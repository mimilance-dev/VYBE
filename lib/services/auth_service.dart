import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  AuthService(this._firebaseAuth);

  final FirebaseAuth _firebaseAuth;
  Future<void>? _persistenceSetup;

  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  Future<void> ensurePersistence() {
    if (!kIsWeb) return Future<void>.value();
    return _persistenceSetup ??=
        _firebaseAuth.setPersistence(Persistence.LOCAL);
  }

  Future<void> signInWithGoogle() async {
    await ensurePersistence();
    final provider = GoogleAuthProvider();
    final currentUser = _firebaseAuth.currentUser;
    if (currentUser?.isAnonymous ?? false) {
      await currentUser!.linkWithPopup(provider);
    } else {
      await _firebaseAuth.signInWithPopup(provider);
    }
  }

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    await ensurePersistence();
    await _firebaseAuth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    await ensurePersistence();
    final currentUser = _firebaseAuth.currentUser;
    final credential = EmailAuthProvider.credential(
      email: email.trim(),
      password: password,
    );

    if (currentUser?.isAnonymous ?? false) {
      await currentUser!.linkWithCredential(credential);
    } else {
      await _firebaseAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    }
  }

  Future<void> signInAsGuest() async {
    await ensurePersistence();
    await _firebaseAuth.signInAnonymously();
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await ensurePersistence();
    await _firebaseAuth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> signOut() => _firebaseAuth.signOut();
}