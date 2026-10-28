import 'package:flutter_test/flutter_test.dart';
import 'package:vybe/core/music/models/music_models.dart';
import 'package:vybe/core/music/music_playback_controller.dart';
import 'package:vybe/core/music/music_provider.dart';
import 'package:vybe/core/music/provider_registry.dart';
import 'package:vybe/core/music/providers/spotify_music_provider.dart';
import 'package:vybe/core/music/providers/youtube_music_provider.dart';
import 'package:vybe/core/music/providers/youtube/youtube_search_service.dart';

Track track(MusicProviderId provider, String id) => Track(
    id: id,
    provider: provider,
    title: 'A song',
    artist: 'An artist',
    durationMs: 180000,
    externalUrl: 'https://open.spotify.com/track/$id');

class FakeProvider implements MusicProvider {
  FakeProvider(this.id, this.searchEnabled);
  @override
  final MusicProviderId id;
  final bool searchEnabled;
  @override
  String get displayName => id.name;
  @override
  MusicCapabilities get capabilities => MusicCapabilities(
      supportsSearch: searchEnabled, supportsMetadata: searchEnabled);
  @override
  Future<Track?> getTrack(String id) async => track(this.id, id);
  @override
  Future<List<Track>> getRecommendations(
          {Track? seedTrack,
          Artist? seedArtist,
          Album? seedAlbum,
          int limit = 20}) async =>
      [];
  @override
  Future<List<Track>> search(String query) async => [track(id, query)];
}

void main() {
  test('registry routes tracks to their provider', () {
    final spotify = FakeProvider(MusicProviderId.spotify, true);
    final youtube = FakeProvider(MusicProviderId.youtube, true);
    final registry = ProviderRegistry([spotify, youtube]);
    expect(registry.providerForTrack(track(MusicProviderId.youtube, 'yt-1')),
        same(youtube));
  });

  test('concrete providers separate metadata and playback capabilities', () {
    final spotify = SpotifyMusicProvider(searchTracks: (_) async => []);
    final youtube = YouTubeMusicProvider(searchTracks: (_) async => []);
    expect(spotify.capabilities.supportsSearch, isTrue);
    expect(spotify.capabilities.supportsPlayback, isFalse);
    expect(youtube.capabilities.supportsSearch, isTrue);
    expect(youtube.capabilities.supportsPlayback, isFalse);
  });

  test('unsupported playback identifies provider and official action',
      () async {
    final controller = UnsupportedMusicPlaybackController('Spotify');
    try {
      await controller.play(track(MusicProviderId.spotify, 'abc'));
      fail('Playback should be unsupported');
    } on PlaybackUnsupportedException catch (error) {
      expect(error.providerName, 'Spotify');
      expect(error.externalUrl, contains('open.spotify.com'));
    }
  });

  test('registry reports when a provider is not installed', () {
    final registry =
        ProviderRegistry([FakeProvider(MusicProviderId.spotify, true)]);
    expect(registry[MusicProviderId.youtube], isNull);
    expect(
        () => registry.providerFor(MusicProviderId.youtube), throwsStateError);
  });

  test('YouTube metadata remains distinct from embed playback capability', () {
    final provider =
        YouTubeMusicProvider(searchService: YouTubeSearchService('test-key'));
    expect(provider.capabilities.supportsSearch, isTrue);
    expect(provider.capabilities.supportsMetadata, isTrue);
    expect(provider.capabilities.supportsPlayback, isFalse);
    expect(provider.capabilities.supportsSeek, isFalse);
  });

  test('unsupported playback rejects every control operation', () async {
    final controller = UnsupportedMusicPlaybackController('YouTube');
    await expectLater(
      controller.pause(),
      throwsA(isA<PlaybackUnsupportedException>()),
    );
    expect(await controller.getPosition(), Duration.zero);
    expect(await controller.getIsPlaying(), isFalse);
  });
}
