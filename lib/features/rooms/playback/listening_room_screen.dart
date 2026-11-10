import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/music/providers/spotify/spotify_web_playback_controller.dart';
import '../../../core/music/providers/youtube/youtube_playback_controller.dart';
import '../../../core/music/models/music_models.dart';
import '../../../core/music/widgets/provider_badge.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_tokens.dart';
import '../../spotify/spotify_connection.dart';
import '../models/room_models.dart';
import '../providers/room_providers.dart';
import 'playback_command.dart';
import 'sync_engine.dart';
import 'youtube_player_surface.dart';

class ListeningRoomScreen extends ConsumerStatefulWidget {
  const ListeningRoomScreen(
      {super.key,
      required this.room,
      required this.participants,
      required this.userId,
      required this.onLeave});
  final ListeningRoom room;
  final List<RoomParticipant> participants;
  final String userId;
  final VoidCallback onLeave;

  @override
  ConsumerState<ListeningRoomScreen> createState() =>
      _ListeningRoomScreenState();
}

class _ListeningRoomScreenState extends ConsumerState<ListeningRoomScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  final _focusNode = FocusNode();
  bool _shuffle = false;
  bool _repeat = false;
  double _volume = 0.72;
  String? _activity;
  Timer? _progressTimer;
  late final String _youtubeViewType;
  late final YouTubePlaybackController _youtubePlayback;
  SpotifyWebPlaybackController? _spotifyPlayback;
  bool _youtubeReady = false;
  Future<void>? _youtubeInitialization;
  int? _youtubeViewId;
  bool _spotifyReady = false;
  Future<void>? _spotifyInitialization;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: AppMotion.pulse);
    _youtubeViewType =
        'vybe-youtube-${widget.room.id.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_')}';
    _youtubePlayback = YouTubePlaybackController();
    _updateProgressTimer();
    if (kIsWeb &&
        _providerFor(widget.room.currentTrack) == MusicProviderId.spotify) {
      unawaited(_runPlayback(_initializeSpotifyPlayback));
    }
  }

  @override
  void didUpdateWidget(covariant ListeningRoomScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.room.playbackState.isPlaying !=
        widget.room.playbackState.isPlaying) {
      _updateProgressTimer();
    }
    if (oldWidget.room.currentTrack?['id'] != widget.room.currentTrack?['id'] ||
        oldWidget.room.playbackState.revision !=
            widget.room.playbackState.revision) {
      unawaited(_syncRoomPlayback(oldWidget.room));
    }
    if (kIsWeb &&
        _providerFor(oldWidget.room.currentTrack) != MusicProviderId.spotify &&
        _providerFor(widget.room.currentTrack) == MusicProviderId.spotify) {
      unawaited(_runPlayback(_initializeSpotifyPlayback));
    }
  }

  void _initializeYouTube(int viewId) {
    _youtubeViewId = viewId;
    unawaited(_runPlayback(() async {
      await _ensureYouTubeReady();
      if (mounted &&
          _providerFor(widget.room.currentTrack) == MusicProviderId.youtube) {
        await _syncRoomPlayback(widget.room);
      }
    }));
  }

  Future<void> _ensureYouTubeReady() async {
    if (_youtubeReady) return;
    final pending = _youtubeInitialization;
    if (pending != null) return pending;
    final viewId = _youtubeViewId;
    if (viewId == null) {
      throw StateError('The YouTube player view is not available yet.');
    }
    final initialization = _youtubePlayback.initialize(viewId);
    _youtubeInitialization = initialization;
    try {
      await initialization;
      _youtubeReady = true;
    } finally {
      _youtubeInitialization = null;
    }
  }

  Future<void> _initializeSpotifyPlayback() {
    if (_spotifyReady) return Future<void>.value();
    return _spotifyInitialization ??= _initializeSpotifyPlaybackOnce()
        .whenComplete(() => _spotifyInitialization = null);
  }

  Future<void> _initializeSpotifyPlaybackOnce() async {
    final auth = ref.read(spotifyAuthServiceProvider);
    final tokens = await auth.loadTokens();
    if (!mounted) return;
    if (tokens == null) {
      throw StateError('Connect Spotify from the home screen first.');
    }
    if (!tokens.hasPlaybackScopes) {
      throw StateError('Spotify playback needs additional permissions. '
          'Return to the home screen, disconnect Spotify, and connect it again.');
    }
    final controller =
        SpotifyWebPlaybackController(ref.read(spotifyApiClientProvider));
    try {
      await controller.initialize(auth.validAccessToken);
    } catch (_) {
      await controller.dispose();
      rethrow;
    }
    if (!mounted) {
      await controller.dispose();
      return;
    }
    _spotifyPlayback = controller;
    _spotifyReady = true;
    await _syncRoomPlayback(widget.room);
  }

  Future<void> _syncRoomPlayback(ListeningRoom previousRoom) async {
    final oldTrack = previousRoom.currentTrack;
    final track = widget.room.currentTrack;
    final oldProvider = _providerFor(oldTrack);
    final provider = _providerFor(track);
    final trackChanged =
        oldProvider != provider || oldTrack?['id'] != track?['id'];
    final stopped = previousRoom.playbackState.isPlaying &&
        !widget.room.playbackState.isPlaying;
    try {
      if (trackChanged || stopped) {
        await _pauseProvider(oldProvider);
      }
      if (oldProvider == MusicProviderId.youtube &&
          provider != MusicProviderId.youtube) {
        final pending = _youtubeInitialization;
        if (pending != null) {
          try {
            await pending;
          } catch (error) {
            _showPlaybackError('YouTube player failed to start: $error');
          }
        }
        await _youtubePlayback.dispose();
        _youtubeReady = false;
        _youtubeViewId = null;
      }
      if (track == null) return;
      final oldPosition = const SyncEngine()
          .projectedPosition(previousRoom.playbackState, DateTime.now());
      final newPosition = const SyncEngine()
          .projectedPosition(widget.room.playbackState, DateTime.now());
      final seekChanged =
          !trackChanged && (newPosition - oldPosition).abs() > 1000;
      if (seekChanged) {
        await _seekProvider(provider, Duration(milliseconds: newPosition));
      } else if (widget.room.playbackState.isPlaying) {
        await _playProvider(_trackFromRoom(track));
      }
    } catch (error) {
      _showPlaybackError('$provider playback failed: $error');
    }
  }

  MusicProviderId? _providerFor(Map<String, dynamic>? track) =>
      switch (track?['provider']) {
        'spotify' => MusicProviderId.spotify,
        'youtube' => MusicProviderId.youtube,
        _ => null,
      };

  Track _trackFromRoom(Map<String, dynamic> data) {
    final provider = _providerFor(data);
    if (provider == null) {
      throw StateError('The selected track has no provider.');
    }
    final id = data['id'] as String?;
    if (id == null || id.isEmpty) {
      throw StateError('The selected track has no ID.');
    }
    return Track(
      id: id,
      provider: provider,
      title: data['title'] as String? ?? 'Unknown track',
      artist: data['artist'] as String? ?? '',
      albumArtUrl: data['albumArtUrl'] as String?,
      durationMs: (data['durationMs'] as num?)?.toInt() ?? 0,
      externalUrl: data['externalUrl'] as String? ??
          (provider == MusicProviderId.spotify
              ? 'https://open.spotify.com/track/$id'
              : 'https://www.youtube.com/watch?v=$id'),
    );
  }

  Future<void> _playProvider(Track track) async {
    if (track.provider == MusicProviderId.youtube) {
      await _ensureYouTubeReady();
      await _youtubePlayback.play(track);
    } else {
      if (!_spotifyReady) {
        await _initializeSpotifyPlayback();
      }
      final controller = _spotifyPlayback;
      if (controller == null || !_spotifyReady) {
        throw StateError('Spotify browser playback is not ready.');
      }
      await controller.play(track);
    }
  }

  Future<void> _pauseProvider(MusicProviderId? provider) async {
    if (provider == MusicProviderId.youtube && _youtubeReady) {
      await _youtubePlayback.pause();
    } else if (provider == MusicProviderId.spotify && _spotifyReady) {
      await _spotifyPlayback?.pause();
    }
  }

  Future<void> _runPlayback(Future<void> Function() operation) async {
    try {
      await operation();
    } catch (error) {
      _showPlaybackError('$error');
    }
  }

  void _showPlaybackError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _updateProgressTimer() {
    _progressTimer?.cancel();
    if (widget.room.playbackState.isPlaying) {
      _progressTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    unawaited(_youtubePlayback.dispose());
    final spotifyPlayback = _spotifyPlayback;
    if (spotifyPlayback != null) unawaited(spotifyPlayback.dispose());
    _pulse.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playing = widget.room.playbackState.isPlaying;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (playing && !_pulse.isAnimating && !reduceMotion) {
      _pulse.repeat(reverse: true);
    }
    if (!playing && _pulse.isAnimating) {
      _pulse.stop();
    }
    return Shortcuts(
        shortcuts: <ShortcutActivator, Intent>{
          const SingleActivator(LogicalKeyboardKey.space):
              const _RoomIntent(_RoomAction.playPause),
          const SingleActivator(LogicalKeyboardKey.arrowLeft):
              const _RoomIntent(_RoomAction.backward),
          const SingleActivator(LogicalKeyboardKey.arrowRight):
              const _RoomIntent(_RoomAction.forward),
          const SingleActivator(LogicalKeyboardKey.keyN):
              const _RoomIntent(_RoomAction.next),
          const SingleActivator(LogicalKeyboardKey.keyP):
              const _RoomIntent(_RoomAction.previous),
          const SingleActivator(LogicalKeyboardKey.keyQ):
              const _RoomIntent(_RoomAction.queue),
        },
        child: Actions(
            actions: {
              _RoomIntent: CallbackAction<_RoomIntent>(onInvoke: (intent) {
                _handleIntent(intent.action);
                return null;
              })
            },
            child: Focus(
                focusNode: _focusNode,
                autofocus: true,
                onKeyEvent: _onKey,
                child: Scaffold(
                    backgroundColor: AppColors.background,
                    body: Stack(children: [
                      const DecoratedBox(
                          position: DecorationPosition.background,
                          decoration: BoxDecoration(
                              gradient: AppDecorations.backgroundGradient),
                          child: SizedBox.expand()),
                      const _AmbientGlow(),
                      SafeArea(
                          child: LayoutBuilder(
                              builder: (context, constraints) =>
                                  Column(children: [
                                    _TopBar(
                                        room: widget.room,
                                        participants: widget.participants,
                                        isPlaying:
                                            widget.room.playbackState.isPlaying,
                                        onLeave: widget.onLeave,
                                        onMenu: _showMenu),
                                    Expanded(
                                        child: constraints.maxWidth < 760
                                            ? _mobileLayout()
                                            : _wideLayout(
                                                constraints.maxWidth)),
                                  ]))),
                      if (_activity != null)
                        Positioned(
                            top: 88,
                            right: 24,
                            child: _ActivityMessage(_activity!)),
                    ])))));
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) =>
      KeyEventResult.ignored;

  Future<void> _send(PlaybackCommandType type,
      {int? positionMs,
      Map<String, dynamic>? queueItem,
      int? queueIndex,
      String? trackId,
      String? provider,
      bool? enabled}) async {
    final repository = ref.read(roomRepositoryProvider);
    final command = PlaybackCommand(
        commandId:
            '${widget.userId}_${DateTime.now().microsecondsSinceEpoch}_${type.name}',
        senderId: widget.userId,
        timestamp: DateTime.now(),
        revision: widget.room.playbackState.revision,
        type: type,
        positionMs: positionMs,
        queueItem: queueItem,
        queueIndex: queueIndex,
        trackId: trackId,
        provider: provider,
        enabled: enabled);
    try {
      await repository.submitPlaybackCommand(widget.room.id, command);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Getting that back in sync…')));
      }
    }
  }

  void _handleIntent(_RoomAction action) {
    switch (action) {
      case _RoomAction.playPause:
        _togglePlayback();
      case _RoomAction.backward:
        _seek(-10);
        _activity = 'Moved back 10 seconds';
      case _RoomAction.forward:
        _seek(10);
        _activity = 'Moved ahead 10 seconds';
      case _RoomAction.next:
        _send(PlaybackCommandType.next);
        _activity = 'Skipped to the next track';
      case _RoomAction.previous:
        _send(PlaybackCommandType.previous);
        _activity = 'Returned to the previous track';
      case _RoomAction.queue:
        _showSearch();
    }
    if (_activity != null) {
      setState(() {});
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _activity = null);
      });
    }
  }

  Future<void> _togglePlayback() async {
    final track = widget.room.currentTrack;
    if (track == null) {
      _showPlaybackError('Add a track before starting playback.');
      return;
    }
    if (widget.room.playbackState.isPlaying) {
      try {
        await _pauseProvider(_providerFor(track));
      } catch (error) {
        _showPlaybackError('$error');
      }
      await _send(PlaybackCommandType.pause);
    } else {
      try {
        await _playProvider(_trackFromRoom(track));
      } catch (error) {
        _showPlaybackError('$error');
        return;
      }
      await _send(PlaybackCommandType.play);
    }
  }

  void _seek(int seconds) {
    final position = const SyncEngine()
        .projectedPosition(widget.room.playbackState, DateTime.now());
    _seekTo(position + seconds * 1000);
  }

  void _seekTo(int positionMs) {
    final durationMs =
        (widget.room.currentTrack?['durationMs'] as num?)?.toInt() ?? 0;
    final maximum = durationMs > 0 ? durationMs : 1 << 31;
    final position = positionMs.clamp(0, maximum).toInt();
    final track = widget.room.currentTrack;
    if (track == null) return;
    unawaited(_seekAndSend(track, position));
  }

  Future<void> _seekAndSend(Map<String, dynamic> track, int position) async {
    try {
      await _seekProvider(
          _providerFor(track), Duration(milliseconds: position));
    } catch (error) {
      _showPlaybackError('$error');
      return;
    }
    await _send(PlaybackCommandType.seek, positionMs: position);
  }

  Future<void> _seekProvider(
      MusicProviderId? provider, Duration position) async {
    if (provider == MusicProviderId.youtube) {
      if (!_youtubeReady) throw StateError('YouTube player is still loading.');
      await _youtubePlayback.seek(position);
    } else if (provider == MusicProviderId.spotify) {
      if (!_spotifyReady) {
        throw StateError('Connect Spotify to seek this track.');
      }
      await _spotifyPlayback!.seek(position);
    }
  }

  void _setVolume(double value) {
    setState(() => _volume = value);
    final provider = _providerFor(widget.room.currentTrack);
    if (provider == MusicProviderId.youtube && _youtubeReady) {
      unawaited(_runPlayback(
          () => _youtubePlayback.setVolume((value * 100).round())));
    } else if (provider == MusicProviderId.spotify && _spotifyReady) {
      unawaited(_runPlayback(() => _spotifyPlayback!.setVolume(value)));
    }
  }

  Widget _wideLayout(double width) {
    final queueWidth = width >= 1180 ? 340.0 : 300.0;
    return Padding(
        padding: const EdgeInsets.fromLTRB(32, 8, 32, 24),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
              child: Center(
                  child: SingleChildScrollView(
                      child: _MainPlayer(
                          pulse: _pulse,
                          room: widget.room,
                          youtubeViewType: _youtubeViewType,
                          onYoutubeViewCreated: _initializeYouTube,
                          onPlayPause: _togglePlayback,
                          onSeek: _seek,
                          onSeekTo: _seekTo,
                          onPrevious: () => _send(PlaybackCommandType.previous),
                          onNext: () => _send(PlaybackCommandType.next),
                          shuffle: _shuffle,
                          repeat: _repeat,
                          volume: _volume,
                          onShuffle: () => setState(() => _shuffle = !_shuffle),
                          onRepeat: () => setState(() => _repeat = !_repeat),
                          onVolume: _setVolume,
                          onQueue: _showSearch)))),
          const SizedBox(width: 28),
          SizedBox(
              width: queueWidth,
              child: _QueuePanel(
                  queue: widget.room.queue,
                  onRemove: _removeQueue,
                  onReorder: _reorderQueue,
                  onAdd: _showSearch)),
        ]));
  }

  Widget _mobileLayout() => Column(children: [
        Expanded(
            child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: _MainPlayer(
                    pulse: _pulse,
                    room: widget.room,
                    youtubeViewType: _youtubeViewType,
                    onYoutubeViewCreated: _initializeYouTube,
                    onPlayPause: _togglePlayback,
                    onSeek: _seek,
                    onSeekTo: _seekTo,
                    onPrevious: () => _send(PlaybackCommandType.previous),
                    onNext: () => _send(PlaybackCommandType.next),
                    shuffle: _shuffle,
                    repeat: _repeat,
                    volume: _volume,
                    onShuffle: () => setState(() => _shuffle = !_shuffle),
                    onRepeat: () => setState(() => _repeat = !_repeat),
                    onVolume: _setVolume,
                    onQueue: _showQueueSheet))),
        Container(
            decoration: const BoxDecoration(
                color: AppColors.glassSurface,
                border: Border(top: BorderSide(color: Colors.white10))),
            child: SafeArea(
                top: false,
                child: _BottomControls(
                    onPlayPause: _togglePlayback,
                    playing: widget.room.playbackState.isPlaying,
                    onNext: () => _send(PlaybackCommandType.next),
                    onQueue: _showQueueSheet))),
      ]);

  Future<void> _removeQueue(int index) async {
    await _send(PlaybackCommandType.removeFromQueue, queueIndex: index);
    if (mounted) setState(() => _activity = 'Removed from the queue');
  }

  Future<void> _reorderQueue(int oldIndex, int newIndex) async {
    final queue = List<Map<String, dynamic>>.from(widget.room.queue);
    if (oldIndex < newIndex) newIndex--;
    final item = queue.removeAt(oldIndex);
    queue.insert(newIndex, item);
    await _send(PlaybackCommandType.clearQueue);
    for (final queued in queue) {
      await _send(PlaybackCommandType.addToQueue, queueItem: queued);
    }
  }

  Future<void> _showSearch() async => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TrackSearchSheet(onAdd: _addTrack));
  Future<void> _showQueueSheet() async => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SafeArea(
          child: SizedBox(
              height: MediaQuery.sizeOf(context).height * .72,
              child: _QueuePanel(
                  queue: widget.room.queue,
                  onRemove: _removeQueue,
                  onReorder: _reorderQueue,
                  onAdd: _showSearch))));
  Future<void> _showMenu() async {}

  Future<void> _addTrack(Track track) async {
    final item = {
      'id': track.id,
      'provider': track.provider.name,
      'title': track.title,
      'artist': track.artist,
      'albumArtUrl': track.albumArtUrl,
      'durationMs': track.durationMs,
      'externalUrl': track.externalUrl
    };
    if (widget.room.currentTrack == null) {
      await _send(PlaybackCommandType.setTrack,
          queueItem: item, trackId: track.id, provider: track.provider.name);
    } else {
      await _send(PlaybackCommandType.addToQueue, queueItem: item);
    }
    if (!mounted) return;
    setState(() {
      _activity = '${_nameForSelf()} added ${track.title}';
    });
    Navigator.of(context, rootNavigator: true).pop();
  }

  String _nameForSelf() {
    final match = widget.participants
        .where((participant) => participant.userId == widget.userId);
    return match.isEmpty ? 'You' : match.first.displayName;
  }
}

