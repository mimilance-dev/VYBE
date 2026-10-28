import '../../models/music_models.dart';
import '../../music_playback_controller.dart';
import 'youtube_iframe_bridge.dart';

/// Official YouTube IFrame Player API controller.
///
/// Its controls represent synchronization intent; actual browser playback can
/// diverge because embeds obey ads, DRM, autoplay, availability, and user
/// controls. The room must therefore publish approximate synchronized state,
/// not claim perfectly synchronized audio.
class YouTubePlaybackController implements MusicPlaybackController {
  YouTubePlaybackController({YouTubeIframeBridge? bridge})
      : _bridge = bridge ?? createYouTubeIframeBridge();

  final YouTubeIframeBridge _bridge;
  final List<String> _queue = [];
  int _queueIndex = 0;

  Future<void> initialize(String elementId) => _bridge.initialize(elementId);
  Future<void> setQueue(List<Track> tracks) async {
    _queue
      ..clear()
      ..addAll(tracks.map((track) => track.id));
    _queueIndex = 0;
  }

  @override
  Future<void> play(Track track) async {
    await _bridge.loadVideo(track.id, Duration.zero);
    await _bridge.play();
  }

  @override
  Future<void> pause() => _bridge.pause();
  @override
  Future<void> resume() => _bridge.play();
  @override
  Future<void> seek(Duration position) => _bridge.seek(position);

  @override
  Future<void> next() async {
    if (_queue.length > 1) {
      await _bridge.next();
      _queueIndex = (_queueIndex + 1).clamp(0, _queue.length - 1);
    }
  }

  @override
  Future<void> previous() async {
    if (_queue.length > 1) {
      await _bridge.previous();
      _queueIndex = (_queueIndex - 1).clamp(0, _queue.length - 1);
    }
  }

  @override
  Future<Duration> getPosition() => _bridge.position();
  @override
  Future<bool> getIsPlaying() => _bridge.playing();
  Future<void> setVolume(int volume) => _bridge.setVolume(volume);
  List<String> synchronizedQueue() => List.unmodifiable(_queue);
}
