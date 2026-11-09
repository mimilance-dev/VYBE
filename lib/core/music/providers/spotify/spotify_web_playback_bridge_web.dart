// ignore: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html';
// ignore: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:js';
import 'dart:async';
import 'dart:js_util' as js_util;

import 'spotify_web_playback_bridge_stub.dart';

export 'spotify_web_playback_bridge_stub.dart' show SpotifyWebPlaybackBridge;

SpotifyWebPlaybackBridge createSpotifyWebPlaybackBridge() =>
    WebSpotifyPlaybackBridge();

class WebSpotifyPlaybackBridge implements SpotifyWebPlaybackBridge {
  JsObject? _player;
  String? _deviceId;

  @override
  Future<void> initialize(Future<String?> Function() getAccessToken) async {
    if (_player != null) return;
    final ready = Completer<void>();
    if (context['Spotify'] == null) {
      context['onSpotifyWebPlaybackSDKReady'] = allowInterop(() {
        unawaited(_createPlayer(getAccessToken, ready));
      });
      final script = ScriptElement()
        ..src = 'https://sdk.scdn.co/spotify-player.js'
        ..async = true;
      document.head?.append(script);
    } else {
      await _createPlayer(getAccessToken, ready);
    }
    await ready.future.timeout(const Duration(seconds: 30));
  }

  Future<void> _createPlayer(
      Future<String?> Function() getAccessToken, Completer<void> ready) async {
    try {
      final spotify = context['Spotify'];
      if (spotify == null || spotify['Player'] == null) {
        if (!ready.isCompleted) {
          ready.completeError(StateError('Spotify Playback SDK did not load.'));
        }
        return;
      }
      _player = JsObject(spotify['Player'] as JsFunction, [
        JsObject.jsify({
          'name': 'VYBE',
          'volume': 0.72,
          'getOAuthToken': allowInterop((JsFunction callback) async {
            final token = await getAccessToken();
            if (token == null) {
              throw StateError('Connect Spotify to enable browser playback.');
            }
            callback.apply([token]);
          }),
        })
      ]);
      _player!.callMethod('addListener', [
        'ready',
        allowInterop((JsObject event) {
          _deviceId = event['device_id'] as String?;
          if (!ready.isCompleted) ready.complete();
        })
      ]);
      _player!.callMethod('addListener', [
        'initialization_error',
        allowInterop((JsObject event) {
          if (!ready.isCompleted) {
            ready.completeError(StateError(event['message'] as String? ??
                'Spotify player failed to initialize.'));
          }
        })
      ]);
      final connected = await js_util
          .promiseToFuture<bool>(_player!.callMethod('connect') as Object);
      if (!connected && !ready.isCompleted) {
        ready.completeError(StateError('Spotify player could not connect.'));
      }
    } catch (error, stackTrace) {
      if (!ready.isCompleted) ready.completeError(error, stackTrace);
    }
  }

  @override
  Future<String> get deviceId async {
    final id = _deviceId;
    if (id == null) throw StateError('Spotify player is not ready.');
    return id;
  }

  @override
  Future<void> activateElement() async {
    final player = _player;
    if (player == null) throw StateError('Spotify player is not ready.');
    await js_util
        .promiseToFuture<void>(player.callMethod('activateElement') as Object);
  }

  @override
  Future<void> pause() async {
    final player = _player;
    if (player == null) throw StateError('Spotify player is not ready.');
    await js_util.promiseToFuture<void>(player.callMethod('pause') as Object);
  }

  @override
  Future<bool> isPlaying() async {
    final player = _player;
    if (player == null) return false;
    final state = await js_util.promiseToFuture<Object?>(
        player.callMethod('getCurrentState') as Object);
    return state != null && (state as JsObject)['paused'] != true;
  }

  @override
  Future<Duration> position() async {
    final player = _player;
    if (player == null) return Duration.zero;
    final state = await js_util.promiseToFuture<Object?>(
        player.callMethod('getCurrentState') as Object);
    if (state == null) return Duration.zero;
    return Duration(
        milliseconds: ((state as JsObject)['position'] as num?)?.round() ?? 0);
  }

  @override
  Future<void> setVolume(double volume) async {
    final player = _player;
    if (player == null) throw StateError('Spotify player is not ready.');
    await js_util.promiseToFuture<void>(
        player.callMethod('setVolume', [volume.clamp(0, 1)]) as Object);
  }

  @override
  Future<void> dispose() async {
    final player = _player;
    _player = null;
    _deviceId = null;
    if (player != null) {
      await js_util
          .promiseToFuture<bool>(player.callMethod('disconnect') as Object);
    }
  }
}
