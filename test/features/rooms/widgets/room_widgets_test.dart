import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vybe/features/rooms/models/room_models.dart';
import 'package:vybe/features/rooms/pages/room_entry_page.dart';
import 'package:vybe/features/rooms/pages/room_page.dart';
import 'package:vybe/features/rooms/playback/listening_room_screen.dart';
import 'package:vybe/features/rooms/providers/room_providers.dart';
import 'package:vybe/features/rooms/services/room_service.dart';
import 'package:vybe/models/user_profile.dart';
import 'package:vybe/providers/auth_state_notifier.dart';

void main() {
  testWidgets('listening screen remains open when a participant disconnects',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final now = DateTime.now();
    final room = ListeningRoom(
      id: 'room',
      code: 'ABC123',
      hostId: 'you',
      participants: const ['you', 'alex'],
      createdAt: now,
      updatedAt: now,
      currentTrack: null,
      playbackState: RoomPlaybackState(
          provider: null,
          trackId: null,
          isPlaying: false,
          positionMs: 0,
          serverTimestamp: now,
          revision: 0),
      queue: const [],
      settings: const {},
    );
    RoomParticipant participant(String id, bool online) => RoomParticipant(
        userId: id,
        displayName: id,
        avatarUrl: null,
        joinedAt: now,
        lastSeenAt: now,
        isOnline: online);
    final participants = StreamController<List<RoomParticipant>>.broadcast();
    addTearDown(participants.close);
    await tester.pumpWidget(ProviderScope(overrides: [
      authStateProvider.overrideWith(_TestAuthStateNotifier.new),
      roomServiceProvider.overrideWithValue(_TestRoomService(room)),
      roomStreamProvider('room').overrideWith((ref) => Stream.value(room)),
      roomParticipantsStreamProvider('room')
          .overrideWith((ref) => participants.stream),
    ], child: const MaterialApp(home: RoomPage(roomId: 'room'))));
    await tester.pump();
    participants.add([participant('you', true), participant('alex', true)]);
    await tester.pump();
    expect(find.byType(ListeningRoomScreen), findsOneWidget);
    participants.add([participant('you', true), participant('alex', false)]);
    await tester.pump();
    expect(find.byType(ListeningRoomScreen), findsOneWidget);
    expect(find.text('Waiting to reconnect'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('join room renders the calm code entry flow', (tester) async {
    await tester.pumpWidget(_scope(const MaterialApp(
      home: JoinRoomPage(code: 'ABC123'),
    )));
    expect(find.text('Join a listening room'), findsOneWidget);
    expect(find.text('Room code'), findsOneWidget);
    expect(find.text('Join room'), findsOneWidget);
  });

  testWidgets('create room page offers a recoverable loading state',
      (tester) async {
    await tester.pumpWidget(_scope(const MaterialApp(home: CreateRoomPage())));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('listening room and search drawer render core controls',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final now = DateTime.now();
    final room = ListeningRoom(
      id: 'room',
      code: 'ABC123',
      hostId: 'alex',
      participants: const ['alex', 'you'],
      createdAt: now,
      updatedAt: now,
      currentTrack: const {
        'title': 'Midnight City',
        'artist': 'M83',
        'album': 'Hurry Up',
        'durationMs': 244000,
      },
      playbackState: RoomPlaybackState(
          provider: 'spotify',
          trackId: 'midnight-city',
          isPlaying: true,
          positionMs: 42000,
          serverTimestamp: now,
          revision: 2),
      queue: const [],
      settings: const {'name': 'Afterglow'},
      name: 'Afterglow',
    );
    final participants = [
      RoomParticipant(
          userId: 'alex',
          displayName: 'Alex',
          avatarUrl: null,
          joinedAt: now,
          lastSeenAt: now,
          isOnline: true),
      RoomParticipant(
          userId: 'you',
          displayName: 'Adithya',
          avatarUrl: null,
          joinedAt: now,
          lastSeenAt: now,
          isOnline: true),
    ];
    await tester.pumpWidget(_scope(MaterialApp(
        home: ListeningRoomScreen(
      room: room,
      participants: participants,
      userId: 'you',
      onLeave: () {},
    ))));
    await tester.pump();
    expect(find.text('Midnight City'), findsOneWidget);
    expect(find.text('Up next'), findsOneWidget);
    final progress = tester.widget<Slider>(find.byType(Slider).first).value;
    await tester.pump(const Duration(seconds: 3));
    expect(tester.widget<Slider>(find.byType(Slider).first).value,
        greaterThan(progress));
    await tester.tap(find.byTooltip('Queue').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('What do you want to hear?'), findsOneWidget);
  });
}

class _TestRoomService extends RoomService {
  _TestRoomService(this.room) : super(UnconfiguredRoomRepository());
  final ListeningRoom room;

  @override
  Future<ListeningRoom> enterRoom(
          {required String roomId,
          required String userId,
          required String displayName,
          String? avatarUrl}) async =>
      room;

  @override
  Future<void> heartbeat(String roomId, String userId) async {}
  @override
  Future<void> markOffline(String roomId, String userId) async {}
}

ProviderScope _scope(Widget child) => ProviderScope(
      overrides: [authStateProvider.overrideWith(_TestAuthStateNotifier.new)],
      child: child,
    );

class _TestAuthStateNotifier extends AuthStateNotifier {
  @override
  Stream<UserProfile?> build() => Stream.value(UserProfile(
        id: 'you',
        displayName: 'Adithya',
        email: 'you@example.com',
        createdAt: DateTime.utc(2026),
        lastSeenAt: DateTime.utc(2026),
      ));
}
