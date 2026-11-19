import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'web_audio_player.dart';

@JS('ytAudioBridge')
external YtAudioBridgeJs? get _ytBridge;

@JS()
extension type YtAudioBridgeJs(JSObject _) implements JSObject {
  external void play(JSString? videoId, JSString? query);
  external void pause();
  external void resume();
  external void stop();
  external void seekTo(JSNumber seconds);
  external JSNumber getPosition();
  external JSNumber getDuration();
  external JSBoolean isPlaying();
  external JSBoolean isBuffering();
  external JSString? getVideoId();
  external JSFunction? onEvent;
}

WebAudioPlayer createWebAudioPlayer() => _WebAudioPlayerWeb();

class _WebAudioPlayerWeb implements WebAudioPlayer {
  bool _initialized = false;
  Duration _position = Duration.zero;
  Duration? _duration;
  bool _isPlaying = false;
  bool _isBuffering = false;
  String? _currentVideoId;
  String? _playbackError;

  final StreamController<Duration> _positionController =
      StreamController<Duration>.broadcast();
  final StreamController<Duration?> _durationController =
      StreamController<Duration?>.broadcast();
  final StreamController<bool> _isPlayingController =
      StreamController<bool>.broadcast();
  final StreamController<bool> _isBufferingController =
      StreamController<bool>.broadcast();
  final StreamController<String?> _videoIdController =
      StreamController<String?>.broadcast();
  final StreamController<String?> _errorController =
      StreamController<String?>.broadcast();

  _WebAudioPlayerWeb() {
    _ensureBridge();
  }

  void _ensureBridge() {
    if (_initialized) return;
    final bridge = _ytBridge;
    if (bridge != null) {
      void handler(JSString eventJson) {
        try {
          final decoded = jsonDecode(eventJson.toDart);
          if (decoded is Map<String, dynamic>) {
            _handleEvent(decoded);
          }
        } catch (_) {}
      }

      bridge.onEvent = handler.toJS;
      _initialized = true;
    }
  }

  void _handleEvent(Map<String, dynamic> msg) {
    final event = msg['event'] as String?;
    final data = msg['data'] as Map<String, dynamic>? ?? <String, dynamic>{};

    switch (event) {
      case 'timeupdate':
        final posSec = (data['position'] as num?)?.toDouble() ?? 0.0;
        final durSec = (data['duration'] as num?)?.toDouble() ?? 0.0;
        _position = Duration(milliseconds: (posSec * 1000).round());
        if (durSec > 0) {
          _duration = Duration(milliseconds: (durSec * 1000).round());
          _durationController.add(_duration);
        }
        _positionController.add(_position);
        break;

      case 'stateChange':
        final state = data['state'] as String?;
        if (state == 'playing') {
          _isPlaying = true;
          _isBuffering = false;
          _isPlayingController.add(true);
          _isBufferingController.add(false);
        } else if (state == 'paused') {
          _isPlaying = false;
          _isBuffering = false;
          _isPlayingController.add(false);
          _isBufferingController.add(false);
        } else if (state == 'buffering') {
          _isBuffering = true;
          _isBufferingController.add(true);
        } else if (state == 'ended') {
          _isPlaying = false;
          _isBuffering = false;
          _position = Duration.zero;
          _isPlayingController.add(false);
          _isBufferingController.add(false);
          _positionController.add(Duration.zero);
        }
        break;

      case 'videoIdResolved':
        final vid = data['videoId'] as String?;
        if (vid != null && vid.isNotEmpty) {
          _currentVideoId = vid;
          _videoIdController.add(vid);
        }
        break;

      case 'error':
        final code = data['code'];
        _isBuffering = false;
        _isPlaying = false;
        _playbackError = 'playback error ($code) – trying another song';
        _errorController.add(_playbackError);
        _isPlayingController.add(false);
        _isBufferingController.add(false);
        break;
    }
  }

  @override
  bool get isSupported => true;

  @override
  Duration get position => _position;

  @override
  Duration? get duration => _duration;

  @override
  bool get isPlaying => _isPlaying;

  @override
  bool get isBuffering => _isBuffering;

  @override
  String? get currentVideoId => _currentVideoId;

  @override
  String? get playbackError => _playbackError;

  @override
  Stream<Duration> get positionStream => _positionController.stream;

  @override
  Stream<Duration?> get durationStream => _durationController.stream;

  @override
  Stream<bool> get isPlayingStream => _isPlayingController.stream;

  @override
  Stream<bool> get isBufferingStream => _isBufferingController.stream;

  @override
  Stream<String?> get videoIdStream => _videoIdController.stream;

  @override
  Stream<String?> get errorStream => _errorController.stream;

  @override
  Future<void> play({String? videoId, String? query}) async {
    _ensureBridge();
    _playbackError = null;
    _isBuffering = true;
    _isBufferingController.add(true);
    if (videoId != null && videoId.isNotEmpty) {
      _currentVideoId = videoId;
    }

    final bridge = _ytBridge;
    if (bridge != null) {
      bridge.play(
        videoId?.toJS,
        query?.toJS,
      );
    } else {
      // Retry in 150ms if bridge was still initializing
      Future<void>.delayed(const Duration(milliseconds: 150), () {
        _ensureBridge();
        _ytBridge?.play(
          videoId?.toJS,
          query?.toJS,
        );
      });
    }
  }

  @override
  Future<void> pause() async {
    _ensureBridge();
    _ytBridge?.pause();
    _isPlaying = false;
    _isPlayingController.add(false);
  }

  @override
  Future<void> resume() async {
    _ensureBridge();
    _ytBridge?.resume();
    _isPlaying = true;
    _isPlayingController.add(true);
  }

  @override
  Future<void> stop() async {
    _ensureBridge();
    _isPlaying = false;
    _isBuffering = false;
    _position = Duration.zero;
    _isPlayingController.add(false);
    _isBufferingController.add(false);
    _positionController.add(Duration.zero);
    _ytBridge?.stop();
  }

  @override
  Future<void> seekTo(Duration position) async {
    _ensureBridge();
    _position = position;
    _positionController.add(position);
    final sec = position.inMilliseconds / 1000.0;
    _ytBridge?.seekTo(sec.toJS);
  }

  @override
  void dispose() {
    _positionController.close();
    _durationController.close();
    _isPlayingController.close();
    _isBufferingController.close();
    _videoIdController.close();
    _errorController.close();
  }
}
