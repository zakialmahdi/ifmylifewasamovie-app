import 'dart:async';
import 'web_audio_player.dart';

WebAudioPlayer createWebAudioPlayer() => _WebAudioPlayerStub();

class _WebAudioPlayerStub implements WebAudioPlayer {
  @override
  bool get isSupported => false;

  @override
  Duration get position => Duration.zero;

  @override
  Duration? get duration => null;

  @override
  bool get isPlaying => false;

  @override
  bool get isBuffering => false;

  @override
  String? get currentVideoId => null;

  @override
  String? get playbackError => null;

  @override
  final Stream<Duration> positionStream = const Stream<Duration>.empty();

  @override
  final Stream<Duration?> durationStream = const Stream<Duration?>.empty();

  @override
  final Stream<bool> isPlayingStream = const Stream<bool>.empty();

  @override
  final Stream<bool> isBufferingStream = const Stream<bool>.empty();

  @override
  final Stream<String?> videoIdStream = const Stream<String?>.empty();

  @override
  final Stream<String?> errorStream = const Stream<String?>.empty();

  @override
  Future<void> play({String? videoId, String? query}) async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> seekTo(Duration position) async {}

  @override
  void dispose() {}
}
