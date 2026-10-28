import '../models/room_models.dart';
import 'sync_engine.dart';

enum SyncStatus { synced, syncing, reconnecting }
enum DriftCorrection { ignore, gradual, hardSeek }
class PlaybackDriftResult { const PlaybackDriftResult(this.driftMs, this.action); final int driftMs; final DriftCorrection action; }

class PlaybackSynchronizer {
  const PlaybackSynchronizer({this.ignoreBelowMs = 100});
  final int ignoreBelowMs;
  int expectedPosition(RoomPlaybackState state, DateTime now) => const SyncEngine().projectedPosition(state, now);
  PlaybackDriftResult correct(int measuredPositionMs, RoomPlaybackState state, DateTime now) {
    final drift = measuredPositionMs - expectedPosition(state, now);
    final absolute = drift.abs();
    if (absolute < ignoreBelowMs) return PlaybackDriftResult(drift, DriftCorrection.ignore);
    if (absolute <= 500) return PlaybackDriftResult(drift, DriftCorrection.gradual);
    return PlaybackDriftResult(drift, DriftCorrection.hardSeek);
  }
}
