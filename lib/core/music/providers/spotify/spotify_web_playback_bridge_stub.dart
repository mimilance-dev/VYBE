abstract class SpotifyWebPlaybackBridge {
  Future<void> initialize(Future<String?> Function() getAccessToken);
  Future<String> get deviceId;
  Future<void> activateElement();
  Future<void> pause();
  Future<bool> isPlaying();
  Future<Duration> position();
  Future<void> setVolume(double volume);
  Future<void> dispose();
}

SpotifyWebPlaybackBridge createSpotifyWebPlaybackBridge() =>
    _UnsupportedSpotifyWebPlaybackBridge();

class _UnsupportedSpotifyWebPlaybackBridge implements SpotifyWebPlaybackBridge {
  Never _unsupported() => throw UnsupportedError(
      'Spotify Web Playback is available only in a browser.');

  @override
  Future<void> initialize(Future<String?> Function() getAccessToken) =>
      Future.sync(_unsupported);
  @override
  Future<String> get deviceId => Future.error(_unsupported());
  @override
  Future<void> activateElement() => Future.sync(_unsupported);
  @override
  Future<void> pause() => Future.sync(_unsupported);
  @override
  Future<bool> isPlaying() => Future.sync(_unsupported);
  @override
  Future<Duration> position() => Future.sync(_unsupported);
  @override
  Future<void> setVolume(double volume) => Future.sync(_unsupported);
  @override
  Future<void> dispose() async {}
}
