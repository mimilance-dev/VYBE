import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vybe/core/music/models/music_models.dart';
import 'package:vybe/core/music/providers/spotify/spotify_api_client.dart';
import 'package:vybe/core/music/providers/spotify/spotify_auth_service.dart';
import 'package:vybe/core/music/providers/spotify_music_provider.dart';

class MemorySpotifyStorage implements SpotifyTokenStorage {
  final Map<String, String> values = {};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

void main() {
  test('Spotify authorization uses PKCE and never accepts a client secret',
      () async {
    final storage = MemorySpotifyStorage();
    final auth = SpotifyAuthService(
        clientId: 'public-client-id',
        redirectUri: 'https://example.test/spotify-callback',
        storage: storage);
    final uri = await auth.createAuthorizationUri(state: 'expected-state');
    expect(uri.host, 'accounts.spotify.com');
    expect(uri.queryParameters['code_challenge_method'], 'S256');
    expect(uri.queryParameters['code_challenge'], isNotEmpty);
    expect(uri.queryParameters['client_id'], 'public-client-id');
    expect(uri.queryParameters, isNot(contains('client_secret')));
  });

  test('Spotify API maps track metadata and artwork', () async {
    final storage = MemorySpotifyStorage();
    await storage.write(
        'spotify_tokens',
        SpotifyTokens(
                accessToken: 'token',
                expiresAt: DateTime.now().add(const Duration(hours: 1)),
                scope: '')
            .toJson()
            .toString());
    // Store JSON without braces added by toString; use a direct JSON encoder shape.
    await storage.write(
        'spotify_tokens',
        '{"accessToken":"token",'
            '"expiresAt":"${DateTime.now().add(const Duration(hours: 1)).toIso8601String()}","scope":""}');
    final auth = SpotifyAuthService(
        clientId: 'client',
        redirectUri: 'https://example.test/callback',
        storage: storage);
    final client = SpotifyApiClient(auth,
        httpClient: MockClient((request) async => http.Response(
            '{'
            '"id":"track-id","name":"Night Drive","duration_ms":180000,'
            '"external_urls":{"spotify":"https://open.spotify.com/track/track-id"},'
            '"preview_url":null,"artists":[{"name":"VYBE"}],'
            '"album":{"id":"album-id","name":"Night","external_urls":{"spotify":"https://open.spotify.com/album/album-id"},'
            '"images":[{"url":"https://example.test/cover.jpg"}]}}',
            200)));
    final track = await client.getTrack('track-id');
    expect(track?.title, 'Night Drive');
    expect(track?.albumArtUrl, contains('cover.jpg'));
  });

  test('Spotify API sends bearer tokens and supports queue commands', () async {
    final storage = MemorySpotifyStorage();
    await storage.write('spotify_tokens',
        '{"accessToken":"access","expiresAt":"${DateTime.now().add(const Duration(hours: 1)).toIso8601String()}","scope":"user-modify-playback-state"}');
    final auth = SpotifyAuthService(
      clientId: 'client',
      redirectUri: 'https://example.test/callback',
      storage: storage,
    );
    late http.Request captured;
    final client =
        SpotifyApiClient(auth, httpClient: MockClient((request) async {
      captured = request;
      return http.Response('', 204);
    }));
    await client.addToQueue(const Track(
      id: 'queue-track',
      provider: MusicProviderId.spotify,
      title: 'Queued',
      artist: 'Artist',
      durationMs: 180000,
      externalUrl: 'https://open.spotify.com/track/queue-track',
    ));
    expect(captured.headers['authorization'], 'Bearer access');
    expect(captured.url.queryParameters['uri'], 'spotify:track:queue-track');
  });

  test('Spotify refreshes expired tokens through PKCE client id flow',
      () async {
    final storage = MemorySpotifyStorage();
    await storage.write('spotify_tokens',
        '{"accessToken":"expired","refreshToken":"refresh-value","expiresAt":"${DateTime.now().subtract(const Duration(hours: 1)).toIso8601String()}","scope":"user-modify-playback-state"}');
    final auth = SpotifyAuthService(
      clientId: 'public-client-id',
      redirectUri: 'https://example.test/callback',
      storage: storage,
      httpClient: MockClient((request) async => http.Response(
            '{"access_token":"fresh","expires_in":3600,"scope":"user-modify-playback-state"}',
            200,
            headers: {'content-type': 'application/json'},
          )),
    );
    expect(await auth.validAccessToken(), 'fresh');
    final refreshed = await auth.loadTokens();
    expect(refreshed?.refreshToken, 'refresh-value');
  });

  test('Spotify sign out clears browser and OAuth state', () async {
    final storage = MemorySpotifyStorage();
    await storage.write('spotify_tokens', 'tokens');
    await storage.write('spotify_pkce', 'verifier');
    final auth = SpotifyAuthService(
      clientId: 'client',
      redirectUri: 'https://example.test/callback',
      storage: storage,
    );
    await auth.signOut();
    expect(storage.values, isEmpty);
  });

  test('Spotify capability flags hide unsupported controls', () {
    final provider = SpotifyMusicProvider(
        searchTracks: (_) async => [],
        supportsPlayback: false,
        supportsSeek: false,
        supportsQueue: true);
    expect(provider.capabilities.supportsSearch, isTrue);
    expect(provider.capabilities.supportsMetadata, isTrue);
    expect(provider.capabilities.supportsPlayback, isFalse);
    expect(provider.capabilities.supportsSeek, isFalse);
    expect(provider.capabilities.supportsQueue, isTrue);
  });
}
