import 'web_audio_player_stub.dart'
    if (dart.library.js_interop) 'web_audio_player_web.dart';

abstract class WebAudioPlayer {
  static final WebAudioPlayer instance = createWebAudioPlayer();

  bool get isSupported;

  Duration get position;
  Duration? get duration;
  bool get isPlaying;
  bool get isBuffering;
  String? get currentVideoId;
  String? get playbackError;

  Stream<Duration> get positionStream;
  Stream<Duration?> get durationStream;
  Stream<bool> get isPlayingStream;
  Stream<bool> get isBufferingStream;
  Stream<String?> get videoIdStream;
  Stream<String?> get errorStream;

  Future<void> play({required String videoId});
  Future<void> pause();
  Future<void> resume();
  Future<void> stop();
  Future<void> seekTo(Duration position);

  void dispose();
}
