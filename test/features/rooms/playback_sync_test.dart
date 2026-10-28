import 'package:flutter_test/flutter_test.dart';
import 'package:vybe/features/rooms/models/room_models.dart';
import 'package:vybe/features/rooms/playback/playback_command.dart';
import 'package:vybe/features/rooms/playback/playback_synchronizer.dart';
import 'package:vybe/features/rooms/playback/sync_engine.dart';

void main() {
  final now = DateTime(2026, 1, 1);
  RoomPlaybackState idle() => RoomPlaybackState(
      provider: 'spotify',
      trackId: 'track',
      isPlaying: false,
      positionMs: 1000,
      serverTimestamp: now,
      revision: 3);
  PlaybackCommand command(String id, PlaybackCommandType type,
          {int revision = 3, int? positionMs, DateTime? timestamp}) =>
      PlaybackCommand(
          commandId: id,
          senderId: 'u',
          timestamp: timestamp ?? now,
          revision: revision,
          type: type,
          positionMs: positionMs);

  test('play then pause uses expected server position', () {
    const engine = SyncEngine();
    var result = engine.apply(
        state: idle(),
        queue: const [],
        command: command('play', PlaybackCommandType.play),
        serverTime: now.add(const Duration(seconds: 1)),
        processedCommandIds: const {});
    expect(result.accepted, isTrue);
    expect(result.state.isPlaying, isTrue);
    result = engine.apply(
        state: result.state,
        queue: const [],
        command: command('pause', PlaybackCommandType.pause, revision: 4),
        serverTime: now.add(const Duration(seconds: 3)),
        processedCommandIds: const {});
    expect(result.state.isPlaying, isFalse);
    expect(result.state.positionMs, 3000);
  });

  test('pause then play resumes from authoritative position', () {
    const engine = SyncEngine();
    var result = engine.apply(
        state: idle(),
        queue: const [],
        command: command('pause1', PlaybackCommandType.pause),
        serverTime: now,
        processedCommandIds: const {});
    result = engine.apply(
        state: result.state,
        queue: const [],
        command: command('play1', PlaybackCommandType.play, revision: 4),
        serverTime: now.add(const Duration(seconds: 1)),
        processedCommandIds: const {});
    expect(result.state.positionMs, 1000);
    expect(result.state.isPlaying, isTrue);
  });

  test('seek records exact position', () {
    final result = const SyncEngine().apply(
        state: idle(),
        queue: const [],
        command: command('seek', PlaybackCommandType.seek, positionMs: 42000),
        serverTime: now,
        processedCommandIds: const {});
    expect(result.state.positionMs, 42000);
  });

  test('rapid play pause remains ordered by revision', () {
    const engine = SyncEngine();
    var state = idle();
    for (final type in [
      PlaybackCommandType.play,
      PlaybackCommandType.pause,
      PlaybackCommandType.play,
      PlaybackCommandType.pause
    ]) {
      final result = engine.apply(
          state: state,
          queue: const [],
          command:
              command('c${state.revision}', type, revision: state.revision),
          serverTime: now.add(Duration(seconds: state.revision)),
          processedCommandIds: const {});
      state = result.state;
    }
    expect(state.revision, 7);
    expect(state.isPlaying, isFalse);
  });

  test('late old command cannot overwrite newer state', () {
    final current = idle().copy(
        revision: 10, serverTimestamp: now.add(const Duration(minutes: 1)));
    final result = const SyncEngine().apply(
        state: current,
        queue: const [],
        command: command('old', PlaybackCommandType.play, revision: 3),
        serverTime: now,
        processedCommandIds: const {});
    expect(result.accepted, isFalse);
  });

  test('duplicate command is ignored', () {
    final result = const SyncEngine().apply(
        state: idle(),
        queue: const [],
        command: command('same', PlaybackCommandType.play),
        serverTime: now,
        processedCommandIds: {'same'});
    expect(result.accepted, isFalse);
  });

  test('simultaneous commands use revision conflict winner', () {
    const engine = SyncEngine();
    final play = engine.apply(
        state: idle(),
        queue: const [],
        command: command('play', PlaybackCommandType.play),
        serverTime: now,
        processedCommandIds: const {});
    final pause = engine.apply(
        state: idle(),
        queue: const [],
        command: command('pause', PlaybackCommandType.pause),
        serverTime: now.add(const Duration(milliseconds: 1)),
        processedCommandIds: const {});
    expect(play.accepted, isTrue);
    expect(pause.accepted, isTrue);
    expect(play.state.revision, 4);
    expect(pause.state.revision, 4);
  });

  test('reconnect and late join calculate expected playing position', () {
    final playing = idle().copy(isPlaying: true, serverTimestamp: now);
    final atReconnect = now.add(const Duration(seconds: 5));
    expect(const PlaybackSynchronizer().expectedPosition(playing, atReconnect),
        6000);
  });

  test('drift below threshold is ignored', () {
    final result = const PlaybackSynchronizer().correct(1009, idle(), now);
    expect(result.action, DriftCorrection.ignore);
  });

  test('drift in range uses gradual correction', () {
    final result = const PlaybackSynchronizer().correct(1250, idle(), now);
    expect(result.action, DriftCorrection.gradual);
  });

  test('large drift hard seeks', () {
    final result = const PlaybackSynchronizer().correct(1600, idle(), now);
    expect(result.action, DriftCorrection.hardSeek);
  });

  test('queue commands are applied without streaming audio', () {
    final result = const SyncEngine().apply(
        state: idle(),
        queue: const [],
        command: PlaybackCommand(
            commandId: 'add',
            senderId: 'u',
            timestamp: now,
            revision: 3,
            type: PlaybackCommandType.addToQueue,
            queueItem: {'provider': 'youtube', 'id': 'v1'}),
        serverTime: now,
        processedCommandIds: const {});
    expect(result.queue.single['id'], 'v1');
  });
}