class _AmbientGlow extends StatelessWidget {
  const _AmbientGlow();
  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: Stack(children: [
          Positioned(
              top: -180,
              left: -100,
              child: Container(
                  width: 440,
                  height: 440,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary.withValues(alpha: 0.18),
                      boxShadow: [
                        BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.14),
                            blurRadius: AppBlur.ambient,
                            spreadRadius: 24)
                      ]))),
          Positioned(
              bottom: -220,
              right: -120,
              child: Container(
                  width: 520,
                  height: 520,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.accent.withValues(alpha: 0.10),
                      boxShadow: [
                        BoxShadow(
                            color: AppColors.accent.withValues(alpha: 0.08),
                            blurRadius: AppBlur.ambient,
                            spreadRadius: 32)
                      ]))),
          const Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(width: 300, height: 300)),
        ]),
      );
}

class _TopBar extends StatelessWidget {
  const _TopBar(
      {required this.room,
      required this.participants,
      required this.isPlaying,
      required this.onLeave,
      required this.onMenu});
  final ListeningRoom room;
  final List<RoomParticipant> participants;
  final bool isPlaying;
  final VoidCallback onLeave;
  final VoidCallback onMenu;
  @override
  Widget build(BuildContext context) => Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(children: [
        const Text('VYBE',
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 5)),
        const Spacer(),
        Expanded(
            child: Text(room.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w700))),
        const Spacer(),
        Row(children: [
          for (final participant in participants.take(2))
            Padding(
                padding: const EdgeInsets.only(left: 5),
                child: CircleAvatar(
                    radius: 17,
                    backgroundColor: AppColors.elevatedSurface,
                    child: Text(participant.displayName
                        .substring(0, 1)
                        .toUpperCase()))),
          const SizedBox(width: 8),
          Tooltip(
              message: participants.length < 2
                  ? 'Waiting for the other listener to reconnect'
                  : isPlaying
                      ? 'Both listening'
                      : 'One of you is paused',
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.circle,
                    size: 8,
                    color: participants.length < 2
                        ? AppColors.textSecondary
                        : AppColors.success),
                const SizedBox(width: 7),
                Text(
                    participants.length < 2
                        ? 'Waiting to reconnect'
                        : isPlaying
                            ? 'Both listening'
                            : 'A little pause',
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: AppColors.textSecondary)),
              ])),
          IconButton(
              tooltip: 'Room menu',
              onPressed: onMenu,
              icon: const Icon(Icons.more_horiz_rounded)),
          FilledButton.tonal(onPressed: onLeave, child: const Text('Leave')),
        ]),
      ]));
}

