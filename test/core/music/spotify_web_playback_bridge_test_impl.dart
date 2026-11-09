// ignore: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:js';

import 'package:flutter_test/flutter_test.dart';
import 'package:vybe/core/music/providers/spotify/spotify_web_playback_bridge_web.dart';

void main() {
  setUp(() {
    context.callMethod('eval', [
      r'''
      window.Spotify = {
        Player: function(options) {
          const listeners = {};
          window.testSpotifyPlayer = this;
          this.addListener = (name, callback) => { listeners[name] = callback; };
          this.connect = () => {
            options.getOAuthToken(token => {
              window.testSpotifyToken = token;
              if (token === 'valid-token') {
                listeners.ready({device_id: 'device-1'});
              } else {
                listeners.authentication_error({message: 'Invalid token'});
              }
            });
            return Promise.resolve(true);
          };
          this.getCurrentState = () => Promise.resolve({paused: false, position: 1234});
          this.activateElement = () => Promise.resolve();
          this.pause = () => Promise.resolve();
          this.setVolume = value => { window.testSpotifyVolume = value; return Promise.resolve(); };
          this.disconnect = () => { window.testSpotifyDisconnected = true; };
        }
      };
      '''
    ]);
  });

  tearDown(() {
    for (final name in [
      'Spotify',
      'testSpotifyPlayer',
      'testSpotifyToken',
      'testSpotifyVolume',
      'testSpotifyDisconnected',
    ]) {
      context.deleteProperty(name);
    }
  });

  test('connects with a token and reads player state', () async {
    final bridge = WebSpotifyPlaybackBridge();
    await bridge
        .initialize(() async => 'valid-token')
        .timeout(const Duration(seconds: 5));
    expect(await bridge.deviceId, 'device-1');
    expect(context['testSpotifyToken'], 'valid-token');
    expect(await bridge.isPlaying(), isTrue);
    expect(await bridge.position(), const Duration(milliseconds: 1234));
    await bridge.activateElement();
    await bridge.pause();
    await bridge.setVolume(0.5);
    expect(context['testSpotifyVolume'], 0.5);
    await bridge.dispose();
    expect(context['testSpotifyDisconnected'], isTrue);
  });

  test('surfaces SDK authentication failures', () async {
    final bridge = WebSpotifyPlaybackBridge();
    await expectLater(
        bridge.initialize(() async => 'bad-token'),
        throwsA(isA<StateError>()
            .having((error) => error.message, 'message', 'Invalid token')));
    await bridge.dispose();
  });

  test('surfaces token retrieval failures', () async {
    final bridge = WebSpotifyPlaybackBridge();
    await expectLater(
        bridge.initialize(() async => throw StateError('Token refresh failed')),
        throwsA(isA<StateError>().having(
            (error) => error.message, 'message', 'Token refresh failed')));
    await bridge.dispose();
  });
}
