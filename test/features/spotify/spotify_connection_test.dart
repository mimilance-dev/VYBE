import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vybe/core/music/providers/spotify/spotify_auth_service.dart';
import 'package:vybe/features/spotify/spotify_connection.dart';

class _MemoryStorage implements SpotifyTokenStorage {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
  @override
  Future<void> delete(String key) async => values.remove(key);
}

void main() {
  test('redirect URI prefers configuration, then the current origin', () {
    expect(
      resolveSpotifyRedirectUri(
          configured: 'https://configured.test/spotify-callback'),
      'https://configured.test/spotify-callback',
    );
    expect(
      resolveSpotifyRedirectUri(
        configured: '',
        base: Uri.parse('https://8080-demo.app.github.dev/home?x=1#frag'),
      ),
      'https://8080-demo.app.github.dev/spotify-callback',
    );
  });

  group('connection', () {
    late _MemoryStorage storage;
    late Uri? launched;
    late ProviderContainer container;

    setUp(() {
      storage = _MemoryStorage();
      launched = null;
      container = ProviderContainer(overrides: [
        spotifyAuthServiceProvider.overrideWithValue(SpotifyAuthService(
          clientId: 'public-client-id',
          redirectUri: 'https://example.test/spotify-callback',
          storage: storage,
          httpClient: MockClient((request) async {
            expect(request.bodyFields['grant_type'], 'authorization_code');
            expect(request.bodyFields['code_verifier'], isNotEmpty);
            expect(request.bodyFields, isNot(contains('client_secret')));
            return http.Response(
                '{"access_token":"a","refresh_token":"r","expires_in":3600}',
                200);
          }),
        )),
        spotifyAuthorizationLauncherProvider.overrideWithValue((uri) async {
          launched = uri;
          return true;
        }),
      ]);
      addTearDown(container.dispose);
    });

    test('connect launches a PKCE request without scopes or secrets',
        () async {
      await container.read(spotifyConnectionProvider.future);
      await container.read(spotifyConnectionProvider.notifier).connect();

      final params = launched!.queryParameters;
      expect(launched!.host, 'accounts.spotify.com');
      expect(params['redirect_uri'], 'https://example.test/spotify-callback');
      expect(params['code_challenge_method'], 'S256');
      expect(params, isNot(contains('scope')));
      expect(params, isNot(contains('client_secret')));
    });

    test('callback exchanges the code and marks Spotify connected', () async {
      expect(await container.read(spotifyConnectionProvider.future), isFalse);
      await container.read(spotifyConnectionProvider.notifier).connect();
      final state = launched!.queryParameters['state'];

      await container
          .read(spotifyConnectionProvider.notifier)
          .completeAuthorization(code: 'auth-code', returnedState: state);

      expect(container.read(spotifyConnectionProvider).value, isTrue);
      expect(storage.values['spotify_tokens'], contains('"accessToken":"a"'));
      expect(storage.values, isNot(contains('spotify_pkce')));
    });

    test('callback rejects a mismatched state', () async {
      await container.read(spotifyConnectionProvider.notifier).connect();

      expect(
        container
            .read(spotifyConnectionProvider.notifier)
            .completeAuthorization(code: 'auth-code', returnedState: 'forged'),
        throwsA(isA<SpotifyAuthException>()),
      );
      expect(storage.values, isNot(contains('spotify_tokens')));
    });

    test('callback reports a cancelled authorization', () async {
      expect(
        container
            .read(spotifyConnectionProvider.notifier)
            .completeAuthorization(error: 'access_denied'),
        throwsA(isA<SpotifyAuthException>().having(
            (e) => e.message, 'message', contains('cancelled'))),
      );
    });

    test('disconnect clears stored tokens', () async {
      storage.values['spotify_tokens'] = 'tokens';
      await container.read(spotifyConnectionProvider.notifier).disconnect();

      expect(container.read(spotifyConnectionProvider).value, isFalse);
      expect(storage.values, isEmpty);
    });
  });
}