class _MainPlayer extends StatelessWidget {
  const _MainPlayer(
      {required this.pulse,
      required this.room,
      required this.youtubeViewType,
      required this.onYoutubeViewCreated,
      required this.onPlayPause,
      required this.onSeek,
      required this.onSeekTo,
      required this.onPrevious,
      required this.onNext,
      required this.shuffle,
      required this.repeat,
      required this.volume,
      required this.onShuffle,
      required this.onRepeat,
      required this.onVolume,
      required this.onQueue});
  final Animation<double> pulse;
  final ListeningRoom room;
  final String youtubeViewType;
  final ValueChanged<int> onYoutubeViewCreated;
  final VoidCallback onPlayPause,
      onPrevious,
      onNext,
      onShuffle,
      onRepeat,
      onQueue;
  final void Function(int seconds) onSeek;
  final ValueChanged<int> onSeekTo;
  final void Function(double) onVolume;
  final bool shuffle, repeat;
  final double volume;

  @override
  Widget build(BuildContext context) {
    final track = room.currentTrack;
    final title = track?['title'] as String? ?? 'Nothing playing yet';
    final artist = track?['artist'] as String? ?? 'Choose a track to begin';
    final album = track?['album'] as String? ?? '—';
    final art = track?['albumArtUrl'] as String?;
    final duration = (track?['durationMs'] as num?)?.toInt() ?? 0;
    final projectedPosition = const SyncEngine()
        .projectedPosition(room.playbackState, DateTime.now());
    final position = duration > 0
        ? projectedPosition.clamp(0, duration).toInt()
        : projectedPosition;
    return ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          AnimatedBuilder(
              animation: pulse,
              builder: (_, child) => Container(
                  width: 390,
                  height: 390,
                  constraints: const BoxConstraints(maxWidth: 520),
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadii.xl),
                      boxShadow: [
                        BoxShadow(
                            color: AppColors.violet
                                .withValues(alpha: .22 + pulse.value * .06),
                            blurRadius: 44,
                            spreadRadius: 5)
                      ]),
                  child: child),
              child: AspectRatio(
                  aspectRatio: 1,
                  child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadii.xl),
                      child: track?['provider'] == 'youtube'
                          ? YouTubePlayerSurface(
                              viewType: youtubeViewType,
                              onCreated: onYoutubeViewCreated)
                          : art == null
                              ? Container(
                                  decoration: const BoxDecoration(
                                      gradient: LinearGradient(colors: [
                                    AppColors.artworkViolet,
                                    AppColors.artworkDark
                                  ])),
                                  child: const Icon(Icons.graphic_eq_rounded,
                                      size: 84, color: AppColors.textPrimary))
                              : CachedNetworkImage(
                                  imageUrl: art,
                                  fit: BoxFit.cover,
                                  memCacheWidth: 780,
                                  memCacheHeight: 780,
                                  fadeInDuration: Duration.zero,
                                  errorWidget: (_, __, ___) => const ColoredBox(
                                      color: AppColors.artworkDark))))),
          const SizedBox(height: 26),
          Text(title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 5),
          Text('$artist • $album',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 24),
          Row(children: [
            Text(_clock(position),
                style:
                    const TextStyle(fontSize: 12, color: AppColors.textMuted)),
            Expanded(
                child: _ProgressSlider(
                    durationMs: duration,
                    positionMs: position,
                    onSeekTo: onSeekTo)),
            Text(duration == 0 ? '--:--' : _clock(duration),
                style:
                    const TextStyle(fontSize: 12, color: AppColors.textMuted)),
          ]),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            IconButton(
                tooltip: 'Previous',
                onPressed: onPrevious,
                icon: const Icon(Icons.skip_previous_rounded),
                iconSize: 34),
            const SizedBox(width: 18),
            FilledButton(
                onPressed: onPlayPause,
                style: FilledButton.styleFrom(
                    shape: const CircleBorder(),
                    fixedSize: const Size(72, 72),
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.surface),
                child: Icon(
                    room.playbackState.isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    size: 38)),
            const SizedBox(width: 18),
            IconButton(
                tooltip: 'Next',
                onPressed: onNext,
                icon: const Icon(Icons.skip_next_rounded),
                iconSize: 34),
          ]),
          const SizedBox(height: 12),
          Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 2,
              children: [
                _ToggleControl(
                    icon: Icons.shuffle_rounded,
                    label: 'Shuffle',
                    active: shuffle,
                    onPressed: onShuffle),
                _ToggleControl(
                    icon: Icons.repeat_rounded,
                    label: 'Repeat',
                    active: repeat,
                    onPressed: onRepeat),
                const SizedBox(width: 8),
                const Icon(Icons.volume_up_outlined, size: 18),
                SizedBox(
                    width: 110,
                    child: Slider(
                        value: volume,
                        onChanged: onVolume,
                        activeColor: AppColors.secondary,
                        inactiveColor: Colors.white12)),
                IconButton(
                    tooltip: 'Queue',
                    onPressed: onQueue,
                    icon: const Icon(Icons.queue_music_rounded)),
              ]),
        ]));
  }

  String _clock(int ms) {
    final seconds = ms ~/ 1000;
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }
}

