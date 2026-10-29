import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/room_models.dart';
import '../repositories/room_repository.dart';
import '../playback/playback_command.dart';
import '../services/room_service.dart';
import '../../../core/music/music_cache.dart';
import 'room_presence_platform.dart';

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

class RoomNotifier extends ChangeNotifier with WidgetsBindingObserver {
  RoomNotifier(this._service, this._roomId, this._userId);
  final RoomService _service;
  final String _roomId;
  final String _userId;
  Timer? _heartbeat;
  bool _started = false;

  void start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    observeRoomPageLifecycle(_startHeartbeat, markOffline);
    _startHeartbeat();
  }

  void _startHeartbeat() {
    if (_heartbeat?.isActive == true) return;
    _sendHeartbeat();
    _heartbeat =
        Timer.periodic(const Duration(seconds: 20), (_) => _sendHeartbeat());
  }

  void _stopHeartbeat() {
    _heartbeat?.cancel();
    _heartbeat = null;
  }

  Future<void> _sendHeartbeat() async {
    try {
      await _service.heartbeat(_roomId, _userId);
    } catch (_) {}
  }

  Future<void> markOffline() async {
    _stopHeartbeat();
    try {
      await _service.markOffline(_roomId, _userId);
    } catch (_) {}
  }

  Future<void> leave() async {
    _stopHeartbeat();
    try {
      await _service.leave(_roomId, _userId);
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startHeartbeat();
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _stopHeartbeat();
      markOffline();
    }
  }

  @override
  void dispose() {
    _stopHeartbeat();
    WidgetsBinding.instance.removeObserver(this);
    markOffline();
    super.dispose();
  }
}
