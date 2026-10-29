import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_database/firebase_database.dart';

import '../models/room_models.dart';
import '../playback/playback_command.dart';

class RoomFullException implements Exception {
  const RoomFullException();
  @override
  String toString() => 'This room is already vibing with two people.';
}

class RoomNotFoundException implements Exception {
  const RoomNotFoundException();
}

abstract interface class RoomRepository {
  Future<ListeningRoom> createRoom(
      {required String hostId,
      required String displayName,
      String? avatarUrl,
      required String code,
      String? name});
  Future<ListeningRoom> joinByCode(
      {required String code,
      required String userId,
      required String displayName,
      String? avatarUrl});
  Future<ListeningRoom?> findById(String roomId);
  Future<ListeningRoom> joinById(
      {required String roomId,
      required String userId,
      required String displayName,
      String? avatarUrl});
  Future<ListeningRoom?> findByCode(String code);
  Stream<ListeningRoom?> watchRoom(String roomId);
  Stream<List<RoomParticipant>> watchParticipants(String roomId);
  Future<void> setOnline(String roomId, RoomParticipant participant);
  Future<void> heartbeat(String roomId, String userId);
  Future<void> setOffline(String roomId, String userId);
  Future<void> leave(String roomId, String userId);
  Future<void> deleteRoom(String roomId);
  Future<void> submitPlaybackCommand(String roomId, PlaybackCommand command);
  Future<void> submitPlaybackCheckpoint(
      String roomId, String userId, int positionMs);
}

class FirestoreRoomRepository implements RoomRepository {
  FirestoreRoomRepository(this._firestore, [FirebaseFunctions? functions])
      : _functions = functions;
  final FirebaseFirestore _firestore;
  final FirebaseFunctions? _functions;

  FirebaseFunctions get _trustedFunctions =>
      _functions ?? FirebaseFunctions.instance;

  CollectionReference<Map<String, dynamic>> get _rooms =>
      _firestore.collection('rooms');

  Future<void> _startPresence(String roomId, String userId) async {
    final presence = FirebaseDatabase.instance.ref('presence/$roomId/$userId');
    await presence.onDisconnect().remove();
    await presence.set({
      'roomId': roomId,
      'connected': true,
      'connectedAt': ServerValue.timestamp,
    });
  }

  @override
  Future<ListeningRoom> createRoom(
      {required String hostId,
      required String displayName,
      String? avatarUrl,
      required String code,
      String? name}) async {
    final result = await _trustedFunctions.httpsCallable('createRoom').call({
      'displayName': displayName,
      'avatarUrl': avatarUrl,
      'name': name,
    });
    final roomId = (result.data as Map)['roomId'] as String;
    await _startPresence(roomId, hostId);
    final saved = await _rooms.doc(roomId).get();
    return ListeningRoom.fromSnapshot(saved);
  }

  @override
  Future<ListeningRoom> joinById(
      {required String roomId,
      required String userId,
      required String displayName,
      String? avatarUrl}) async {
    final result = await _trustedFunctions.httpsCallable('joinRoom').call({
      'roomId': roomId,
      'displayName': displayName,
      'avatarUrl': avatarUrl,
    });
    final saved =
        await _rooms.doc((result.data as Map)['roomId'] as String).get();
    await _startPresence(roomId, userId);
    return ListeningRoom.fromSnapshot(saved);
  }

  @override
  Future<ListeningRoom> joinByCode(
      {required String code,
      required String userId,
      required String displayName,
      String? avatarUrl}) async {
    final result = await _trustedFunctions.httpsCallable('joinRoom').call({
      'code': code,
      'displayName': displayName,
      'avatarUrl': avatarUrl,
    });
    final saved =
        await _rooms.doc((result.data as Map)['roomId'] as String).get();
    await _startPresence((result.data as Map)['roomId'] as String, userId);
    return ListeningRoom.fromSnapshot(saved);
  }

  @override
  Future<ListeningRoom?> findById(String roomId) async {
    final snapshot = await _rooms.doc(roomId).get();
    return snapshot.exists ? ListeningRoom.fromSnapshot(snapshot) : null;
  }

