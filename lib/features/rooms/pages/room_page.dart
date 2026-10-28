import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../providers/auth_state_notifier.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_tokens.dart';
import '../models/room_models.dart';
import '../providers/room_providers.dart';
import '../playback/listening_room_screen.dart';

class RoomPage extends ConsumerStatefulWidget {
  const RoomPage({super.key, required this.roomId});
  final String roomId;

  @override
  ConsumerState<RoomPage> createState() => _RoomPageState();
}

class _RoomPageState extends ConsumerState<RoomPage>
    with WidgetsBindingObserver {
  RoomNotifier? _presence;
  String? _enterError;
  bool _joining = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final userId = ref.read(authStateProvider).valueOrNull?.id;
    if (!_joining && _presence == null && userId != null) {
      _joining = true;
      final profile = ref.read(authStateProvider).valueOrNull;
      final service = ref.read(roomServiceProvider);
      service
          .enterRoom(
              roomId: widget.roomId,
              userId: userId,
              displayName: profile?.displayName ?? 'Listener',
              avatarUrl: profile?.photoUrl)
          .then((_) {
        if (!mounted) return;
        _presence = RoomNotifier(service, widget.roomId, userId)..start();
        setState(() {});
      }, onError: (error, _) {
        if (!mounted) return;
        setState(() => _enterError = error.toString());
      });
    }
  }

  @override
  void dispose() {
    _presence?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(roomServiceProvider);
    if (_enterError != null) {
      final full = _enterError!.contains('full') ||
          _enterError!.contains('This room is full');
      return Scaffold(
          body: Center(
              child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.people_outline_rounded, size: 52),
                    const SizedBox(height: 16),
                    Text(full
                        ? 'This room is already vibing'
                        : 'We couldn’t settle into this room yet'),
                    const SizedBox(height: 8),
                    Text(
                        full
                            ? 'It has two people listening already. Try another room or ask your friend to share a spot.'
                            : 'Your connection is taking a moment. Try again in a little while.',
                        textAlign: TextAlign.center),
                    const SizedBox(height: 24),
                    FilledButton(
                        onPressed: () => context.go('/room'),
                        child: const Text('Try another room'))
                  ]))));
    }
    return Scaffold(
        body: StreamBuilder<ListeningRoom?>(
      stream: service.watch(widget.roomId),
      builder: (context, roomSnapshot) {
        final room = roomSnapshot.data;
        if (roomSnapshot.connectionState == ConnectionState.waiting &&
            room == null) {
          return const Center(child: CircularProgressIndicator());
        }
        if (room == null) {
          return const _MissingRoom();
        }
        return StreamBuilder<List<RoomParticipant>>(
          stream: service.watchParticipants(widget.roomId),
          builder: (context, participantSnapshot) {
            final connected = (participantSnapshot.data ?? const [])
                .where((p) => p.connected)
                .toList();
            if (connected.length >= 2) {
              final currentUser = ref.read(authStateProvider).valueOrNull;
              return ListeningRoomScreen(
                  room: room,
                  participants: connected,
                  userId: currentUser?.id ?? '',
                  onLeave: () => _leave());
            }
            return _RoomLobby(
                room: room,
                participants: connected,
                onInvite: () => _invite(context, room),
                onLeave: () => _leave());
          },
        );
      },
    ));
  }

  Future<void> _invite(BuildContext context, ListeningRoom room) async {
    final origin = Uri.base.origin;
    final link =
        ref.read(roomServiceProvider).inviteUrl(room.id, origin, room.code);
    await Clipboard.setData(ClipboardData(text: '${room.code}\n$link'));
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Invite link copied')));
    }
  }

  Future<void> _leave() async {
    final userId = ref.read(authStateProvider).valueOrNull?.id;
    if (userId == null) return;
    await _presence?.leave();
    if (mounted) context.go('/home');
  }
}

