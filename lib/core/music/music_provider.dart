import 'models/music_models.dart';

/// Provider capability is intentionally separate from playback capability.
/// A provider may return authoritative metadata while its playback controller
/// is unavailable in a particular platform (especially Flutter Web).
class MusicCapabilities {
  const MusicCapabilities({
    required this.supportsSearch,
    required this.supportsMetadata,
    this.supportsPlayback = false,
    this.supportsSeek = false,
    this.supportsQueue = false,
    this.supportsVolume = false,
    this.supportsBackgroundPlayback = false,
  });

  final bool supportsSearch;
  final bool supportsMetadata;
  final bool supportsPlayback;
  final bool supportsSeek;
  final bool supportsQueue;
  final bool supportsVolume;
  final bool supportsBackgroundPlayback;

  @Deprecated('Use supportsSearch and supportsPlayback instead')
  bool get search => supportsSearch;
  @Deprecated('Use supportsPlayback instead')
  bool get playback => supportsPlayback;
}

abstract class MusicProvider {
  MusicProviderId get id;
  String get displayName;
  MusicCapabilities get capabilities;
  Future<List<Track>> search(String query);
  Future<Track?> getTrack(String id);
  Future<List<Track>> getRecommendations(
      {Track? seedTrack, Artist? seedArtist, Album? seedAlbum, int limit = 20});
}
