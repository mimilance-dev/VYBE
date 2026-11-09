// ignore: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html';
// ignore: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:js';
import 'package:flutter_test/flutter_test.dart';
import 'package:vybe/core/music/providers/youtube/youtube_iframe_bridge_web.dart';

void main() {
  test('YouTube initializes inside an attached shadow DOM view', () async {
    context.callMethod('eval', [
      r'''
      window.YT = {
        Player: function(element, options) {
          if (!(element instanceof HTMLElement) || !element.isConnected) {
            throw new Error('Expected attached player element');
          }
          window.vybeTestPlayer = this;
          this.loadVideoById = function(id, position) {
            window.vybeTestVideo = id;
          };
          this.getPlayerState = function() { return 1; };
          this.destroy = function() {};
          setTimeout(function() { options.events.onReady({}); }, 0);
        }
      };
    '''
    ]);
    final host = DivElement();
    final shadow = host.attachShadow({'mode': 'open'});
    final view = DivElement();
    shadow.append(view);
    final bridge = WebYouTubeIframeBridge();
    final ready = bridge.initializeElement(view);
    document.body!.append(host);
    addTearDown(() {
      host.remove();
      context.deleteProperty('YT');
      context.deleteProperty('vybeTestPlayer');
      context.deleteProperty('vybeTestVideo');
    });

    await ready.timeout(const Duration(seconds: 5));
    await bridge.loadVideo('video-id', Duration.zero);
    expect(context['vybeTestVideo'], 'video-id');
    await bridge.dispose();
  });

  test('live YouTube IFrame API initializes in a shadow DOM view', () async {
    final host = DivElement();
    final shadow = host.attachShadow({'mode': 'open'});
    final view = DivElement()
      ..style.width = '390px'
      ..style.height = '390px';
    shadow.append(view);
    document.body!.append(host);
    final bridge = WebYouTubeIframeBridge();
    addTearDown(() async {
      await bridge.dispose();
      host.remove();
    });
    await bridge.initializeElement(view);
  },
      skip: !const bool.fromEnvironment('YOUTUBE_LIVE_TEST'),
      timeout: const Timeout(Duration(seconds: 30)));
}
