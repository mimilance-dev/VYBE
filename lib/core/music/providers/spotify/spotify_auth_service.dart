import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

class SpotifyTokens {
  const SpotifyTokens(
      {required this.accessToken,
      this.refreshToken,
      required this.expiresAt,
      required this.scope});
  final String accessToken;
  final String? refreshToken;
  final DateTime expiresAt;
  final String scope;

  Map<String, Object?> toJson() => {
        'accessToken': accessToken,
        'refreshToken': refreshToken,
        'expiresAt': expiresAt.toIso8601String(),
        'scope': scope,
      };
  factory SpotifyTokens.fromJson(String source) {
    final json = jsonDecode(source) as Map<String, dynamic>;
    return SpotifyTokens(
        accessToken: json['accessToken'] as String,
        refreshToken: json['refreshToken'] as String?,
        expiresAt: DateTime.parse(json['expiresAt'] as String),
        scope: json['scope'] as String? ?? '');
  }
}

abstract class SpotifyTokenStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class SpotifyAuthException implements Exception {
  const SpotifyAuthException(this.message);
  final String message;
  @override
  String toString() => message;
}

class SpotifyAuthService {
  SpotifyAuthService(
      {required this.clientId,
      required this.redirectUri,
      required this.storage,
      http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  static const authorizationEndpoint = 'https://accounts.spotify.com/authorize';
  static const tokenEndpoint = 'https://accounts.spotify.com/api/token';
  // Public search/track metadata only need an authenticated bearer token.
  // Playback controls require the player scopes below and are all Premium gated
  // at the Spotify account/device layer. 'streaming' enables a browser SDK
  // player but does not turn search-capable accounts into playable devices.
  static const defaultScopes = 'user-read-playback-state '
      'user-read-currently-playing user-modify-playback-state streaming';

  final String clientId;
  final String redirectUri;
  final SpotifyTokenStorage storage;
  final http.Client _http;

  Future<Uri> createAuthorizationUri(
      {String? state, List<String>? scopes}) async {
    if (clientId.isEmpty) {
      throw const SpotifyAuthException('SPOTIFY_CLIENT_ID is not configured.');
    }
    final verifier = _secureRandomString(96);
    final challenge = base64Url
        .encode(sha256.convert(ascii.encode(verifier)).bytes)
        .replaceAll('=', '');
    await storage.write(
        'spotify_pkce',
        jsonEncode(
            {'verifier': verifier, 'state': state ?? _secureRandomString(24)}));
    final effectiveState = state ??
        jsonDecode(await storage.read('spotify_pkce') ?? '{}')['state'];
    return Uri.parse(authorizationEndpoint).replace(queryParameters: {
      'client_id': clientId,
      'response_type': 'code',
      'redirect_uri': redirectUri,
      'code_challenge_method': 'S256',
      'code_challenge': challenge,
      'state': effectiveState as String,
      'scope': (scopes ?? defaultScopes.split(' ')).join(' '),
    });
  }

  Future<SpotifyTokens> exchangeAuthorizationCode(
      String code, String expectedState) async {
    final pending = jsonDecode(await storage.read('spotify_pkce') ?? '{}')
            as Map<String, dynamic>? ??
        {};
    if (pending['state'] != expectedState) {
      throw const SpotifyAuthException('OAuth state validation failed.');
    }
    final response = await _http.post(Uri.parse(tokenEndpoint), headers: {
      'Content-Type': 'application/x-www-form-urlencoded'
    }, body: {
      'grant_type': 'authorization_code',
      'code': code,
      'redirect_uri': redirectUri,
      'client_id': clientId,
      'code_verifier': pending['verifier'] as String,
    });
    final tokens = await _parseTokenResponse(response);
    await storage.delete('spotify_pkce');
    return tokens;
  }

  Future<void> signOut() async {
    await storage.delete('spotify_tokens');
    await storage.delete('spotify_pkce');
  }

  Future<SpotifyTokens?> loadTokens() async {
    final json = await storage.read('spotify_tokens');
    if (json == null) return null;
    try {
      return SpotifyTokens.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  Future<String?> validAccessToken() async {
    var tokens = await loadTokens();
    if (tokens == null) return null;
    if (tokens.expiresAt
        .isAfter(DateTime.now().add(const Duration(minutes: 1)))) {
      return tokens.accessToken;
    }
    if (tokens.refreshToken == null) return null;
    tokens = await refresh(tokens.refreshToken!);
    return tokens.accessToken;
  }

  Future<SpotifyTokens> refresh(String refreshToken) async {
    final previous = await loadTokens();
    final response = await _http.post(Uri.parse(tokenEndpoint), headers: {
      'Content-Type': 'application/x-www-form-urlencoded'
    }, body: {
      'grant_type': 'refresh_token',
      'refresh_token': refreshToken,
      'client_id': clientId,
    });
    final result = await _parseTokenResponse(response);
    final combined = SpotifyTokens(
        accessToken: result.accessToken,
        refreshToken: result.refreshToken ?? previous?.refreshToken,
        expiresAt: result.expiresAt,
        scope: result.scope);
    await storage.write('spotify_tokens', jsonEncode(combined.toJson()));
    return combined;
  }

  Future<SpotifyTokens> _parseTokenResponse(http.Response response) async {
    Map<String, dynamic> json;
    try {
      json = jsonDecode(response.body) as Map<String, dynamic>;
    } on FormatException {
      throw const SpotifyAuthException(
          'Spotify returned an invalid token response.');
    }
    if (response.statusCode >= 400) {
      throw SpotifyAuthException(json['error_description'] as String? ??
          'Spotify authorization failed.');
    }
    final expiresIn = (json['expires_in'] as num).toInt();
    final tokens = SpotifyTokens(
        accessToken: json['access_token'] as String,
        refreshToken: json['refresh_token'] as String?,
        expiresAt: DateTime.now().add(Duration(seconds: expiresIn)),
        scope: json['scope'] as String? ?? '');
    await storage.write('spotify_tokens', jsonEncode(tokens.toJson()));
    return tokens;
  }

  static String _secureRandomString(int length) {
    const alphabet =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
    final random = Random.secure();
    return List.generate(
        length, (_) => alphabet[random.nextInt(alphabet.length)]).join();
  }
}
