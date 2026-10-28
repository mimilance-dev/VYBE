import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/room_models.dart';
import '../repositories/room_repository.dart';
import 'playback_command.dart';
import 'playback_synchronizer.dart';

class PlaybackStateNotifier extends ChangeNotifier {
  PlaybackStateNotifier(this.repository, this.roomId, this.userId);
  final RoomRepository repository;
  final String roomId;
  final String userId;
  final PlaybackSynchronizer synchronizer = const PlaybackSynchronizer();
  RoomPlaybackState? state;
  SyncStatus status = SyncStatus.synced;
  StreamSubscription<ListeningRoom?>? subscription;
  Timer? checkpointTimer;

  void start() {
    subscription ??= repository.watchRoom(roomId).listen((room) {
      if (room != null &&
          (state == null || room.playbackState.revision >= state!.revision)) {
        state = room.playbackState;
        status = SyncStatus.synced;
        notifyListeners();
      }
    }, onError: (_) {
      status = SyncStatus.reconnecting;
      notifyListeners();
    });
    checkpointTimer ??=
        Timer.periodic(const Duration(seconds: 30), (_) => checkpoint());
  }

  Future<void> send(PlaybackCommandType type,
      {String? trackId,
      String? provider,
      int? positionMs,
      Map<String, dynamic>? queueItem,
      int? queueIndex,
      bool? enabled}) async {
    final command = PlaybackCommand(
        commandId:
            '${userId}_${DateTime.now().microsecondsSinceEpoch}_${type.name}',
        senderId: userId,
        timestamp: DateTime.now(),
        revision: state?.revision ?? 0,
        type: type,
        trackId: trackId,
        provider: provider,
        positionMs: positionMs,
        queueItem: queueItem,
        queueIndex: queueIndex,
        enabled: enabled);
    status = SyncStatus.syncing;
    notifyListeners();
    try {
      await repository.submitPlaybackCommand(roomId, command);
      status = SyncStatus.synced;
    } catch (_) {
      status = SyncStatus.reconnecting;
    }
    notifyListeners();
  }

  Future<void> checkpoint() async {
    final current = state;
    if (current == null) return;
    await repository.submitPlaybackCheckpoint(
        roomId, userId, synchronizer.expectedPosition(current, DateTime.now()));
  }

  @override
  void dispose() {
    checkpointTimer?.cancel();
    subscription?.cancel();
    super.dispose();
  }
}
