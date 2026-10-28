import '../models/music_models.dart';
import '../music_provider.dart';
import 'youtube/youtube_search_service.dart';

/// YouTube Music metadata/search adapter.
///
/// Metadata/search use official APIs only. No implementation in this class
/// extracts, decrypts, proxies, or bypasses playback restrictions; Flutter
/// playback must use official embeds, IFrame APIs, or applications.
class YouTubeMusicProvider implements MusicProvider {
  YouTubeMusicProvider({
    Future<List<Track>> Function(String query)? searchTracks,
    YouTubeSearchService? searchService,
    Future<Track?> Function(String id)? trackById,
    Future<List<Track>> Function(
            Track? seedTrack, Artist? seedArtist, Album? seedAlbum, int limit)?
        recommendations,
    bool supportsPlayback = false,
    bool supportsSeek = false,
    bool supportsQueue = false,
    bool supportsVolume = false,
  })  : _searchTracks = searchTracks,
        _supportsPlayback = supportsPlayback,
        _supportsSeek = supportsSeek,
        _supportsQueue = supportsQueue,
        _supportsVolume = supportsVolume,
        _searchService = searchService,
        _trackById = trackById,
        _recommendations = recommendations;

  final Future<List<Track>> Function(String query)? _searchTracks;
  final YouTubeSearchService? _searchService;
  final Future<Track?> Function(String id)? _trackById;
  final Future<List<Track>> Function(Track?, Artist?, Album?, int)?
      _recommendations;
  final bool _supportsPlayback;
  final bool _supportsSeek;
  final bool _supportsQueue;
  final bool _supportsVolume;

  @override
  MusicProviderId get id => MusicProviderId.youtube;
  @override
  String get displayName => 'YouTube';
  // Search is metadata only. YouTube playback must use an official embed/API;
  // this architecture never extracts or streams audio itself.
  @override
  MusicCapabilities get capabilities => MusicCapabilities(
      supportsSearch: _searchTracks != null || _searchService != null,
      supportsMetadata: _searchTracks != null ||
          _trackById != null ||
          _searchService != null,
      supportsPlayback: _supportsPlayback,
      supportsSeek: _supportsSeek,
      supportsQueue: _supportsQueue,
      supportsVolume: _supportsVolume);

  @override
  Future<List<Track>> search(String query) =>
      _searchService?.search(query) ??
      _searchTracks?.call(query) ??
      Future.error(
          StateError('YouTube metadata integration is not configured.'));
  @override
  Future<Track?> getTrack(String id) =>
      _searchService?.getTrack(id) ??
      _trackById?.call(id) ??
      Future.error(
          StateError('YouTube metadata integration is not configured.'));
  @override
  Future<List<Track>> getRecommendations(
          {Track? seedTrack,
          Artist? seedArtist,
          Album? seedAlbum,
          int limit = 20}) =>
      _recommendations?.call(seedTrack, seedArtist, seedAlbum, limit) ??
      Future.error(
          StateError('YouTube recommendations integration is not configured.'));
}
