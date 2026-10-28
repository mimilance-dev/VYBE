import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../models/music_models.dart';
import 'spotify_auth_service.dart';

class SpotifyApiException implements Exception {
  const SpotifyApiException(this.statusCode, this.message);
  final int statusCode;
  final String message;

  bool get premiumRequired =>
      statusCode == 403 && message.toLowerCase().contains('premium');
  bool get noActiveDevice => statusCode == 404;

  @override
  String toString() => 'Spotify API $statusCode: $message';
}

class SpotifyPlaybackStatus {
  const SpotifyPlaybackStatus(
      {required this.trackId,
      required this.isPlaying,
      required this.positionMs,
      this.deviceId});
  final String? trackId;
  final bool isPlaying;
  final int positionMs;
  final String? deviceId;
}

class SpotifyApiClient {
  SpotifyApiClient(this.auth, {http.Client? httpClient})
      : _http = httpClient ?? http.Client();
  static const apiBase = 'https://api.spotify.com/v1';
  final SpotifyAuthService auth;
  final http.Client _http;

  Future<Map<String, dynamic>> _authorizedJson(String method, String path,
      {Map<String, String>? body, Map<String, String>? query}) async {
    final token = await auth.validAccessToken();
    if (token == null) {
      throw const SpotifyApiException(401, 'Spotify authentication required.');
    }
    final uri = Uri.parse('$apiBase$path').replace(queryParameters: query);
    late http.Response response;
    if (method == 'POST') {
      response = await _http.post(uri, headers: _headers(token), body: body);
    } else if (method == 'PUT') {
      response = await _http.put(uri, headers: _headers(token), body: body);
    } else if (method == 'DELETE') {
      response = await _http.delete(uri, headers: _headers(token));
    } else {
      response = await _http.get(uri, headers: _headers(token));
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      String message = response.reasonPhrase ?? 'Request failed';
      try {
        message =
            jsonDecode(response.body)['error']['message'] as String? ?? message;
      } catch (_) {}
      throw SpotifyApiException(response.statusCode, message);
    }
    if (response.body.isEmpty) return const {};
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Map<String, String> _headers(String token) => {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };

  Future<List<Track>> search(String query) async {
    final data = await _authorizedJson('GET', '/search',
        query: {'type': 'track', 'limit': '20', 'q': query});
    final items = ((data['tracks'] as Map)['items'] as List).cast<Map>();
    return items.map((item) => _track(item.cast<String, dynamic>())).toList();
  }

  Future<Track?> getTrack(String id) async {
    final data = await _authorizedJson('GET', '/tracks/$id');
    return _track(data);
  }

  Track _track(Map<String, dynamic> data) {
    final album = data['album'] as Map<String, dynamic>?;
    final artists = data['artists'] as List? ?? const [];
    final images = album?['images'] as List? ?? const [];
    return Track(
        id: data['id'] as String,
        provider: MusicProviderId.spotify,
        title: data['name'] as String,
        artist: artists.isEmpty ? '' : (artists.first as Map)['name'] as String,
        album: album == null
            ? null
            : Album(
                id: album['id'] as String,
                title: album['name'] as String,
                externalUrl: album['external_urls']?['spotify'] as String?,
                albumArtUrl: images.isEmpty
                    ? null
                    : (images.first as Map)['url'] as String?),
        albumArtUrl:
            images.isEmpty ? null : (images.first as Map)['url'] as String?,
        durationMs: (data['duration_ms'] as num).toInt(),
        externalUrl: (data['external_urls'] as Map)['spotify'] as String,
        previewUrl: data['preview_url'] as String?);
  }

  Future<SpotifyPlaybackStatus?> currentPlayback() async {
    final data = await _authorizedJson('GET', '/me/player');
    if (data.isEmpty) return null;
    final item = data['item'] as Map<String, dynamic>?;
    return SpotifyPlaybackStatus(
        trackId: item?['id'] as String?,
        isPlaying: data['is_playing'] == true,
        positionMs: (data['progress_ms'] as num?)?.toInt() ?? 0,
        deviceId: (data['device'] as Map<String, dynamic>?)?['id'] as String?);
  }

  Future<void> play(
      {Track? track, Duration? position, String? deviceId}) async {
    final query = deviceId == null ? null : {'device_id': deviceId};
    final body = track == null
        ? null
        : jsonEncode({
            'uris': ['spotify:track:${track.id}'],
            if (position != null) 'position_ms': position.inMilliseconds
          });
    await _authorizedBody('PUT', '/me/player/play',
        query: query, jsonBody: body);
  }

  Future<void> pause({String? deviceId}) async =>
      _authorizedBody('PUT', '/me/player/pause',
          query: deviceId == null ? null : {'device_id': deviceId});
  Future<void> seek(Duration position, {String? deviceId}) async =>
      _authorizedBody('PUT', '/me/player/seek', query: {
        'position_ms': '${position.inMilliseconds}',
        if (deviceId != null) 'device_id': deviceId
      });
  Future<void> next({String? deviceId}) async =>
      _authorizedBody('POST', '/me/player/next',
          query: deviceId == null ? null : {'device_id': deviceId});
  Future<void> previous({String? deviceId}) async =>
      _authorizedBody('POST', '/me/player/previous',
          query: deviceId == null ? null : {'device_id': deviceId});
  Future<void> addToQueue(Track track, {String? deviceId}) async =>
      _authorizedBody('POST', '/me/player/queue', query: {
        'uri': 'spotify:track:${track.id}',
        if (deviceId != null) 'device_id': deviceId
      });

  Future<void> _authorizedBody(String method, String path,
      {Map<String, String>? query, String? jsonBody}) async {
    final token = await auth.validAccessToken();
    if (token == null) {
      throw const SpotifyApiException(401, 'Spotify authentication required.');
    }
    final uri = Uri.parse('$apiBase$path').replace(queryParameters: query);
    final response = method == 'PUT'
        ? await _http.put(uri, headers: _headers(token), body: jsonBody)
        : await _http.post(uri, headers: _headers(token), body: jsonBody);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      String message =
          response.reasonPhrase ?? 'Spotify playback request failed';
      try {
        final error = jsonDecode(response.body)['error'];
        if (error is Map && error['message'] is String) {
          message = error['message'] as String;
        }
      } catch (_) {}
      throw SpotifyApiException(response.statusCode, message);
    }
  }
}
