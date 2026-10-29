import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../models/user_profile.dart';
import '../services/auth_service.dart';

abstract interface class AuthRepository {
  Stream<UserProfile?> watchUser();

  Future<void> updatePreferences(UserPreferences preferences);

  Future<void> signInWithGoogle();

  Future<void> signInWithEmail({
    required String email,
    required String password,
  });

  Future<void> signUpWithEmail({
    required String email,
    required String password,
  });

  Future<void> signInAsGuest();

  Future<void> sendPasswordResetEmail(String email);

  Future<void> signOut();
}

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({
    required AuthService authService,
    required FirebaseFirestore firestore,
  })  : _authService = authService,
        _firestore = firestore;

  final AuthService _authService;
  final FirebaseFirestore _firestore;

  @override
  Stream<UserProfile?> watchUser() async* {
    await _authService.ensurePersistence();
    await for (final user in _authService.authStateChanges) {
      if (user == null) {
        yield null;
      } else {
        yield await _loadOrCreateProfile(user);
      }
    }
  }

  Future<UserProfile> _loadOrCreateProfile(User user) async {
    final now = DateTime.now();
    final profileRef = _firestore.collection('users').doc(user.uid);
    final existing = await profileRef.get();
    final profileData = <String, Object?>{
      'id': user.uid,
      'displayName': user.displayName,
      'email': user.email,
      'photoUrl': user.photoURL,
      'lastSeenAt': FieldValue.serverTimestamp(),
    };

    if (!existing.exists) {
      profileData['createdAt'] = FieldValue.serverTimestamp();
    }
    final existingPreferences =
        (existing.data()?['preferences'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{};
    profileData['preferences'] =
        UserPreferences.fromMap(existingPreferences).toMap();

    await profileRef.set(profileData, SetOptions(merge: true));
    final saved = await profileRef.get();
    return UserProfile.fromMap(
      saved.data() ?? profileData,
      id: user.uid,
      fallbackCreatedAt: user.metadata.creationTime ?? now,
      fallbackLastSeenAt: now,
    );
  }

  @override
  Future<void> updatePreferences(UserPreferences preferences) async {
    final user = _authService.currentUser;
    if (user == null) return;

    await _firestore.collection('users').doc(user.uid).set({
      'preferences': preferences.toMap(),
      'lastSeenAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> signInWithGoogle() => _authService.signInWithGoogle();

  @override
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) =>
      _authService.signInWithEmail(email: email, password: password);

  @override
  Future<void> signUpWithEmail({
    required String email,
    required String password,
  }) =>
      _authService.signUpWithEmail(email: email, password: password);

  @override
  Future<void> signInAsGuest() => _authService.signInAsGuest();

  @override
  Future<void> sendPasswordResetEmail(String email) =>
      _authService.sendPasswordResetEmail(email);

  @override
  Future<void> signOut() => _authService.signOut();
}

class UnconfiguredAuthRepository implements AuthRepository {
  const UnconfiguredAuthRepository();

  static FirebaseAuthException get _error => FirebaseAuthException(
        code: 'configuration-not-found',
        message: 'Firebase Authentication is not configured for this app.',
      );

  @override
  Stream<UserProfile?> watchUser() => Stream.value(null);

  @override
  Future<void> updatePreferences(UserPreferences preferences) =>
      Future<void>.value();

  @override
  Future<void> signInWithGoogle() => Future.error(_error);

  @override
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) =>
      Future.error(_error);

  @override
  Future<void> signUpWithEmail({
    required String email,
    required String password,
  }) =>
      Future.error(_error);

  @override
  Future<void> signInAsGuest() => Future.error(_error);

  @override
  Future<void> sendPasswordResetEmail(String email) => Future.error(_error);

  @override
  Future<void> signOut() => Future.error(_error);
}

AuthRepository createAuthRepository() {
  if (Firebase.apps.isEmpty) return const UnconfiguredAuthRepository();

  final firebaseAuth = FirebaseAuth.instance;
  return FirebaseAuthRepository(
    authService: AuthService(firebaseAuth),
    firestore: FirebaseFirestore.instance,
  );
}
