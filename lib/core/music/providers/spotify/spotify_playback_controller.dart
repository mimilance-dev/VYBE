import '../../models/music_models.dart';
import '../../music_playback_controller.dart';
import 'spotify_api_client.dart';

/// Spotify playback is capability and account gated: SDK/Web APIs require a
/// Premium account and an available Spotify device. This controller performs
/// only documented official Web API calls; it never extracts audio.
class SpotifyPlaybackController implements MusicPlaybackController {
  SpotifyPlaybackController(this.api);
  final SpotifyApiClient api;

  static const premiumMessage = 'Spotify playback requires Spotify Premium and '
      'an available compatible Spotify device. Open the track in Spotify to listen.';

  @override
  Future<void> play(Track track) async => api.play(track: track);
  @override
  Future<void> pause() async => api.pause();
  @override
  Future<void> resume() async => api.play();
  @override
  Future<void> seek(Duration position) async => api.seek(position);
  @override
  Future<void> next() async => api.next();
  @override
  Future<void> previous() async => api.previous();
  @override
  Future<Duration> getPosition() async =>
      Duration(milliseconds: (await api.currentPlayback())?.positionMs ?? 0);
  @override
  Future<bool> getIsPlaying() async =>
      (await api.currentPlayback())?.isPlaying ?? false;

  Future<void> addToQueue(Track track) => api.addToQueue(track);
}
