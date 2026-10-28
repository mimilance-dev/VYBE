abstract class YouTubeIframeBridge {
  Future<void> initialize(String elementId);
  Future<void> loadVideo(String videoId, Duration position);
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> setVolume(int volume);
  Future<void> next();
  Future<void> previous();
  Future<Duration> position();
  Future<bool> playing();
}

YouTubeIframeBridge createYouTubeIframeBridge() => _UnsupportedBridge();

class _UnsupportedBridge implements YouTubeIframeBridge {
  Never unsupported() => throw UnsupportedError(
      'The YouTube IFrame Player API is available only on Flutter Web.');
  @override
  Future<void> initialize(String elementId) => Future.sync(unsupported);
  @override
  Future<void> loadVideo(String videoId, Duration position) =>
      Future.sync(unsupported);
  @override
  Future<void> play() => Future.sync(unsupported);
  @override
  Future<void> pause() => Future.sync(unsupported);
  @override
  Future<void> seek(Duration position) => Future.sync(unsupported);
  @override
  Future<void> setVolume(int volume) => Future.sync(unsupported);
  @override
  Future<void> next() => Future.sync(unsupported);
  @override
  Future<void> previous() => Future.sync(unsupported);
  @override
  Future<Duration> position() async => Duration.zero;
  @override
  Future<bool> playing() async => false;
}