class _ProgressSlider extends StatefulWidget {
  const _ProgressSlider(
      {required this.durationMs,
      required this.positionMs,
      required this.onSeekTo});
  final int durationMs;
  final int positionMs;
  final ValueChanged<int> onSeekTo;

  @override
  State<_ProgressSlider> createState() => _ProgressSliderState();
}

class _ProgressSliderState extends State<_ProgressSlider> {
  double? _scrubValue;

  @override
  Widget build(BuildContext context) {
    final duration = widget.durationMs;
    final value = duration > 0
        ? (_scrubValue ?? widget.positionMs.toDouble())
            .clamp(0, duration.toDouble())
            .toDouble()
        : 0.0;
    return Slider(
        value: duration > 0 ? value / duration : 0,
        onChanged: duration > 0
            ? (fraction) =>
                setState(() => _scrubValue = fraction * duration.toDouble())
            : null,
        onChangeEnd: duration > 0
            ? (fraction) {
                widget.onSeekTo((fraction * duration).round());
                setState(() => _scrubValue = null);
              }
            : null,
        activeColor: AppColors.secondary,
        inactiveColor: Colors.white12);
  }
}

class _ToggleControl extends StatelessWidget {
  const _ToggleControl(
      {required this.icon,
      required this.label,
      required this.active,
      required this.onPressed});
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => TextButton.icon(
      onPressed: onPressed,
      style: TextButton.styleFrom(
          foregroundColor: active ? AppColors.accent : AppColors.textSecondary),
      icon: Icon(icon, size: 19),
      label: Text(label));
}

