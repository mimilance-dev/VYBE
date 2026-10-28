import '../models/music_models.dart';
import '../music_provider.dart';

/// Spotify metadata/search adapter.
///
/// This adapter does not imply playback support. Playback is deliberately
/// enabled only by an explicitly configured, official Spotify controller.
class SpotifyMusicProvider implements MusicProvider {
  SpotifyMusicProvider({
    Future<List<Track>> Function(String query)? searchTracks,
    Future<Track?> Function(String id)? trackById,
    Future<List<Track>> Function(
            Track? seedTrack, Artist? seedArtist, Album? seedAlbum, int limit)?
        recommendations,
    bool supportsPlayback = false,
    bool supportsSeek = false,
    bool supportsQueue = false,
    bool supportsVolume = false,
  })  : _supportsPlayback = supportsPlayback,
        _supportsSeek = supportsSeek,
        _supportsQueue = supportsQueue,
        _supportsVolume = supportsVolume,
        _searchTracks = searchTracks,
        _trackById = trackById,
        _recommendations = recommendations;

  final Future<List<Track>> Function(String query)? _searchTracks;
  final Future<Track?> Function(String id)? _trackById;
  final Future<List<Track>> Function(Track?, Artist?, Album?, int)?
      _recommendations;
  final bool _supportsPlayback;
  final bool _supportsSeek;
  final bool _supportsQueue;
  final bool _supportsVolume;

  @override
  MusicProviderId get id => MusicProviderId.spotify;
  @override
  String get displayName => 'Spotify';
  // Metadata integration can be enabled without implying Web SDK playback.
  @override
  MusicCapabilities get capabilities => MusicCapabilities(
      supportsSearch: _searchTracks != null,
      supportsMetadata: _searchTracks != null || _trackById != null,
      supportsPlayback: _supportsPlayback,
      supportsSeek: _supportsSeek,
      supportsQueue: _supportsQueue,
      supportsVolume: _supportsVolume);

  @override
  Future<List<Track>> search(String query) =>
      _searchTracks?.call(query) ??
      Future.error(
          StateError('Spotify metadata integration is not configured.'));
  @override
  Future<Track?> getTrack(String id) =>
      _trackById?.call(id) ??
      Future.error(
          StateError('Spotify metadata integration is not configured.'));
  @override
  Future<List<Track>> getRecommendations(
          {Track? seedTrack,
          Artist? seedArtist,
          Album? seedAlbum,
          int limit = 20}) =>
      _recommendations?.call(seedTrack, seedArtist, seedAlbum, limit) ??
      Future.error(
          StateError('Spotify recommendations integration is not configured.'));
}
