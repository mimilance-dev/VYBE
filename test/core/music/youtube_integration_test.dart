import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vybe/core/music/providers/youtube/youtube_search_service.dart';

void main() {
  test('YouTube Data API maps official video search metadata', () async {
    var requestCount = 0;
    final service = YouTubeSearchService('public-api-key',
        httpClient: MockClient((request) async {
      requestCount++;
      if (request.url.path.endsWith('/search')) {
        return http.Response('{"items":[{"id":{"videoId":"video-id"}}]}', 200);
      }
      return http.Response(
          '{"items":[{"id":"video-id","snippet":{"title":"Official video","channelTitle":"Artist","thumbnails":{"high":{"url":"https://example.test/art.jpg"}}},"contentDetails":{"duration":"PT3M30S"}}]}',
          200);
    }));

    final tracks = await service.search('official video');
    expect(requestCount, 2);
    expect(tracks.single.id, 'video-id');
    expect(tracks.single.title, 'Official video');
    expect(tracks.single.albumArtUrl, contains('art.jpg'));
    expect(tracks.single.durationMs, 210000);
    expect(
        tracks.single.externalUrl, 'https://www.youtube.com/watch?v=video-id');
  });

  test('YouTube Data API reports configuration and quota errors', () async {
    final missingKey = YouTubeSearchService('',
        httpClient: MockClient((_) async => http.Response('{}', 200)));
    await expectLater(
        missingKey.search('test'), throwsA(isA<YouTubeSearchException>()));

    final service = YouTubeSearchService('test-key',
        httpClient: MockClient((_) async =>
            http.Response('{"error":{"message":"quota exceeded"}}', 403)));
    await expectLater(
        service.search('test'),
        throwsA(predicate((Object error) =>
            error is YouTubeSearchException &&
            error.statusCode == 403 &&
            error.message.contains('quota'))));
  });
}
