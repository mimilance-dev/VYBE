import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vybe/app.dart';
import 'package:vybe/models/user_profile.dart';
import 'package:vybe/providers/auth_state_notifier.dart';
import 'package:vybe/repositories/auth_repository.dart';
import 'package:vybe/routing/app_router.dart';

void main() {
  test('login and logout update the auth state', () async {
    final repository = FakeAuthRepository();
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    addTearDown(repository.dispose);

    final subscription = container.listen(authStateProvider, (_, __) {});
    addTearDown(subscription.close);
    await container.read(authStateProvider.future);

    await container.read(authStateProvider.notifier).signInWithEmail(
          email: 'listener@example.com',
          password: 'a-secure-password',
        );
    await _waitFor(container, (state) => state.valueOrNull != null);
    expect(container.read(authStateProvider).valueOrNull?.email,
        'listener@example.com');

    await container.read(authStateProvider.notifier).signOut();
    await _waitFor(container, (state) => state.hasValue && state.value == null);
    expect(container.read(authStateProvider).valueOrNull, isNull);
  });

  test('restores an existing session from the auth stream', () async {
    final user = _profile('restored-user');
    final repository = FakeAuthRepository(initialUser: user);
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    addTearDown(repository.dispose);

    expect((await container.read(authStateProvider.future))?.id, user.id);
  });

  testWidgets('unauthorized home access redirects and sign-in unlocks it',
      (tester) async {
    final repository = FakeAuthRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(repository)],
        child: const VybeApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();

    final context = tester.element(find.byType(MaterialApp));
    ProviderScope.containerOf(context, listen: false)
        .read(appRouterProvider)
        .go('/home');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();
    expect(find.text('Welcome back'), findsOneWidget);

    await tester.tap(find.text('Continue with Google'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();
    expect(find.text('Your listening rooms will live here.'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await repository.dispose();
  });

  testWidgets('authenticated session redirects login to home', (tester) async {
    final repository = FakeAuthRepository(initialUser: _profile('signed-in'));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(repository)],
        child: const VybeApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();

    final context = tester.element(find.byType(MaterialApp));
    ProviderScope.containerOf(context, listen: false)
        .read(appRouterProvider)
        .go('/login');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();

    expect(find.text('Your listening rooms will live here.'), findsOneWidget);
    expect(find.text('Welcome back'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await repository.dispose();
  });
}

Future<void> _waitFor(
  ProviderContainer container,
  bool Function(AsyncValue<UserProfile?> state) predicate,
) async {
  if (predicate(container.read(authStateProvider))) return;
  final completer = Completer<void>();
  final subscription = container.listen(authStateProvider, (_, next) {
    if (!completer.isCompleted && predicate(next)) completer.complete();
  });
  await completer.future.timeout(const Duration(seconds: 2));
  subscription.close();
}

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({UserProfile? initialUser}) : _user = initialUser;

  final StreamController<UserProfile?> _changes =
      StreamController<UserProfile?>.broadcast();
  UserProfile? _user;

  @override
  Stream<UserProfile?> watchUser() => Stream<UserProfile?>.multi((controller) {
        controller.add(_user);
        final subscription = _changes.stream.listen(controller.add);
        controller.onCancel = subscription.cancel;
      });

  @override
  Future<void> signInWithGoogle() async => _setUser(_profile('google-user'));

  @override
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    _setUser(_profile('email-user', email: email));
  }

  @override
  Future<void> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    _setUser(_profile('new-user', email: email));
  }

  @override
  Future<void> signInAsGuest() async => _setUser(_profile('guest-user'));

  @override
  Future<void> sendPasswordResetEmail(String email) async {}

  @override
  Future<void> signOut() async => _setUser(null);

  void _setUser(UserProfile? user) {
    _user = user;
    _changes.add(user);
  }

  Future<void> dispose() => _changes.close();
}

UserProfile _profile(String id, {String? email}) {
  final now = DateTime.utc(2025);
  return UserProfile(
    id: id,
    email: email ?? '$id@example.com',
    displayName: 'Listener',
    createdAt: now,
    lastSeenAt: now,
  );
}