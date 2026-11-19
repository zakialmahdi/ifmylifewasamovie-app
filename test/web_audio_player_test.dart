import 'package:flutter_test/flutter_test.dart';
import 'package:if_my_life_was_a_movie/services/web_audio/web_audio_player.dart';
import 'package:if_my_life_was_a_movie/services/youtube_music_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('WebAudioPlayer instance provides fallback stub on VM', () {
    final player = WebAudioPlayer.instance;
    expect(player.isSupported, isFalse);
    expect(player.isPlaying, isFalse);
    expect(player.isBuffering, isFalse);
    expect(player.position, Duration.zero);
    expect(player.duration, isNull);
    expect(player.currentVideoId, isNull);
    expect(player.playbackError, isNull);
  });

  test('YouTubeMusicService currentPosition and currentDuration defaults', () {
    expect(musicService.currentPosition, Duration.zero);
    expect(musicService.currentDuration, isNull);
    expect(musicService.positionStream, isNotNull);
    expect(musicService.durationStream, isNotNull);
  });
}