class _QueuePanel extends StatelessWidget {
  const _QueuePanel(
      {required this.queue,
      required this.onRemove,
      required this.onReorder,
      required this.onAdd});
  final List<Map<String, dynamic>> queue;
  final Future<void> Function(int) onRemove;
  final Future<void> Function(int, int) onReorder;
  final Future<void> Function() onAdd;
  @override
  Widget build(BuildContext context) => Container(
      decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.lg),
          border: Border.all(color: Colors.white.withValues(alpha: .06))),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(
              child: Text('Up next',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
          IconButton(
              tooltip: 'Add track',
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded))
        ]),
        const SizedBox(height: 8),
        Expanded(
            child: queue.isEmpty
                ? const Center(
                    child: Text(
                        'Your queue is quiet\nAdd something you both love.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.muted)))
                : ReorderableListView.builder(
                    itemCount: queue.length,
                    onReorderItem: onReorder,
                    buildDefaultDragHandles: true,
                    itemBuilder: (_, index) {
                      final item = queue[index];
                      final provider = item['provider'] == 'youtube'
                          ? MusicProviderId.youtube
                          : MusicProviderId.spotify;
                      return ListTile(
                          key: ValueKey('${item['id']}-$index'),
                          contentPadding: EdgeInsets.zero,
                          leading: _Artwork(item['albumArtUrl'] as String?,
                              size: 48),
                          title: Text(item['title'] as String? ?? 'Track',
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text(item['artist'] as String? ?? '',
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          trailing:
                              Row(mainAxisSize: MainAxisSize.min, children: [
                            MusicProviderBadge(provider, compact: true),
                            IconButton(
                                tooltip: 'Remove from queue',
                                onPressed: () => onRemove(index),
                                icon:
                                    const Icon(Icons.close_rounded, size: 18)),
                            const Icon(Icons.drag_handle_rounded,
                                color: AppColors.muted, size: 20)
                          ]));
                    }))
      ]));
}

