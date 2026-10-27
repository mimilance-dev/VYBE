import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vybe/features/home/home_page.dart';
import 'package:vybe/models/user_profile.dart';
import 'package:vybe/providers/auth_state_notifier.dart';

void main() {
  for (final viewport in [
    const Size(390, 844),
    const Size(768, 1024),
    const Size(1440, 900),
  ]) {
    testWidgets('home screen fits ${viewport.width.toInt()}px viewport',
        (tester) async {
      tester.view.physicalSize = viewport;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith(_TestAuthStateNotifier.new),
          ],
          child: const MaterialApp(home: HomePage()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 700));

      expect(find.text('Good afternoon, Adithya'), findsOneWidget);
      expect(find.text('Who do you want to listen with?'), findsOneWidget);
      expect(find.text('CREATE A ROOM'), findsOneWidget);
      expect(find.text('JOIN A ROOM'), findsOneWidget);
      expect(find.text('Recent rooms'), findsOneWidget);
      expect(find.text('Recently played'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('join flow asks for a code and reports unavailable backend',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(_TestAuthStateNotifier.new),
        ],
        child: const MaterialApp(home: HomePage()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 700));
    await tester.tap(find.text('JOIN A ROOM'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Room code'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'VYBE-1234');
    await tester.tap(find.text('Join room'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Joining rooms is not connected yet.'), findsOneWidget);
  });
}

class _TestAuthStateNotifier extends AuthStateNotifier {
  @override
  Stream<UserProfile?> build() {
    final now = DateTime(2026, 10, 27);
    return Stream.value(
      UserProfile(
        id: 'test-user',
        displayName: 'Adithya',
        email: 'adithya@example.com',
        createdAt: now,
        lastSeenAt: now,
      ),
    );
  }
}
