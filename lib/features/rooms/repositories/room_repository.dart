import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/room_models.dart';
import '../playback/playback_command.dart';
import '../playback/sync_engine.dart';

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
  FirestoreRoomRepository(this._firestore);
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _rooms =>
      _firestore.collection('rooms');

  @override
  Future<ListeningRoom> createRoom(
      {required String hostId,
      required String displayName,
      String? avatarUrl,
      required String code,
      String? name}) async {
    final roomRef = _rooms.doc();
    final now = DateTime.now();
    final playback = RoomPlaybackState(
        provider: null,
        trackId: null,
        isPlaying: false,
        positionMs: 0,
        serverTimestamp: now,
        revision: 0);
    await _rooms.doc(roomRef.id).set({
      'id': roomRef.id,
      'code': code,
      'hostId': hostId,
      'participants': [hostId],
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'currentTrack': null,
      'playbackState': playback.toMap(),
      'queue': <Object>[],
      'settings': {
        'visibility': 'invite',
        'maxParticipants': 2,
        'name':
            name?.trim().isNotEmpty == true ? name!.trim() : 'Listening room'
      },
    });
    await roomRef.collection('participants').doc(hostId).set({
      'userId': hostId,
      'displayName': displayName,
      'avatarUrl': avatarUrl,
      'joinedAt': FieldValue.serverTimestamp(),
      'lastSeenAt': FieldValue.serverTimestamp(),
      'isOnline': true,
    });
    final saved = await roomRef.get();
    return ListeningRoom.fromSnapshot(saved);
  }

  @override
  Future<ListeningRoom> joinById(
          {required String roomId,
          required String userId,
          required String displayName,
          String? avatarUrl}) =>
      _join(roomId, userId, displayName, avatarUrl);

  @override
  Future<ListeningRoom> joinByCode(
      {required String code,
      required String userId,
      required String displayName,
      String? avatarUrl}) async {
    final found = await findByCode(code);
    if (found == null) throw const RoomNotFoundException();
    return _join(found.id, userId, displayName, avatarUrl);
  }

  Future<ListeningRoom> _join(String roomId, String userId, String displayName,
      String? avatarUrl) async {
    final roomRef = _rooms.doc(roomId);
    final participantRef = roomRef.collection('participants').doc(userId);
    final previous = await participantRef.get();
    await _firestore.runTransaction<void>((transaction) async {
      final roomSnapshot = await transaction.get(roomRef);
      if (!roomSnapshot.exists) throw const RoomNotFoundException();
      final room = ListeningRoom.fromSnapshot(roomSnapshot);
      final roster = room.participants.toSet();
      final staleCutoff = DateTime.now().subtract(const Duration(seconds: 45));
      final participantSnapshots = await Future.wait(roster.map(
          (id) => transaction.get(roomRef.collection('participants').doc(id))));
      final activeIds = <String>{};
      for (final snapshot in participantSnapshots) {
        final data = snapshot.data();
        final seen = _timestamp(data?['lastSeenAt']);
        if (snapshot.exists &&
            data?['isOnline'] == true &&
            seen != null &&
            seen.isAfter(staleCutoff)) {
          activeIds.add(snapshot.id);
        }
      }

      // Rejoining your own seat never consumes another slot. A stale or offline
      // seat is reclaimed before the room is counted as full.
      if (!activeIds.contains(userId) && activeIds.length >= 2) {
        throw const RoomFullException();
      }
      activeIds.add(userId);
      transaction.set(participantRef, {
        'userId': userId,
        'displayName': displayName,
        'avatarUrl': avatarUrl,
        'joinedAt': previous.exists && previous.data() != null
            ? previous.data()!['joinedAt'] ?? FieldValue.serverTimestamp()
            : FieldValue.serverTimestamp(),
        'lastSeenAt': FieldValue.serverTimestamp(),
        'isOnline': true,
      });
      transaction.update(roomRef, {
        'participants': activeIds.toList(),
        'updatedAt': FieldValue.serverTimestamp()
      });
    });
    final refreshed = await roomRef.get();
    return ListeningRoom.fromSnapshot(refreshed);
  }

  @override
  Future<ListeningRoom?> findById(String roomId) async {
    final snapshot = await _rooms.doc(roomId).get();
    return snapshot.exists ? ListeningRoom.fromSnapshot(snapshot) : null;
  }

  @override
  Future<ListeningRoom?> findByCode(String code) async {
    final snapshot = await _rooms
        .where('code',
            isEqualTo: code.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), ''))
        .limit(1)
        .get();
    return snapshot.docs.isEmpty
        ? null
        : ListeningRoom.fromSnapshot(snapshot.docs.first);
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
  Future<void> heartbeat(String roomId, String userId) => _rooms
      .doc(roomId)
      .collection('participants')
      .doc(userId)
      .update({'lastSeenAt': FieldValue.serverTimestamp(), 'isOnline': true});

  @override
  Future<void> setOffline(String roomId, String userId) => _rooms
      .doc(roomId)
      .collection('participants')
      .doc(userId)
      .update({'isOnline': false, 'lastSeenAt': FieldValue.serverTimestamp()});

  @override
  @override
  Future<void> submitPlaybackCommand(
      String roomId, PlaybackCommand command) async {
    final roomRef = _rooms.doc(roomId);
    final commandRef =
        roomRef.collection('playbackCommands').doc(command.commandId);
    await _firestore.runTransaction((transaction) async {
      final existing = await transaction.get(commandRef);
      if (existing.exists) return;
      final snapshot = await transaction.get(roomRef);
      if (!snapshot.exists) throw const RoomNotFoundException();
      final room = ListeningRoom.fromSnapshot(snapshot);
      final result = const SyncEngine().apply(
        state: room.playbackState,
        queue: room.queue,
        currentTrack: room.currentTrack,
        command: command,
        serverTime: DateTime.now(),
        processedCommandIds: const {},
      );
      if (!result.accepted) return;
      transaction.set(commandRef, {
        ...command.toMap(),
        'timestamp': FieldValue.serverTimestamp(),
        'accepted': true
      });
      transaction.update(roomRef, {
        'playbackState': result.state.toMap(),
        'queue': result.queue,
        'currentTrack': result.currentTrack,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (command.type == PlaybackCommandType.setShuffle ||
          command.type == PlaybackCommandType.setRepeat) {
        final key = command.type == PlaybackCommandType.setShuffle
            ? 'shuffle'
            : 'repeat';
        transaction.update(roomRef, {'settings.$key': command.enabled});
      }
    });
  }

  @override
  Future<void> submitPlaybackCheckpoint(
      String roomId, String userId, int positionMs) async {
    final roomRef = _rooms.doc(roomId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(roomRef);
      if (!snapshot.exists) return;
      final state = ListeningRoom.fromSnapshot(snapshot).playbackState;
      transaction.update(roomRef, {
        'playbackState.positionMs': positionMs.clamp(0, 0x7fffffff),
        'playbackState.serverTimestamp': FieldValue.serverTimestamp(),
        'playbackState.revision': state.revision,
      });
    });
  }

  @override
  Future<void> leave(String roomId, String userId) async {
    final roomRef = _rooms.doc(roomId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(roomRef);
      final room = ListeningRoom.fromSnapshot(snapshot);
      transaction.update(roomRef, {
        'participants': room.participants.where((id) => id != userId).toList(),
        'updatedAt': FieldValue.serverTimestamp()
      });
      transaction.update(roomRef.collection('participants').doc(userId),
          {'isOnline': false, 'lastSeenAt': FieldValue.serverTimestamp()});
    });
  }
}

DateTime? _timestamp(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}
