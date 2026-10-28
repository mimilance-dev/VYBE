import 'dart:async';
import 'dart:math';

import '../models/room_models.dart';
import '../repositories/room_repository.dart';

class RoomService {
  RoomService(this._repository);
  final RoomRepository _repository;

  Future<ListeningRoom> create(
      {required String hostId,
      required String displayName,
      String? avatarUrl,
      String? name}) async {
    for (var attempt = 0; attempt < 5; attempt++) {
      final code = generateRoomCode();
      if (await _repository.findByCode(code) == null) {
        return _repository.createRoom(
            hostId: hostId,
            displayName: displayName,
            avatarUrl: avatarUrl,
            code: code,
            name: name);
      }
    }
    throw StateError(
        'Could not generate a unique room code. Please try again.');
  }

  Future<ListeningRoom> join(
          {required String code,
          required String userId,
          required String displayName,
          String? avatarUrl}) =>
      _repository.joinByCode(
          code: normalizeRoomCode(code),
          userId: userId,
          displayName: displayName,
          avatarUrl: avatarUrl);

  String normalizeRoomCode(String code) => normalizeRoomCodeValue(code);

  Stream<ListeningRoom?> watch(String roomId) => _repository.watchRoom(roomId);
  Stream<List<RoomParticipant>> watchParticipants(String roomId) =>
      _repository.watchParticipants(roomId);
  Future<ListeningRoom> enterRoom(
          {required String roomId,
          required String userId,
          required String displayName,
          String? avatarUrl}) =>
      _repository.joinById(
          roomId: roomId,
          userId: userId,
          displayName: displayName,
          avatarUrl: avatarUrl);
  Future<void> leave(String roomId, String userId) =>
      _repository.leave(roomId, userId);
  Future<void> heartbeat(String roomId, String userId) =>
      _repository.heartbeat(roomId, userId);
  Future<void> markOffline(String roomId, String userId) =>
      _repository.setOffline(roomId, userId);

  String inviteUrl(String roomId, String origin, String code) =>
      Uri.parse(origin).replace(
          path: '/room/join', queryParameters: {'code': code}).toString();
}

String normalizeRoomCodeValue(String code) =>
    code.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '').trim();

String generateRoomCode([int length = 6]) {
  const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final random = Random.secure();
  return List.generate(length, (_) => alphabet[random.nextInt(alphabet.length)])
      .join();
}
