import 'models/music_models.dart';

abstract class MusicPlaybackController {
  Future<void> play(Track track);
  Future<void> pause();
  Future<void> resume();
  Future<void> seek(Duration position);
  Future<void> next();
  Future<void> previous();
  Future<Duration> getPosition();
  Future<bool> getIsPlaying();
}

class PlaybackUnsupportedException implements Exception {
  const PlaybackUnsupportedException(this.providerName, this.externalUrl,
      {this.reason = 'Playback is not supported in this app/platform.'});
  final String providerName;
  final String externalUrl;
  final String reason;

  String get message => '$providerName playback unavailable. $reason';
  @override
  String toString() => message;
}

/// No provider implementation should use this controller to bypass an
/// official SDK, preview restriction, embed policy, or audio extraction rule.
class UnsupportedMusicPlaybackController implements MusicPlaybackController {
  UnsupportedMusicPlaybackController(this.providerName);
  final String providerName;

  Never _unsupported(String externalUrl) =>
      throw PlaybackUnsupportedException(providerName, externalUrl,
          reason: 'Use the official provider to play this track here.');

  @override
  Future<void> play(Track track) =>
      Future.sync(() => _unsupported(track.externalUrl));
  @override
  Future<void> pause() => Future.sync(() => _unsupported(''));
  @override
  Future<void> resume() => Future.sync(() => _unsupported(''));
  @override
  Future<void> seek(Duration position) => Future.sync(() => _unsupported(''));
  @override
  Future<void> next() => Future.sync(() => _unsupported(''));
  @override
  Future<void> previous() => Future.sync(() => _unsupported(''));
  @override
  Future<Duration> getPosition() async => Duration.zero;
  @override
  Future<bool> getIsPlaying() async => false;
}