class _BottomControls extends StatelessWidget {
  const _BottomControls(
      {required this.onPlayPause,
      required this.playing,
      required this.onNext,
      required this.onQueue});
  final VoidCallback onPlayPause, onNext, onQueue;
  final bool playing;
  @override
  Widget build(BuildContext context) => SizedBox(
      height: 68,
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        IconButton(
            tooltip: 'Queue',
            onPressed: onQueue,
            icon: const Icon(Icons.queue_music_rounded)),
        IconButton(
            tooltip: 'Previous',
            onPressed: () {},
            icon: const Icon(Icons.skip_previous_rounded)),
        IconButton(
            tooltip: playing ? 'Pause' : 'Play',
            onPressed: onPlayPause,
            iconSize: 34,
            icon: Icon(playing
                ? Icons.pause_circle_filled_rounded
                : Icons.play_circle_fill_rounded)),
        IconButton(
            tooltip: 'Next',
            onPressed: onNext,
            icon: const Icon(Icons.skip_next_rounded)),
        IconButton(
            tooltip: 'Volume',
            onPressed: () {},
            icon: const Icon(Icons.volume_up_rounded))
      ]));
}

class _Artwork extends StatelessWidget {
  const _Artwork(this.url, {this.size = 56});
  final String? url;
  final double size;
  @override
  Widget build(BuildContext context) => ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
          width: size,
          height: size,
          child: url == null
              ? const ColoredBox(
                  color: AppColors.artworkViolet,
                  child: Icon(Icons.music_note_rounded))
              : CachedNetworkImage(
                  imageUrl: url!,
                  fit: BoxFit.cover,
                  memCacheWidth: 160,
                  memCacheHeight: 160,
                  fadeInDuration: Duration.zero,
                  errorWidget: (_, __, ___) =>
                      const ColoredBox(color: AppColors.artworkViolet))));
}

