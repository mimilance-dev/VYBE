import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'spotify_auth_service.dart';

/// Browser storage is deliberately limited to the browser's origin and never
/// contains a Spotify client secret. A browser cannot provide hardware-backed
/// secrecy for long-lived OAuth refresh tokens; Flutter Secure Storage's web
/// implementation encrypts values in browser storage. Native platforms use
/// platform secure storage. Revoke access from Spotify when browser state is
/// untrusted.
class SpotifySecureStorage implements SpotifyTokenStorage {
  SpotifySecureStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();
  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);
  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);
  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}
