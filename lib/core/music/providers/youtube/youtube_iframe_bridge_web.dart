// ignore: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html';
// ignore: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:js';
import 'dart:async';
import 'dart:ui_web' as ui_web;
import 'youtube_iframe_bridge_stub.dart';

export 'youtube_iframe_bridge_stub.dart' show YouTubeIframeBridge;

YouTubeIframeBridge createYouTubeIframeBridge() => WebYouTubeIframeBridge();

class WebYouTubeIframeBridge implements YouTubeIframeBridge {
  JsObject? _player;

  @override
  Future<void> initialize(int viewId) async {
    final view = ui_web.platformViewRegistry.getViewById(viewId);
    if (view is! Element) {
      throw StateError('The YouTube player view is unavailable.');
    }
    await initializeElement(view);
  }

  Future<void> initializeElement(Element view) async {
    for (var i = 0; i < 200 && view.isConnected != true; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    if (view.isConnected != true) {
      throw StateError('The YouTube player view was not attached.');
    }
    if (context['YT'] == null || context['YT']['Player'] == null) {
      if (document.querySelector(
              'script[src="https://www.youtube.com/iframe_api"]') ==
          null) {
        final script = ScriptElement()
          ..src = 'https://www.youtube.com/iframe_api'
          ..async = true;
        document.head!.append(script);
      }
      for (var i = 0;
          i < 200 && (context['YT'] == null || context['YT']['Player'] == null);
          i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    }
    if (context['YT'] == null || context['YT']['Player'] == null) {
      throw StateError('YouTube IFrame Player API did not load.');
    }
    final ready = Completer<void>();
    final playerElement = DivElement();
    view.append(playerElement);
    try {
      _player = JsObject(context['YT']['Player'] as JsFunction, [
        playerElement,
        JsObject.jsify({
          'height': '390',
          'width': '390',
          'playerVars': {
            'autoplay': 0,
            'controls': 1,
            'playsinline': 1,
            'rel': 0,
            'origin': Uri.base.origin,
          },
          'events': {
            'onReady': allowInterop((JsObject _) {
              if (!ready.isCompleted) ready.complete();
            })
          }
        }),
      ]);
      await ready.future.timeout(const Duration(seconds: 15));
    } on TimeoutException {
      await dispose();
      throw StateError(
          'YouTube player did not respond. Check browser network and privacy settings, then try again.');
    } catch (_) {
      playerElement.remove();
      rethrow;
    }
  }

  JsObject get _readyPlayer =>
      _player ?? (throw StateError('YouTube player is not initialized.'));

  @override
  Future<void> loadVideo(String videoId, Duration position) async =>
      _readyPlayer.callMethod(
          'loadVideoById', [videoId, position.inMilliseconds / 1000]);
  @override
  Future<void> play() async => _readyPlayer.callMethod('playVideo');
  @override
  Future<void> pause() async => _readyPlayer.callMethod('pauseVideo');
  @override
  Future<void> seek(Duration position) async =>
      _readyPlayer.callMethod('seekTo', [position.inMilliseconds / 1000, true]);
  @override
  Future<void> setVolume(int volume) async =>
      _readyPlayer.callMethod('setVolume', [volume.clamp(0, 100)]);
  @override
  Future<void> next() async => _readyPlayer.callMethod('nextVideo');
  @override
  Future<void> previous() async => _readyPlayer.callMethod('previousVideo');
  @override
  Future<Duration> position() async => Duration(
      milliseconds:
          (((_readyPlayer.callMethod('getCurrentTime') as num) * 1000))
              .round());
  @override
  Future<bool> playing() async =>
      _readyPlayer.callMethod('getPlayerState') == 1;
  @override
  Future<void> dispose() async {
    _player?.callMethod('destroy');
    _player = null;
  }
}
