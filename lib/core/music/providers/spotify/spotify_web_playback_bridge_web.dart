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
  static Future<void>? _sdkLoading;
  Object? _player;
  String? _deviceId;
  Future<void>? _initializing;
  Completer<void>? _ready;
  int _generation = 0;

  @override
  Future<void> initialize(Future<String?> Function() getAccessToken) {
    if (_deviceId != null) return Future.value();
    return _initializing ??= _initialize(getAccessToken).whenComplete(() {
      _initializing = null;
    });
  }

  static bool get _sdkReady {
    final spotify = js_util.getProperty<Object?>(window, 'Spotify');
    return spotify != null && js_util.hasProperty(spotify, 'Player');
  }

  static Future<void> _loadSdk() {
    if (_sdkReady) return Future.value();
    return _sdkLoading ??= _loadSdkOnce().whenComplete(() {
      _sdkLoading = null;
    });
  }

  static Future<void> _loadSdkOnce() async {
    final ready = Completer<void>();
    final previous =
        js_util.getProperty<Object?>(window, 'onSpotifyWebPlaybackSDKReady');
    final script = ScriptElement()
      ..src = 'https://sdk.scdn.co/spotify-player.js'
      ..async = true;
    final callback = js_util.allowInterop(() {
      if (previous != null) {
        js_util.callMethod<void>(previous, 'call', [window]);
      }
      if (!ready.isCompleted) {
        if (_sdkReady) {
          ready.complete();
        } else {
          ready.completeError(StateError('Spotify Playback SDK did not load.'));
        }
      }
    });
    js_util.setProperty(window, 'onSpotifyWebPlaybackSDKReady', callback);
    final errors = script.onError.listen((_) {
      if (!ready.isCompleted) {
        ready.completeError(StateError(
            'Spotify Playback SDK could not load. Check your connection and browser content blockers.'));
      }
    });
    document.head!.append(script);
    try {
      await ready.future.timeout(const Duration(seconds: 30), onTimeout: () {
        throw StateError('Spotify Playback SDK did not load. Check your '
            'connection and browser content blockers, then try again.');
      });
    } finally {
      await errors.cancel();
      if (js_util.getProperty<Object?>(
              window, 'onSpotifyWebPlaybackSDKReady') ==
          callback) {
        js_util.setProperty(window, 'onSpotifyWebPlaybackSDKReady', previous);
      }
      if (!_sdkReady) script.remove();
    }
  }

  Future<void> _initialize(Future<String?> Function() getAccessToken) async {
    if (_deviceId != null) return;
    final generation = ++_generation;
    await _loadSdk();
    if (generation != _generation) {
      throw StateError('Spotify player initialization was cancelled.');
    }
    final ready = Completer<void>();
    _ready = ready;
    try {
      unawaited(_createPlayer(getAccessToken, ready, generation));
      await ready.future.timeout(const Duration(seconds: 30), onTimeout: () {
        throw StateError('Spotify player did not become ready. Make sure your '
            'account has Premium, Spotify playback is allowed in this browser, '
            'and content blockers are disabled, then try again.');
      });
    } catch (_) {
      await dispose();
      rethrow;
    } finally {
      if (identical(_ready, ready)) _ready = null;
    }
  }

  Future<void> _createPlayer(Future<String?> Function() getAccessToken,
      Completer<void> ready, int generation) async {
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
              if (generation != _generation) return;
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
          if (generation != _generation) return;
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
    _generation++;
    final ready = _ready;
    if (ready != null && !ready.isCompleted) {
      ready.completeError(
          StateError('Spotify player initialization was cancelled.'));
    }
    final player = _player;
    _player = null;
    _deviceId = null;
    if (player != null) js_util.callMethod<void>(player, 'disconnect', []);
  }
}