class TrackSearchSheet extends ConsumerStatefulWidget {
  const TrackSearchSheet({super.key, required this.onAdd});
  final Future<void> Function(Track) onAdd;
  @override
  ConsumerState<TrackSearchSheet> createState() => _TrackSearchSheetState();
}

class _TrackSearchSheetState extends ConsumerState<TrackSearchSheet> {
  final _query = TextEditingController();
  String _provider = 'All';
  int _visibleCount = 30;
  Timer? _debounce;
  List<Track> _spotifyResults = const [];
  List<Track> _youtubeResults = const [];
  bool _searching = false;
  String? _spotifyError;
  String? _youtubeError;
  int _searchId = 0;

  void _onQueryChanged() {
    setState(() => _visibleCount = 30);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _search);
  }

  Future<void> _search() async {
    final query = _query.text.trim();
    final id = ++_searchId;
    if (query.isEmpty) {
      setState(() {
        _spotifyResults = const [];
        _youtubeResults = const [];
        _searching = false;
        _spotifyError = null;
        _youtubeError = null;
      });
      return;
    }
    setState(() {
      _searching = true;
    });
    final searches = <Future<void>>[];
    if (_provider != 'YouTube') {
      searches.add(_searchSpotify(query, id));
    } else {
      setState(() {
        _spotifyResults = const [];
        _spotifyError = null;
      });
    }
    if (_provider != 'Spotify') {
      searches.add(_searchYouTube(query, id));
    } else {
      setState(() {
        _youtubeResults = const [];
        _youtubeError = null;
      });
    }
    await Future.wait(searches);
    if (mounted && id == _searchId) setState(() => _searching = false);
  }

  Future<void> _searchSpotify(String query, int id) async {
    if (!(ref.read(spotifyConnectionProvider).valueOrNull ?? false)) {
      if (mounted && id == _searchId) {
        setState(() {
          _spotifyResults = const [];
          _spotifyError = 'Connect Spotify from the home screen to search it.';
        });
      }
      return;
    }
    final cacheKey = 'spotify:$query';
    final cached = ref.read(musicCacheProvider).search(cacheKey);
    if (cached != null) {
      if (mounted && id == _searchId) {
        setState(() {
          _spotifyResults = cached;
          _spotifyError = null;
        });
      }
      return;
    }
    try {
      final results =
          await ref.read(spotifyMusicProviderProvider).search(query);
      ref.read(musicCacheProvider).putSearch(cacheKey, results);
      if (mounted && id == _searchId) {
        setState(() {
          _spotifyResults = results;
          _spotifyError = null;
        });
      }
    } catch (error) {
      if (mounted && id == _searchId) {
        setState(() {
          _spotifyResults = const [];
          _spotifyError = 'Spotify search failed: $error';
        });
      }
    }
  }

  Future<void> _searchYouTube(String query, int id) async {
    final cacheKey = 'youtube:$query';
    final cached = ref.read(musicCacheProvider).search(cacheKey);
    if (cached != null) {
      if (mounted && id == _searchId) {
        setState(() {
          _youtubeResults = cached;
          _youtubeError = null;
        });
      }
      return;
    }
    try {
      final results =
          await ref.read(youtubeSearchServiceProvider).search(query);
      ref.read(musicCacheProvider).putSearch(cacheKey, results);
      if (mounted && id == _searchId) {
        setState(() {
          _youtubeResults = results;
          _youtubeError = null;
        });
      }
    } catch (error) {
      if (mounted && id == _searchId) {
        setState(() {
          _youtubeResults = const [];
          _youtubeError = 'YouTube search failed: $error';
        });
      }
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = [
      if (_provider != 'YouTube') ..._spotifyResults,
      if (_provider != 'Spotify') ..._youtubeResults,
    ];
    final query = _query.text.toLowerCase();
    final searchError = [
      if (_provider != 'YouTube' && _spotifyError != null) _spotifyError,
      if (_provider != 'Spotify' && _youtubeError != null) _youtubeError,
    ].join('\n');
    final visibleResults = filtered.take(_visibleCount).toList(growable: false);
    return Container(
        margin: const EdgeInsets.only(top: 36),
        decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        child: SafeArea(
            child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Column(children: [
                  Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 18),
                  TextField(
                      controller: _query,
                      autofocus: true,
                      onChanged: (_) => _onQueryChanged(),
                      decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search_rounded),
                          hintText: 'What do you want to hear?',
                          filled: true,
                          fillColor: AppColors.elevatedSurface,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppRadii.md),
                              borderSide: BorderSide.none))),
                  const SizedBox(height: 14),
                  SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'All', label: Text('All')),
                        ButtonSegment(value: 'Spotify', label: Text('Spotify')),
                        ButtonSegment(value: 'YouTube', label: Text('YouTube'))
                      ],
                      selected: {
                        _provider
                      },
                      onSelectionChanged: (values) {
                        setState(() => _provider = values.first);
                        _search();
                      }),
                  const SizedBox(height: 12),
                  Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: _searching
                                  ? const CircularProgressIndicator()
                                  : Text(
                                      (searchError.isNotEmpty
                                              ? searchError
                                              : null) ??
                                          (query.isEmpty
                                              ? 'Search for a song'
                                              : 'No tracks found'),
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                          color: AppColors.muted)))
                          : ListView.builder(
                              itemCount: visibleResults.length +
                                  (visibleResults.length < filtered.length
                                      ? 1
                                      : 0),
                              itemBuilder: (_, index) {
                                if (index == visibleResults.length) {
                                  return Center(
                                      child: TextButton(
                                          onPressed: () => setState(
                                              () => _visibleCount += 30),
                                          child: const Text('Show more')));
                                }
                                final track = visibleResults[index];
                                return ListTile(
                                    contentPadding:
                                        const EdgeInsets.symmetric(vertical: 6),
                                    leading:
                                        _Artwork(track.albumArtUrl, size: 52),
                                    title: Text(track.title,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700)),
                                    subtitle: Text(track.artist),
                                    trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          MusicProviderBadge(track.provider),
                                          const SizedBox(width: 8),
                                          FilledButton.tonal(
                                              onPressed: () =>
                                                  widget.onAdd(track),
                                              child: const Text('Add'))
                                        ]));
                              })),
                ]))));
  }
}

class _ActivityMessage extends StatelessWidget {
  const _ActivityMessage(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Container(
          key: ValueKey(message),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
              color: AppColors.elevatedSurface,
              borderRadius: BorderRadius.circular(AppRadii.md),
              border: Border.all(color: Colors.white12)),
          child: Text(message, style: const TextStyle(fontSize: 13))));
}

enum _RoomAction { playPause, backward, forward, next, previous, queue }

class _RoomIntent extends Intent {
  const _RoomIntent(this.action);
  final _RoomAction action;
}
