import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/music_models.dart';

class YouTubeSearchException implements Exception {
  const YouTubeSearchException(this.statusCode, this.message);
  final int statusCode;
  final String message;
  @override
  String toString() => 'YouTube Data API $statusCode: $message';
}

/// Public metadata/search uses the official YouTube Data API v3 only. OAuth is
/// not required. This implementation must not use undocumented Music endpoints.
class YouTubeSearchService {
  YouTubeSearchService(this.apiKey, {http.Client? httpClient})
      : _http = httpClient ?? http.Client();
  static const _apiBase = 'https://www.googleapis.com/youtube/v3';
  final String apiKey;
  final http.Client _http;

  Future<List<Track>> search(String query) async {
    if (apiKey.trim().isEmpty) {
      throw const YouTubeSearchException(
          401, 'YouTube API key is not configured.');
    }
    final searchData = await _get('/search', {
      'part': 'snippet',
      'type': 'video',
      'maxResults': '20',
      'safeSearch': 'none',
      'q': query,
    });
    final ids = ((searchData['items'] as List?) ?? const [])
        .map((item) => (item as Map)['id']?['videoId'] as String?)
        .whereType<String>()
        .join(',');
    if (ids.isEmpty) return const [];
    final videosData =
        await _get('/videos', {'part': 'snippet,contentDetails', 'id': ids});
    return ((videosData['items'] as List?) ?? const [])
        .map((item) => _track((item as Map).cast<String, dynamic>()))
        .whereType<Track>()
        .toList();
  }

  Future<Track?> getTrack(String id) async {
    final data =
        await _get('/videos', {'part': 'snippet,contentDetails', 'id': id});
    final items = data['items'] as List? ?? const [];
    if (items.isEmpty) return null;
    return _track((items.first as Map).cast<String, dynamic>());
  }

  Future<Map<String, dynamic>> _get(
      String path, Map<String, String> query) async {
    final uri = Uri.parse('$_apiBase$path')
        .replace(queryParameters: {...query, 'key': apiKey});
    final response = await _http.get(uri);
    Map<String, dynamic> data;
    try {
      data = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw YouTubeSearchException(
          response.statusCode, 'Invalid YouTube API response.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = data['error'] as Map?;
      final message = (error?['message'] as String?) ??
          response.reasonPhrase ??
          'Request failed';
      throw YouTubeSearchException(response.statusCode, message);
    }
    return data;
  }

  Track? _track(Map<String, dynamic> data) {
    final id = data['id'] as String?;
    if (id == null) return null;
    final snippet = data['snippet'] as Map?;
    final thumbnails = snippet?['thumbnails'] as Map?;
    final thumbnail =
        thumbnails?['maxres'] ?? thumbnails?['high'] ?? thumbnails?['default'];
    final details = data['contentDetails'] as Map?;
    return Track(
        id: id,
        provider: MusicProviderId.youtube,
        title: (snippet?['title'] as String?) ?? 'YouTube video',
        artist: (snippet?['channelTitle'] as String?) ?? '',
        albumArtUrl: thumbnail is Map ? thumbnail['url'] as String? : null,
        durationMs: _duration(details?['duration'] as String? ?? 'PT0S'),
        externalUrl: 'https://www.youtube.com/watch?v=$id');
  }

  static int _duration(String value) {
    final m =
        RegExp(r'P(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+(?:\.\d+)?)S)?)?')
            .firstMatch(value);
    if (m == null) return 0;
    final seconds = (int.tryParse(m.group(1) ?? '') ?? 0) * 86400 +
        (int.tryParse(m.group(2) ?? '') ?? 0) * 3600 +
        (int.tryParse(m.group(3) ?? '') ?? 0) * 60 +
        (double.tryParse(m.group(4) ?? '') ?? 0);
    return (seconds * 1000).round();
  }
}
