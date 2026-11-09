import '../../models/music_models.dart';
import '../../music_playback_controller.dart';
import 'spotify_api_client.dart';
import 'spotify_web_playback_bridge.dart';

class SpotifyWebPlaybackController implements MusicPlaybackController {
  SpotifyWebPlaybackController(this.api, {SpotifyWebPlaybackBridge? bridge})
      : _bridge = bridge ?? createSpotifyWebPlaybackBridge();

  final SpotifyApiClient api;
  final SpotifyWebPlaybackBridge _bridge;
  String? _trackId;

  Future<void> initialize(Future<String?> Function() getAccessToken) =>
      _bridge.initialize(getAccessToken);

  Future<void> activateElement() => _bridge.activateElement();

  @override
  Future<void> play(Track track) async {
    await _bridge.activateElement();
    final deviceId = await _bridge.deviceId;
    if (_trackId != track.id) {
      await api.play(track: track, deviceId: deviceId);
      _trackId = track.id;
    } else if (!await _bridge.isPlaying()) {
      await api.play(deviceId: deviceId);
    }
  }

  @override
  Future<void> pause() async => api.pause(deviceId: await _bridge.deviceId);

  @override
  Future<void> resume() async => api.play(deviceId: await _bridge.deviceId);

  @override
  Future<void> seek(Duration position) async =>
      api.seek(position, deviceId: await _bridge.deviceId);

  @override
  Future<void> next() async => api.next(deviceId: await _bridge.deviceId);

  @override
  Future<void> previous() async =>
      api.previous(deviceId: await _bridge.deviceId);

  @override
  Future<Duration> getPosition() => _bridge.position();

  @override
  Future<bool> getIsPlaying() => _bridge.isPlaying();

  Future<void> setVolume(double volume) => _bridge.setVolume(volume);

  Future<void> dispose() async {
    _trackId = null;
    await _bridge.dispose();
  }
}
