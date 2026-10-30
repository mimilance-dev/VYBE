import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/app_environment.dart';
import '../../core/music/providers/spotify/spotify_auth_service.dart';
import '../../core/music/providers/spotify/spotify_secure_storage.dart';

const spotifyCallbackPath = '/spotify-callback';

/// Uses the configured redirect URI, otherwise the current origin, so the same
/// build works from any host as long as the URI is registered with Spotify.
String resolveSpotifyRedirectUri({
  String configured = AppEnvironment.spotifyRedirectUri,
  Uri? base,
}) {
  if (configured.isNotEmpty) return configured;
  final origin = base ?? Uri.base;
  return Uri(
    scheme: origin.scheme,
    host: origin.host,
    port: origin.hasPort ? origin.port : null,
    path: spotifyCallbackPath,
  ).toString();
}

final spotifyAuthServiceProvider = Provider<SpotifyAuthService>(
  (ref) => SpotifyAuthService(
    clientId: AppEnvironment.spotifyClientId,
    redirectUri: resolveSpotifyRedirectUri(),
    storage: SpotifySecureStorage(),
  ),
);

/// Navigates the browser to Spotify in the same tab so the redirect returns
/// to this app instance.
final spotifyAuthorizationLauncherProvider =
    Provider<Future<bool> Function(Uri uri)>(
  (ref) => (uri) => launchUrl(uri, webOnlyWindowName: '_self'),
);

final spotifyConnectionProvider =
    AsyncNotifierProvider<SpotifyConnectionNotifier, bool>(
  SpotifyConnectionNotifier.new,
);

/// Tracks whether this browser holds Spotify tokens. It is independent of
/// Firebase Authentication.
class SpotifyConnectionNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    try {
      return await ref.read(spotifyAuthServiceProvider).loadTokens() != null;
    } catch (_) {
      return false;
    }
  }

  Future<void> connect() async {
    final auth = ref.read(spotifyAuthServiceProvider);
    // No scopes yet: playback permissions are requested when playback ships.
    final uri = await auth.createAuthorizationUri(scopes: const []);
    final opened = await ref.read(spotifyAuthorizationLauncherProvider)(uri);
    if (!opened) {
      throw const SpotifyAuthException('Could not open Spotify.');
    }
  }

  Future<void> completeAuthorization({
    String? code,
    String? returnedState,
    String? error,
  }) async {
    if (error != null && error.isNotEmpty) {
      throw SpotifyAuthException(error == 'access_denied'
          ? 'Spotify connection was cancelled.'
          : 'Spotify could not connect ($error).');
    }
    if (code == null ||
        code.isEmpty ||
        returnedState == null ||
        returnedState.isEmpty) {
      throw const SpotifyAuthException(
          'Spotify returned an incomplete response.');
    }
    await ref
        .read(spotifyAuthServiceProvider)
        .exchangeAuthorizationCode(code, returnedState);
    state = const AsyncData(true);
  }

  Future<void> disconnect() async {
    await ref.read(spotifyAuthServiceProvider).signOut();
    state = const AsyncData(false);
  }
}
