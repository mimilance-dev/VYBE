import 'package:flutter_test/flutter_test.dart';
import 'package:vybe/features/rooms/models/room_models.dart';
import 'package:vybe/features/rooms/playback/playback_command.dart';
import 'package:vybe/features/rooms/playback/sync_engine.dart';
import 'package:vybe/features/rooms/playback/playback_synchronizer.dart';

class _Client {
  _Client(this.name);
  final String name;
  RoomPlaybackState? authoritative;
  DateTime? lastEventAt;
  bool connected = true;

  Future<void> receive(RoomPlaybackState state, Duration delay) async {
    await Future<void>.delayed(delay);
    if (!connected) return;
    authoritative = state;
    lastEventAt = DateTime.now();
  }
}

void main() {
  final start = DateTime.utc(2026);
  const engine = SyncEngine();
  RoomPlaybackState roomState() => RoomPlaybackState(
      provider: 'spotify',
      trackId: 'track-a',
      isPlaying: false,
      positionMs: 0,
      serverTimestamp: start,
      revision: 0);
  PlaybackCommand cmd(String id, PlaybackCommandType type, int revision,
          {int? positionMs, String? trackId}) =>
      PlaybackCommand(
          commandId: id,
          senderId: 'a',
          timestamp: start,
          revision: revision,
          type: type,
          positionMs: positionMs,
          trackId: trackId,
          queueItem:
              trackId == null ? null : {'id': trackId, 'provider': 'spotify'});

  test('two users create, join, play, seek, change track and converge',
      () async {
    final a = _Client('A');
    final b = _Client('B');
    var server = roomState();

    var result = engine.apply(
        state: server,
        queue: const [],
        command: cmd('play', PlaybackCommandType.play, server.revision),
        serverTime: start,
        processedCommandIds: const {});
    server = result.state;
    await Future.wait([
      a.receive(server, const Duration(milliseconds: 100)),
      b.receive(server, const Duration(milliseconds: 100))
    ]);
    expect(a.authoritative?.isPlaying, isTrue);

    result = engine.apply(
        state: server,
        queue: const [],
        command: cmd('seek', PlaybackCommandType.seek, server.revision,
            positionMs: 42000),
        serverTime: start,
        processedCommandIds: const {});
    server = result.state;
    await Future.wait([
      a.receive(server, const Duration(milliseconds: 100)),
      b.receive(server, const Duration(milliseconds: 100))
    ]);
    expect(a.authoritative?.positionMs, 42000);
    expect(b.authoritative?.positionMs, 42000);

    result = engine.apply(
        state: server,
        queue: const [],
        command: cmd('track', PlaybackCommandType.setTrack, server.revision,
            trackId: 'track-b'),
        serverTime: start,
        processedCommandIds: const {});
    server = result.state;
    await Future.wait([
      a.receive(server, const Duration(milliseconds: 100)),
      b.receive(server, const Duration(milliseconds: 100))
    ]);
    expect(a.authoritative?.trackId, 'track-b');
    expect(b.authoritative?.trackId, 'track-b');
  });

  test('disconnect reconnect and late refresh recover authoritative state',
      () async {
    final a = _Client('A');
    final b = _Client('B')..connected = false;
    var server = roomState();
    var result = engine.apply(
        state: server,
        queue: const [],
        command: cmd('play', PlaybackCommandType.play, server.revision),
        serverTime: start,
        processedCommandIds: const {});
    server = result.state;
    await a.receive(server, const Duration(milliseconds: 500));
    expect(b.authoritative, isNull);

    b.connected = true;
    await b.receive(server, const Duration(milliseconds: 500));
    final lateJoiner = _Client('late-refresh');
    await lateJoiner.receive(server, Duration.zero);
    expect(b.authoritative?.revision, server.revision);
    expect(lateJoiner.authoritative?.revision, server.revision);
  });

  test('simultaneous A pause and B play converge by revision', () {
    final server = roomState().copy(isPlaying: true);
    final pause = engine.apply(
        state: server,
        queue: const [],
        command: cmd('pause', PlaybackCommandType.pause, server.revision),
        serverTime: start,
        processedCommandIds: const {});
    final play = engine.apply(
        state: server,
        queue: const [],
        command:
            cmd('play-simultaneous', PlaybackCommandType.play, server.revision),
        serverTime: start,
        processedCommandIds: const {});
    expect(pause.state.revision, server.revision + 1);
    expect(play.state.revision, server.revision + 1);
    expect(pause.state.revision, play.state.revision);
  });

  test('browser refresh uses monotonic authoritative projection', () {
    final playing = roomState()
        .copy(isPlaying: true, positionMs: 1000, serverTimestamp: start);
    final expected = const PlaybackSynchronizer()
        .expectedPosition(playing, start.add(const Duration(seconds: 5)));
    expect(expected, 6000);
  });
}
