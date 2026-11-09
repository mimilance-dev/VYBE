// ignore: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html';
import 'dart:async';
// ignore: avoid_web_libraries_in_flutter, uri_does_not_exist
import 'dart:js_util' as js_util;

import 'spotify_web_playback_bridge_stub.dart';

export 'spotify_web_playback_bridge_stub.dart' show SpotifyWebPlaybackBridge;

SpotifyWebPlaybackBridge createSpotifyWebPlaybackBridge() =>
    WebSpotifyPlaybackBridge();

class WebSpotifyPlaybackBridge implements SpotifyWebPlaybackBridge {
  Object? _player;
  String? _deviceId;

  @override
  Future<void> initialize(Future<String?> Function() getAccessToken) async {
    if (_deviceId != null) return;
    final ready = Completer<void>();
    ScriptElement? script;
    StreamSubscription<Event>? scriptErrors;
    void fail(Object error, [StackTrace? stackTrace]) {
      if (!ready.isCompleted) ready.completeError(error, stackTrace);
    }

    void createPlayer() {
      unawaited(_createPlayer(getAccessToken, ready));
    }

    try {
      final spotify = js_util.getProperty<Object?>(window, 'Spotify');
      if (spotify == null) {
        js_util.setProperty(window, 'onSpotifyWebPlaybackSDKReady',
            js_util.allowInterop(createPlayer));
        script = ScriptElement()
          ..src = 'https://sdk.scdn.co/spotify-player.js'
          ..async = true;
        scriptErrors = script.onError.listen((_) {
          fail(StateError(
              'Spotify Playback SDK could not load. Check your connection and browser content blockers.'));
        });
        document.head!.append(script);
      } else {
        createPlayer();
      }
      await ready.future.timeout(const Duration(seconds: 30), onTimeout: () {
        throw StateError('Spotify player did not become ready. Check your '
            'connection and browser playback settings, then try again.');
      });
    } finally {
      await scriptErrors?.cancel();
    }
  }

  Future<void> _createPlayer(
      Future<String?> Function() getAccessToken, Completer<void> ready) async {
    void fail(Object error, [StackTrace? stackTrace]) {
      if (!ready.isCompleted) ready.completeError(error, stackTrace);
    }

    try {
      final spotify = js_util.getProperty<Object?>(window, 'Spotify');
      if (spotify == null || !js_util.hasProperty(spotify, 'Player')) {
        throw StateError('Spotify Playback SDK did not load.');
      }
      final player = js_util.callConstructor<Object>(
          js_util.getProperty<Object>(spotify, 'Player'), [
        js_util.jsify({
          'name': 'VYBE',
          'volume': 0.72,
          'getOAuthToken': js_util.allowInterop((Object callback) {
            Future<void>(() async {
              final token = await getAccessToken();
              if (token == null) {
                throw StateError(
                    'Spotify authorization expired. Reconnect Spotify from the home screen.');
              }
              js_util.callMethod<void>(callback, 'call', [null, token]);
            }).catchError((Object error, StackTrace stackTrace) {
              fail(error, stackTrace);
            });
          }),
        })
      ]);
      _player = player;
      js_util.callMethod<void>(player, 'addListener', [
        'ready',
        js_util.allowInterop((Object event) {
          final id = js_util.getProperty<String?>(event, 'device_id');
          if (id == null || id.isEmpty) {
            fail(StateError('Spotify did not provide a playback device.'));
            return;
          }
          _deviceId = id;
          if (!ready.isCompleted) ready.complete();
        })
      ]);
      for (final eventName in [
        'initialization_error',
        'authentication_error',
        'account_error',
      ]) {
        js_util.callMethod<void>(player, 'addListener', [
          eventName,
          js_util.allowInterop((Object event) {
            final message = js_util.getProperty<String?>(event, 'message');
            fail(StateError(message ?? 'Spotify player failed to start.'));
          })
        ]);
      }
      final promise = js_util.callMethod<Object>(player, 'connect', []);
      final connected = await js_util.promiseToFuture<bool>(promise);
      if (!connected) fail(StateError('Spotify player could not connect.'));
    } catch (error, stackTrace) {
      fail(error, stackTrace);
    }
  }

  Object get _readyPlayer =>
      _player ?? (throw StateError('Spotify player is not ready.'));

  Future<void> _promiseMethod(String method, [List<Object?> args = const []]) =>
      js_util.promiseToFuture<void>(
          js_util.callMethod<Object>(_readyPlayer, method, args));

  @override
  Future<String> get deviceId async =>
      _deviceId ?? (throw StateError('Spotify player is not ready.'));

  @override
  Future<void> activateElement() => _promiseMethod('activateElement');

  @override
  Future<void> pause() => _promiseMethod('pause');

  Future<Object?> _currentState() => js_util.promiseToFuture<Object?>(
      js_util.callMethod<Object>(_readyPlayer, 'getCurrentState', []));

  @override
  Future<bool> isPlaying() async {
    final state = await _currentState();
    return state != null && js_util.getProperty<bool>(state, 'paused') == false;
  }

  @override
  Future<Duration> position() async {
    final state = await _currentState();
    if (state == null) return Duration.zero;
    return Duration(
        milliseconds: (js_util.getProperty<num>(state, 'position')).round());
  }

  @override
  Future<void> setVolume(double volume) =>
      _promiseMethod('setVolume', [volume.clamp(0, 1)]);

  @override
  Future<void> dispose() async {
    final player = _player;
    _player = null;
    _deviceId = null;
    if (player != null) js_util.callMethod<void>(player, 'disconnect', []);
  }
}
