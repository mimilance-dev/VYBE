import 'models/music_models.dart';
import 'music_playback_controller.dart';

class PlaybackRegistry {
  PlaybackRegistry(Map<MusicProviderId, MusicPlaybackController> controllers)
      : _controllers = Map.unmodifiable(controllers);

  final Map<MusicProviderId, MusicPlaybackController> _controllers;

  MusicPlaybackController controllerFor(MusicProviderId provider) =>
      _controllers[provider] ??
      UnsupportedMusicPlaybackController(provider.name);

  bool supports(MusicProviderId provider) => _controllers.containsKey(provider);
}