class _RoomLobby extends StatelessWidget {
  const _RoomLobby(
      {required this.room,
      required this.participants,
      required this.onInvite,
      required this.onLeave});
  final ListeningRoom room;
  final List<RoomParticipant> participants;
  final VoidCallback onInvite;
  final VoidCallback onLeave;
  @override
  Widget build(BuildContext context) {
    final waiting = participants.length < 2;
    return _RoomScaffold(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text(room.name,
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.w800),
          textAlign: TextAlign.center),
      const SizedBox(height: 8),
      const Icon(Icons.graphic_eq_rounded,
          color: AppColors.secondary, size: 38),
      const SizedBox(height: 18),
      Text(room.code,
          style: Theme.of(context)
              .textTheme
              .headlineMedium
              ?.copyWith(letterSpacing: 6, fontWeight: FontWeight.w800)),
      const SizedBox(height: 6),
      Text('ROOM CODE',
          style: Theme.of(context)
              .textTheme
              .labelSmall
              ?.copyWith(color: AppColors.muted, letterSpacing: 2)),
      const SizedBox(height: 32),
      const _TwoPersonVisual(),
      const SizedBox(height: 28),
      Text(waiting ? 'Waiting for your person...' : 'You’re both here.',
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.w700),
          textAlign: TextAlign.center),
      const SizedBox(height: 10),
      Text(
          waiting
              ? 'Share the code or invite link when you’re ready.'
              : 'Your listening room is ready.',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: AppColors.muted)),
      const SizedBox(height: 30),
      FilledButton.icon(
          onPressed: onInvite,
          icon: const Icon(Icons.link_rounded),
          label: const Text('Invite')),
      TextButton(onPressed: onLeave, child: const Text('Leave room')),
    ]));
  }
}

class _TwoPersonVisual extends StatefulWidget {
  const _TwoPersonVisual();
  @override
  State<_TwoPersonVisual> createState() => _TwoPersonVisualState();
}

class _TwoPersonVisualState extends State<_TwoPersonVisual>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: AppMotion.pulse)
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context) && _controller.isAnimating) {
      _controller.stop();
    }
    return AnimatedBuilder(
        animation: _controller,
        builder: (_, __) => Transform.translate(
            offset: Offset(0, -3 * _controller.value),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const CircleAvatar(
                  radius: 43,
                  backgroundColor: AppColors.elevatedSurface,
                  child: Icon(Icons.person_rounded, size: 46)),
              const SizedBox(width: 18),
              Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                      shape: BoxShape.circle, color: AppColors.secondary),
                  child: const Icon(Icons.favorite, size: 14)),
              const SizedBox(width: 18),
              const CircleAvatar(
                  radius: 43,
                  backgroundColor: AppColors.elevatedSurface,
                  child: Icon(Icons.person_outline_rounded, size: 46))
            ])));
  }
}

class _RoomScaffold extends StatelessWidget {
  const _RoomScaffold({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(children: [
        const DecoratedBox(
            position: DecorationPosition.background,
            decoration:
                BoxDecoration(gradient: AppDecorations.backgroundGradient),
            child: SizedBox.expand()),
        Positioned(
            top: -160,
            right: -120,
            child: Container(
                width: 420,
                height: 420,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.16),
                ))),
        Positioned(
            bottom: -180,
            left: -140,
            child: Container(
                width: 380,
                height: 380,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accent.withValues(alpha: 0.08),
                ))),
        SafeArea(
            child: Center(
                child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg, vertical: AppSpacing.xl),
                    child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 620),
                        child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.lg,
                                vertical: AppSpacing.xl),
                            decoration:
                                AppDecorations.glass(radius: AppRadii.xl),
                            child: child))))),
      ]));
}

class _MissingRoom extends StatelessWidget {
  const _MissingRoom();
  @override
  Widget build(BuildContext context) => const Center(
      child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('This room is unavailable or may have ended.',
              textAlign: TextAlign.center)));
}
