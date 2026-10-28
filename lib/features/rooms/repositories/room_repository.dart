import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

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
  Stream<List<RoomParticipant>> watchParticipants(String roomId) => _rooms
      .doc(roomId)
      .collection('participants')
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => RoomParticipant.fromMap(doc.data(), doc.id))
          .toList());

  @override
  Future<void> setOnline(String roomId, RoomParticipant participant) =>
      _rooms.doc(roomId).collection('participants').doc(participant.userId).set(
          participant
              .copyWith(lastSeenAt: DateTime.now(), isOnline: true)
              .toMap(),
          SetOptions(merge: true));

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
}
