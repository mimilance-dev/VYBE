// ignore: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html';
// ignore: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:js';
import 'dart:async';
import 'youtube_iframe_bridge_stub.dart';

YouTubeIframeBridge createYouTubeIframeBridge() => WebYouTubeIframeBridge();

class WebYouTubeIframeBridge implements YouTubeIframeBridge {
  JsObject? _player;

  @override
  Future<void> initialize(String elementId) async {
    if (context['YT'] == null || context['YT']['Player'] == null) {
      final script = ScriptElement()
        ..src = 'https://www.youtube.com/iframe_api'
        ..async = true;
      document.head?.append(script);
      for (var i = 0; i < 100 && context['YT'] == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    }
    if (context['YT'] == null || context['YT']['Player'] == null) {
      throw StateError('YouTube IFrame Player API did not load.');
    }
    final ready = Completer<void>();
    _player = JsObject(context['YT']['Player'] as JsFunction, [
      elementId,
      JsObject.jsify({
        'height': '360',
        'width': '640',
        'events': {'onReady': (JsObject _) => ready.complete()}
      }),
    ]);
    return ready.future.timeout(const Duration(seconds: 15));
  }

  @override
  Future<void> loadVideo(String videoId, Duration position) async => _player
      ?.callMethod('loadVideoById', [videoId, position.inMilliseconds / 1000]);
  @override
  Future<void> play() async => _player?.callMethod('playVideo');
  @override
  Future<void> pause() async => _player?.callMethod('pauseVideo');
  @override
  Future<void> seek(Duration position) async =>
      _player?.callMethod('seekTo', [position.inMilliseconds / 1000, true]);
  @override
  Future<void> setVolume(int volume) async =>
      _player?.callMethod('setVolume', [volume.clamp(0, 100)]);
  @override
  Future<void> next() async => _player?.callMethod('nextVideo');
  @override
  Future<void> previous() async => _player?.callMethod('previousVideo');
  @override
  Future<Duration> position() async => Duration(
      milliseconds:
          (((_player?.callMethod('getCurrentTime') as num?) ?? 0) * 1000)
              .round());
  @override
  Future<bool> playing() async => _player?.callMethod('getPlayerState') == 1;
}
