import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vybe/features/rooms/models/room_models.dart';
import 'package:vybe/features/rooms/pages/room_entry_page.dart';
import 'package:vybe/features/rooms/playback/listening_room_screen.dart';
import 'package:vybe/models/user_profile.dart';
import 'package:vybe/providers/auth_state_notifier.dart';

void main() {
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
    final now = DateTime.utc(2026);
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
          isPlaying: false,
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
    await tester.tap(find.byTooltip('Queue').first);
    await tester.pumpAndSettle();
    expect(find.text('What do you want to hear?'), findsOneWidget);
  });
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
