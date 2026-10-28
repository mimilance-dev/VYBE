import 'package:flutter_test/flutter_test.dart';
import 'package:vybe/features/rooms/models/room_models.dart';
import 'package:vybe/features/rooms/playback/playback_command.dart';
import 'package:vybe/features/rooms/playback/playback_synchronizer.dart';
import 'package:vybe/features/rooms/playback/sync_engine.dart';

class _DelayedClient {
  _DelayedClient(this.delay);
  final Duration delay;
  RoomPlaybackState? state;

  Future<void> receive(RoomPlaybackState authoritative) async {
    await Future<void>.delayed(delay);
    state = authoritative;
  }
}

void main() {
  final start = DateTime.utc(2026, 1, 1);
  RoomPlaybackState initial() => RoomPlaybackState(
      provider: 'spotify',
      trackId: 'track-a',
      isPlaying: false,
      positionMs: 0,
      serverTimestamp: start,
      revision: 0);
  PlaybackCommand command(String id, PlaybackCommandType type, int revision,
          {int? positionMs}) =>
      PlaybackCommand(
          commandId: id,
          senderId: 'a',
          timestamp: start,
          revision: revision,
          type: type,
          positionMs: positionMs);

  for (final milliseconds in [100, 500, 2000]) {
    test('normal and delayed delivery converges after ${milliseconds}ms',
        () async {
      final a = _DelayedClient(Duration(milliseconds: milliseconds));
      final b = _DelayedClient(Duration(milliseconds: milliseconds));
      var state = initial();
      final play = const SyncEngine().apply(
          state: state,
          queue: const [],
          command: command('play', PlaybackCommandType.play, 0),
          serverTime: start,
          processedCommandIds: const {});
      state = play.state;
      await Future.wait([a.receive(state), b.receive(state)]);
      expect(a.state?.isPlaying, isTrue);
      expect(b.state?.isPlaying, isTrue);
      expect(a.state?.revision, b.state?.revision);
    });
  }

  test('duplicate events do not advance revisions', () {
    final state = initial();
    const engine = SyncEngine();
    final played = engine.apply(
        state: state,
        queue: const [],
        command: command('same', PlaybackCommandType.play, 0),
        serverTime: start,
        processedCommandIds: const {});
    final duplicate = engine.apply(
        state: played.state,
        queue: const [],
        command: command('same', PlaybackCommandType.play, 0),
        serverTime: start,
        processedCommandIds: {'same'});
    expect(duplicate.accepted, isFalse);
    expect(played.state.revision, 1);
  });

  test('out-of-order stale command is ignored', () {
    final fresh = initial().copy(revision: 8);
    final stale = const SyncEngine().apply(
        state: fresh,
        queue: const [],
        command: command('old', PlaybackCommandType.pause, 7),
        serverTime: start,
        processedCommandIds: const {});
    expect(stale.accepted, isFalse);
    expect(fresh.revision, 8);
  });

  test('rapid play pause and reconnect converge to final state', () async {
    const engine = SyncEngine();
    var state = initial();
    for (final entry in [
      ('play-1', PlaybackCommandType.play, 0),
      ('pause-1', PlaybackCommandType.pause, 1),
      ('play-2', PlaybackCommandType.play, 2),
      ('pause-2', PlaybackCommandType.pause, 3),
    ]) {
      final result = engine.apply(
          state: state,
          queue: const [],
          command: command(entry.$1, entry.$2, entry.$3),
          serverTime: start,
          processedCommandIds: const {});
      state = result.state;
    }
    final lateJoiner = _DelayedClient(Duration.zero)..state = null;
    await lateJoiner.receive(state);
    expect(lateJoiner.state?.revision, 4);
    expect(lateJoiner.state?.isPlaying, isFalse);
  });

  test('late seek and reconnect position obey drift policy', () {
    final playing = initial()
        .copy(isPlaying: true, positionMs: 1000, serverTimestamp: start);
    const synchronizer = PlaybackSynchronizer();
    expect(
        synchronizer.expectedPosition(
            playing, start.add(const Duration(seconds: 3))),
        4000);
    expect(
        synchronizer
            .correct(6500, playing, start.add(const Duration(seconds: 3)))
            .action,
        DriftCorrection.hardSeek);
  });
}
