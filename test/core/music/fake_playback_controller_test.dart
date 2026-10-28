import 'package:flutter_test/flutter_test.dart';
import 'package:vybe/core/music/models/music_models.dart';
import '../../support/fake_music_playback_controller.dart';

void main() {
  const track = Track(
    id: 'test-track',
    provider: MusicProviderId.spotify,
    title: 'Test',
    artist: 'Listener',
    durationMs: 180000,
    externalUrl: 'https://open.spotify.com/track/test-track',
  );

  test('fake playback controller records provider-neutral operations',
      () async {
    final controller = FakeMusicPlaybackController(
        clock: () => const Duration(milliseconds: 1000));
    await controller.play(track);
    expect(controller.currentTrack, track);
    await controller.seek(const Duration(seconds: 42));
    expect(await controller.getPosition(), const Duration(seconds: 42));

    await controller.pause();
    expect(await controller.getIsPlaying(), isFalse);
    expect(controller.operations, contains('play:test-track'));
    expect(controller.seekCount, 1);
  });

  test('fake playback latency is configurable without provider dependencies',
      () async {
    final controller = FakeMusicPlaybackController()
      ..latency = const Duration(milliseconds: 100);
    final stopwatch = Stopwatch()..start();
    await controller.play(track);
    stopwatch.stop();
    expect(stopwatch.elapsedMilliseconds, greaterThanOrEqualTo(100));
  });
}
