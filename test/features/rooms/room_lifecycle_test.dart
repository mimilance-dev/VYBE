import 'package:flutter_test/flutter_test.dart';
import 'package:vybe/features/rooms/models/room_models.dart';
import 'package:vybe/features/rooms/repositories/room_repository.dart';
import 'package:vybe/features/rooms/services/room_service.dart';
import 'package:vybe/features/rooms/playback/playback_command.dart';

void main() {
  test('room codes are six characters and human-friendly', () {
    for (var i = 0; i < 100; i++) {
      final code = generateRoomCode();
      expect(code, hasLength(6));
      expect(code, matches(RegExp(r'^[A-HJ-NP-Z2-9]+$')));
    }
  });

  test('room codes are normalized from links and pasted codes', () {
    expect(normalizeRoomCodeValue(' vybe-abc 123 '), 'VYBEABC123');
  });

  test('invite URLs carry the room code and stay on the join route', () {
    final service = RoomService(_LifecycleRepository());
    final invite = service.inviteUrl(
      'room-document-id',
      'https://vybe.example',
      'VYBE42',
    );
    expect(Uri.parse(invite).path, '/room/join');
    expect(Uri.parse(invite).queryParameters['code'], 'VYBE42');
  });

  test('rejoined participant keeps their original seat and identity', () {
    final participant = RoomParticipant(
      userId: 'u1',
      displayName: 'Ada',
      avatarUrl: null,
      joinedAt: DateTime(2026, 1, 1),
      lastSeenAt: DateTime.now(),
      isOnline: false,
    );
    expect(participant.copyWith(isOnline: true).userId, 'u1');
    expect(participant.copyWith(isOnline: true).connected, isTrue);
  });

  test('presence requires both online and a fresh heartbeat', () {
    final participant = RoomParticipant(
      userId: 'u1',
      displayName: 'Ada',
      avatarUrl: null,
      joinedAt: DateTime.now(),
      lastSeenAt: DateTime.now(),
      isOnline: true,
    );
    expect(participant.connected, isTrue);
    expect(participant.copyWith(isOnline: false).connected, isFalse);
    expect(
        participant
            .copyWith(
                lastSeenAt: DateTime.now().subtract(const Duration(minutes: 1)))
            .connected,
        isFalse);
  });
}

class _LifecycleRepository implements RoomRepository {
  @override
  Future<ListeningRoom> createRoom({
    required String hostId,
    required String displayName,
    String? avatarUrl,
    required String code,
    String? name,
  }) =>
      Future.value(_room(code: code));

  @override
  Future<ListeningRoom?> findByCode(String code) async => _room(code: code);

  @override
  Future<ListeningRoom?> findById(String roomId) async => _room(id: roomId);

  @override
  Future<ListeningRoom> joinByCode({
    required String code,
    required String userId,
    required String displayName,
    String? avatarUrl,
  }) async =>
      _room(code: code);

  @override
  Future<ListeningRoom> joinById({
    required String roomId,
    required String userId,
    required String displayName,
    String? avatarUrl,
  }) async =>
      _room(id: roomId);

  @override
  Stream<ListeningRoom?> watchRoom(String roomId) => const Stream.empty();

  @override
  Stream<List<RoomParticipant>> watchParticipants(String roomId) =>
      const Stream.empty();

  @override
  Future<void> setOnline(String roomId, RoomParticipant participant) async {}

  @override
  Future<void> heartbeat(String roomId, String userId) async {}

  @override
  Future<void> setOffline(String roomId, String userId) async {}

  @override
  Future<void> leave(String roomId, String userId) async {}

  @override
  Future<void> submitPlaybackCommand(String roomId, PlaybackCommand command) async {}

  @override
  Future<void> submitPlaybackCheckpoint(String roomId, String userId, int positionMs) async {}

  ListeningRoom _room({String id = 'room-id', String code = 'VYBE42'}) {
    final now = DateTime.now();
    return ListeningRoom(
      id: id,
      code: code,
      hostId: 'host',
      participants: const ['host'],
      createdAt: now,
      updatedAt: now,
      currentTrack: null,
      playbackState: RoomPlaybackState(
        provider: null,
        trackId: null,
        isPlaying: false,
        positionMs: 0,
        serverTimestamp: now,
        revision: 0,
      ),
      queue: const [],
      settings: const {},
    );
  }
}
