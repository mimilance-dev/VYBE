import '../../models/music_models.dart';
import '../../music_provider.dart';
import 'spotify_api_client.dart';

class SpotifyMusicProvider implements MusicProvider {
  SpotifyMusicProvider({
    SpotifyApiClient? api,
    Future<List<Track>> Function(String query)? searchTracks,
    Future<Track?> Function(String id)? trackById,
    Future<List<Track>> Function(
            Track? seedTrack, Artist? seedArtist, Album? seedAlbum, int limit)?
        recommendations,
  })  : _api = api,
        _searchTracks = searchTracks,
        _trackById = trackById,
        _recommendations = recommendations;

  final SpotifyApiClient? _api;
  final Future<List<Track>> Function(String query)? _searchTracks;
  final Future<Track?> Function(String id)? _trackById;
  final Future<List<Track>> Function(Track?, Artist?, Album?, int)?
      _recommendations;

  @override
  MusicProviderId get id => MusicProviderId.spotify;
  @override
  String get displayName => 'Spotify';
  @override
  MusicCapabilities get capabilities => MusicCapabilities(
      supportsSearch: _api != null || _searchTracks != null,
      supportsMetadata:
          _api != null || _searchTracks != null || _trackById != null);

  @override
  Future<List<Track>> search(String query) async {
    if (_api != null) return _api.search(query);
    if (_searchTracks != null) return _searchTracks(query);
    throw StateError('Spotify metadata integration is not configured.');
  }

  @override
  Future<Track?> getTrack(String id) async {
    if (_api != null) return _api.getTrack(id);
    if (_trackById != null) return _trackById(id);
    throw StateError('Spotify metadata integration is not configured.');
  }

  @override
  Future<List<Track>> getRecommendations(
      {Track? seedTrack,
      Artist? seedArtist,
      Album? seedAlbum,
      int limit = 20}) async {
    if (_recommendations == null) {
      throw StateError(
          'Spotify recommendations integration is not configured.');
    }
    return _recommendations(seedTrack, seedArtist, seedAlbum, limit);
  }
}
