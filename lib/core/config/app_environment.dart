import 'package:firebase_core/firebase_core.dart';

abstract final class AppEnvironment {
  static const firebaseApiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const firebaseAppId = String.fromEnvironment('FIREBASE_APP_ID');
  static const firebaseMessagingSenderId =
      String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  static const firebaseProjectId =
      String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const firebaseAuthDomain =
      String.fromEnvironment('FIREBASE_AUTH_DOMAIN');
  static const spotifyClientId = String.fromEnvironment('SPOTIFY_CLIENT_ID');
  static const spotifyRedirectUri = String.fromEnvironment('SPOTIFY_REDIRECT_URI');

  static const firebaseStorageBucket =
      String.fromEnvironment('FIREBASE_STORAGE_BUCKET');

  static FirebaseOptions? get firebaseOptions {
    if (firebaseApiKey.isEmpty ||
        firebaseAppId.isEmpty ||
        firebaseMessagingSenderId.isEmpty ||
        firebaseProjectId.isEmpty) {
      return null;
    }

    return FirebaseOptions(
      apiKey: firebaseApiKey,
      appId: firebaseAppId,
      messagingSenderId: firebaseMessagingSenderId,
      projectId: firebaseProjectId,
      authDomain: firebaseAuthDomain.isEmpty ? null : firebaseAuthDomain,
      storageBucket:
          firebaseStorageBucket.isEmpty ? null : firebaseStorageBucket,
    );
  }
}