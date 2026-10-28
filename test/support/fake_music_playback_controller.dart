import 'package:vybe/core/music/models/music_models.dart';
import 'package:vybe/core/music/music_playback_controller.dart';

/// Deterministic playback seam for synchronization tests.
/// No Spotify, YouTube, audio device, or network access is used.
class FakeMusicPlaybackController implements MusicPlaybackController {
  FakeMusicPlaybackController(
      {this.positionFactory, Duration Function()? clock})
      : _clock = clock ??
            (() =>
                Duration(milliseconds: DateTime.now().millisecondsSinceEpoch));

  Duration _position = Duration.zero;
  Duration? _lastStartedAt;
  bool _playing = false;
  Track? _track;
  final Duration Function(Duration current)? positionFactory;
  final Duration Function() _clock;

  Duration latency = Duration.zero;
  final List<String> operations = [];
  int seekCount = 0;

  @override
  Future<void> play(Track track) async {
    operations.add('play:${track.id}');
    await Future<void>.delayed(latency);
    _track = track;
    _position = Duration.zero;
    _playing = true;
    _lastStartedAt = _now();
  }

  @override
  Future<void> pause() async {
    operations.add('pause');
    await Future<void>.delayed(latency);
    await _capturePosition();
    _playing = false;
    _lastStartedAt = null;
  }

  @override
  Future<void> resume() async {
    operations.add('resume');
    await Future<void>.delayed(latency);
    _playing = true;
    _lastStartedAt = _now();
  }

  @override
  Future<void> seek(Duration position) async {
    operations.add('seek:${position.inMilliseconds}ms');
    seekCount++;
    await Future<void>.delayed(latency);
    _position = position;
    if (_playing) _lastStartedAt = _now();
  }

  @override
  Future<void> next() async {
    operations.add('next');
  }

  @override
  Future<void> previous() async {
    operations.add('previous');
  }

  @override
  Future<Duration> getPosition() async {
    await Future<void>.delayed(latency);
    return _capturePosition();
  }

  @override
  Future<bool> getIsPlaying() async => _playing;

  Track? get currentTrack => _track;

  Future<Duration> _capturePosition() async {
    final now = _now();
    if (_playing && _lastStartedAt != null) {
      _position += now - _lastStartedAt!;
      _lastStartedAt = now;
    }
    return positionFactory?.call(_position) ?? _position;
  }

  Duration _now() => _clock();
}
