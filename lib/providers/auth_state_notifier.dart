import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_profile.dart';
import '../repositories/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => createAuthRepository(),
);

final authStateProvider =
    StreamNotifierProvider<AuthStateNotifier, UserProfile?>(
  AuthStateNotifier.new,
);

class AuthStateNotifier extends StreamNotifier<UserProfile?> {
  @override
  Stream<UserProfile?> build() {
    return ref.watch(authRepositoryProvider).watchUser();
  }

  Future<void> signInWithGoogle() => _perform(
        ref.read(authRepositoryProvider).signInWithGoogle,
      );

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) =>
      _perform(
        () => ref.read(authRepositoryProvider).signInWithEmail(
              email: email,
              password: password,
            ),
      );

  Future<void> signUpWithEmail({
    required String email,
    required String password,
  }) =>
      _perform(
        () => ref.read(authRepositoryProvider).signUpWithEmail(
              email: email,
              password: password,
            ),
      );

  Future<void> signInAsGuest() => _perform(
        ref.read(authRepositoryProvider).signInAsGuest,
      );

  Future<void> signOut() => _perform(
        ref.read(authRepositoryProvider).signOut,
      );

  Future<void> updatePreferences(UserPreferences preferences) => _perform(
        () => ref.read(authRepositoryProvider).updatePreferences(preferences),
      );

  Future<void> _perform(Future<void> Function() action) async {
    await action();
  }

  Future<void> sendPasswordResetEmail(String email) =>
      ref.read(authRepositoryProvider).sendPasswordResetEmail(email);
}