  @override
  Future<ListeningRoom?> findByCode(String code) async {
    // Invite lookup is mediated by the authenticated resolver. A code alone
    // never grants a direct Firestore read.
    await _trustedFunctions
        .httpsCallable('resolveRoomInvite')
        .call({'code': code});
    return null;
  }

  @override
  Stream<ListeningRoom?> watchRoom(String roomId) =>
      _rooms.doc(roomId).snapshots().map((snapshot) =>
          snapshot.exists ? ListeningRoom.fromSnapshot(snapshot) : null);

  @override
  Stream<List<RoomParticipant>> watchParticipants(String roomId) {
    final controller = StreamController<List<RoomParticipant>>.broadcast();
    final firestore = _rooms.doc(roomId).collection('participants');
    var participants = <RoomParticipant>[];
    var presence = <String, dynamic>{};

    void emit() {
      final now = DateTime.now();
      controller.add(participants.map((participant) {
        final data = presence[participant.userId];
        final connectedAt = data is Map ? data['connectedAt'] : null;
        final connected = data is Map &&
            data['connected'] == true &&
            connectedAt is int &&
            now
                    .difference(
                        DateTime.fromMillisecondsSinceEpoch(connectedAt))
                    .inSeconds <
                45;
        return participant.copyWith(
          lastSeenAt: connectedAt is int
              ? DateTime.fromMillisecondsSinceEpoch(connectedAt)
              : participant.lastSeenAt,
          isOnline: connected,
        );
      }).toList(growable: false));
    }

    final participantSubscription = firestore.snapshots().listen((snapshot) {
      participants = snapshot.docs
          .map((doc) => RoomParticipant.fromMap(doc.data(), doc.id))
          .toList(growable: false);
      emit();
    });
    final presenceSubscription = FirebaseDatabase.instance
        .ref('presence/$roomId')
        .onValue
        .listen((event) {
      final value = event.snapshot.value;
      presence = value is Map ? Map<String, dynamic>.from(value) : {};
      emit();
    });

    controller.onCancel = () async {
      await participantSubscription.cancel();
      await presenceSubscription.cancel();
      await controller.close();
    };
    return controller.stream;
  }

  @override
  Future<void> setOnline(String roomId, RoomParticipant participant) =>
      _trustedFunctions.httpsCallable('heartbeatRoom').call({'roomId': roomId});

  @override
  Future<void> heartbeat(String roomId, String userId) =>
      _trustedFunctions.httpsCallable('heartbeatRoom').call({'roomId': roomId});

  @override
  Future<void> setOffline(String roomId, String userId) => _trustedFunctions
      .httpsCallable('leaveRoom')
      .call({'roomId': roomId, 'offline': true});

  @override
  @override
  Future<void> submitPlaybackCommand(
      String roomId, PlaybackCommand command) async {
    await _trustedFunctions.httpsCallable('submitPlaybackCommand').call({
      'roomId': roomId,
      'command': {
        'commandId': command.commandId,
        'type': command.type.name,
        'revision': command.revision,
        'trackId': command.trackId,
        'provider': command.provider,
        'positionMs': command.positionMs,
        'queueItem': command.queueItem,
        'queueIndex': command.queueIndex,
        'enabled': command.enabled,
      }
    });
  }

  @override
  Future<void> submitPlaybackCheckpoint(
      String roomId, String userId, int positionMs) async {
    await _trustedFunctions.httpsCallable('submitPlaybackCheckpoint').call({
      'roomId': roomId,
      'positionMs': positionMs.clamp(0, 0x7fffffff),
    });
  }

  @override
  Future<void> leave(String roomId, String userId) async {
    await _trustedFunctions.httpsCallable('leaveRoom').call({'roomId': roomId});
  }

  @override
  Future<void> deleteRoom(String roomId) async {
    await _trustedFunctions
        .httpsCallable('deleteRoom')
        .call({'roomId': roomId});
  }
}
