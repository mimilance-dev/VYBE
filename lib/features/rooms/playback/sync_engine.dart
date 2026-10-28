import '../models/room_models.dart';
import 'playback_command.dart';

class PlaybackSyncResult {
  const PlaybackSyncResult(this.state, this.accepted, this.queue,
      {this.currentTrack});
  final RoomPlaybackState state;
  final bool accepted;
  final List<Map<String, dynamic>> queue;
  final Map<String, dynamic>? currentTrack;
}

/// Server ordering is revision-first. A timestamp is only used when commands
/// are observed against the same revision, such as after reconnecting.
class SyncEngine {
  const SyncEngine();

  PlaybackSyncResult apply(
      {required RoomPlaybackState state,
      required List<Map<String, dynamic>> queue,
      Map<String, dynamic>? currentTrack,
      required PlaybackCommand command,
      required DateTime serverTime,
      required Set<String> processedCommandIds}) {
    if (processedCommandIds.contains(command.commandId)) {
      return PlaybackSyncResult(state, false, queue,
          currentTrack: currentTrack);
    }
    // Revision represents the observed state. Only commands based on the
    // exact current revision are accepted; replayed and stale values are rejected.
    // Timestamp is audit-only because client clocks and network delays vary.
    if (command.revision != state.revision) {
      return PlaybackSyncResult(state, false, queue,
          currentTrack: currentTrack);
    }

    final revision = state.revision + 1;
    var next = state;
    var nextTrack = currentTrack;
    var nextQueue = List<Map<String, dynamic>>.from(queue);
    switch (command.type) {
      case PlaybackCommandType.play:
        next = _state(state, true, state.positionMs, serverTime, revision);
      case PlaybackCommandType.pause:
        next = _state(state, false, projectedPosition(state, serverTime),
            serverTime, revision);
      case PlaybackCommandType.seek:
        next = _state(
            state,
            state.isPlaying,
            (command.positionMs ?? 0).clamp(0, 0x7fffffff),
            serverTime,
            revision);
      case PlaybackCommandType.setTrack:
        nextTrack = command.queueItem ??
            {'id': command.trackId, 'provider': command.provider};
        next = _state(
            state.copy(
                provider: command.provider ?? state.provider,
                trackId: command.trackId ?? state.trackId),
            false,
            0,
            serverTime,
            revision);
      case PlaybackCommandType.addToQueue:
        if (command.queueItem != null) {
          nextQueue.add(command.queueItem!);
        }
      case PlaybackCommandType.removeFromQueue:
        final index = command.queueIndex;
        if (index != null && index >= 0 && index < nextQueue.length) {
          nextQueue.removeAt(index);
        }
      case PlaybackCommandType.clearQueue:
        nextQueue.clear();
      case PlaybackCommandType.next:
      case PlaybackCommandType.previous:
        break;
      case PlaybackCommandType.setShuffle:
      case PlaybackCommandType.setRepeat:
      case PlaybackCommandType.checkpoint:
        break;
    }
    if (next == state) {
      next = _state(
          state,
          state.isPlaying,
          projectedPosition(state, serverTime),
          state.serverTimestamp,
          revision);
    }
    return PlaybackSyncResult(next, true, nextQueue, currentTrack: nextTrack);
  }

  RoomPlaybackState _state(RoomPlaybackState source, bool playing,
          Object position, DateTime? time, int revision) =>
      RoomPlaybackState(
        provider: source.provider,
        trackId: source.trackId,
        isPlaying: playing,
        positionMs: position is num ? position.toInt() : 0,
        serverTimestamp: time,
        revision: revision,
      );

  int projectedPosition(RoomPlaybackState state, DateTime now) {
    if (!state.isPlaying || state.serverTimestamp == null) {
      return state.positionMs;
    }
    final elapsed = now.difference(state.serverTimestamp!).inMilliseconds;
    return state.positionMs + (elapsed > 0 ? elapsed : 0);
  }
}
