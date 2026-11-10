import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_environment.dart';
import '../../../core/music/providers/youtube/youtube_search_service.dart';
import '../models/room_models.dart';
import '../repositories/room_repository.dart';
import '../playback/playback_command.dart';
import '../services/room_service.dart';
import '../../../core/music/music_cache.dart';

class UnconfiguredRoomRepository implements RoomRepository {
  static Exception get error =>
      Exception('Listening rooms are not connected yet.');
  @override
  Future<ListeningRoom> createRoom(
          {required String hostId,
          required String displayName,
          String? avatarUrl,
          required String code,
          String? name}) =>
      Future.error(error);
  @override
  Future<ListeningRoom> joinByCode(
          {required String code,
          required String userId,
          required String displayName,
          String? avatarUrl}) =>
      Future.error(error);
  @override
  Future<ListeningRoom?> findById(String roomId) async => null;
  @override
  Future<ListeningRoom> joinById(
          {required String roomId,
          required String userId,
          required String displayName,
          String? avatarUrl}) =>
      Future.error(error);
  @override
  Future<ListeningRoom?> findByCode(String code) async => null;
  @override
  Stream<ListeningRoom?> watchRoom(String roomId) => const Stream.empty();
  @override
  Stream<List<RoomParticipant>> watchParticipants(String roomId) =>
      const Stream.empty();
  @override
  Future<void> setOnline(String roomId, RoomParticipant participant) =>
      Future.error(error);
  @override
  Future<void> heartbeat(String roomId, String userId) => Future.error(error);
  @override
  Future<void> setOffline(String roomId, String userId) => Future.error(error);
  @override
  Future<void> leave(String roomId, String userId) => Future.error(error);
  @override
  Future<void> deleteRoom(String roomId) => Future.error(error);
  @override
  Future<void> submitPlaybackCommand(String roomId, PlaybackCommand command) =>
      Future.error(error);
  @override
  Future<void> submitPlaybackCheckpoint(
          String roomId, String userId, int positionMs) =>
      Future.error(error);
}

final roomRepositoryProvider = Provider<RoomRepository>((ref) =>
    Firebase.apps.isEmpty
        ? UnconfiguredRoomRepository()
        : FirestoreRoomRepository(
            FirebaseFirestore.instance, FirebaseFunctions.instance));
final roomServiceProvider = Provider<RoomService>(
    (ref) => RoomService(ref.watch(roomRepositoryProvider)));

final roomStreamProvider = StreamProvider.autoDispose
    .family<ListeningRoom?, String>(
        (ref, roomId) => ref.watch(roomServiceProvider).watch(roomId));

final roomPlaybackProvider =
    Provider.autoDispose.family<RoomPlaybackState?, String>((ref, roomId) {
  return ref.watch(roomStreamProvider(roomId)).valueOrNull?.playbackState;
});

final roomQueueProvider = Provider.autoDispose
    .family<List<Map<String, dynamic>>?, String>((ref, roomId) {
  return ref.watch(roomStreamProvider(roomId)).valueOrNull?.queue;
});

final roomMetadataProvider =
    Provider.autoDispose.family<ListeningRoom?, String>((ref, roomId) {
  return ref.watch(roomStreamProvider(roomId)).valueOrNull;
});

final roomParticipantsStreamProvider = StreamProvider.autoDispose
    .family<List<RoomParticipant>, String>((ref, roomId) =>
        ref.watch(roomServiceProvider).watchParticipants(roomId));

final connectedParticipantsProvider = Provider.autoDispose
    .family<List<RoomParticipant>, String>((ref, roomId) =>
        (ref.watch(roomParticipantsStreamProvider(roomId)).valueOrNull ??
                const [])
            .where((participant) => participant.connected)
            .toList(growable: false));

final musicCacheProvider = Provider<MusicCache>((ref) => MusicCache());
final youtubeSearchServiceProvider = Provider<YouTubeSearchService>(
    (ref) => YouTubeSearchService(AppEnvironment.youtubeApiKey));

class RoomNotifier extends ChangeNotifier with WidgetsBindingObserver {
  RoomNotifier(this._service, this._roomId, this._userId);
  final RoomService _service;
  final String _roomId;
  final String _userId;
  Timer? _heartbeat;
  Future<void>? _pendingHeartbeat;
  bool _started = false;
  bool _left = false;

  void start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _startHeartbeat();
  }

  void _startHeartbeat() {
    if (_left) return;
    if (_heartbeat?.isActive == true) return;
    _scheduleHeartbeat();
    _heartbeat = Timer.periodic(
        const Duration(seconds: 20), (_) => _scheduleHeartbeat());
  }

  void _stopHeartbeat() {
    _heartbeat?.cancel();
    _heartbeat = null;
  }

  Future<void> _sendHeartbeat() async {
    try {
      await _service.heartbeat(_roomId, _userId);
    } catch (error, stack) {
      debugPrint('Room heartbeat failed: $error\n$stack');
    }
  }

  void _scheduleHeartbeat() {
    if (_pendingHeartbeat != null) return;
    _pendingHeartbeat = _sendHeartbeat().whenComplete(() {
      _pendingHeartbeat = null;
    });
  }

  Future<void> markOffline() async {
    _stopHeartbeat();
    try {
      await _pendingHeartbeat;
      await _service.markOffline(_roomId, _userId);
    } catch (error, stack) {
      debugPrint('Room offline update failed: $error\n$stack');
    }
  }

  Future<void> leave() async {
    _stopHeartbeat();
    try {
      await _pendingHeartbeat;
      await _service.leave(_roomId, _userId);
      _left = true;
    } catch (error) {
      _startHeartbeat();
      rethrow;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startHeartbeat();
    }
  }

  @override
  void dispose() {
    _stopHeartbeat();
    WidgetsBinding.instance.removeObserver(this);
    if (!_left) unawaited(markOffline());
    super.dispose();
  }
}
