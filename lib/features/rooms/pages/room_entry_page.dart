import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../providers/auth_state_notifier.dart';
import '../../../theme/app_colors.dart';
import '../repositories/room_repository.dart';
import '../providers/room_providers.dart';

class CreateRoomPage extends ConsumerStatefulWidget {
  const CreateRoomPage({super.key});
  @override
  ConsumerState<CreateRoomPage> createState() => _CreateRoomPageState();
}

class _CreateRoomPageState extends ConsumerState<CreateRoomPage> {
  bool _started = false;
  String? _error;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _create();
    }
  }

  Future<void> _create() async {
    final profile = ref.read(authStateProvider).valueOrNull;
    if (profile == null) return;
    try {
      final room = await ref.read(roomServiceProvider).create(
          hostId: profile.id,
          displayName: profile.displayName ?? 'Listener',
          avatarUrl: profile.photoUrl);
      if (mounted) context.go('/room/${room.id}');
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      body: Center(
          child: _error == null
              ? const CircularProgressIndicator()
              : Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton(
                        onPressed: () => context.go('/home'),
                        child: const Text('Back home'))
                  ]))));
}

class JoinRoomPage extends ConsumerStatefulWidget {
  const JoinRoomPage({super.key, this.code});
  final String? code;
  @override
  ConsumerState<JoinRoomPage> createState() => _JoinRoomPageState();
}

class _JoinRoomPageState extends ConsumerState<JoinRoomPage> {
  late final TextEditingController _controller;
  bool _loading = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.code ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final profile = ref.read(authStateProvider).valueOrNull;
    if (profile == null || _controller.text.trim().isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final room = await ref.read(roomServiceProvider).join(
          code: _controller.text,
          userId: profile.id,
          displayName: profile.displayName ?? 'Listener',
          avatarUrl: profile.photoUrl);
      if (mounted) context.go('/room/${room.id}');
    } catch (error) {
      if (mounted) {
        setState(() => _error = error is RoomFullException
            ? error.toString()
            : error is RoomNotFoundException
                ? 'We couldn’t find a room with that code.'
                : error.toString());
      }
    }
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      body: SafeArea(
          child: Center(
              child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Icon(Icons.headphones_rounded,
                                size: 54, color: AppColors.secondary),
                            const SizedBox(height: 18),
                            Text('Join a listening room',
                                textAlign: TextAlign.center,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(fontWeight: FontWeight.w800)),
                            const SizedBox(height: 8),
                            const Text(
                                'Enter the six-character code your friend shared.',
                                textAlign: TextAlign.center),
                            const SizedBox(height: 28),
                            TextField(
                                controller: _controller,
                                autofocus: true,
                                textCapitalization:
                                    TextCapitalization.characters,
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) => _join(),
                                decoration: const InputDecoration(
                                    labelText: 'Room code',
                                    hintText: 'ABC123')),
                            const SizedBox(height: 12),
                            if (_error != null)
                              Text(_error!,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      color:
                                          Theme.of(context).colorScheme.error)),
                            const SizedBox(height: 18),
                            FilledButton(
                                onPressed: _loading ? null : _join,
                                child: _loading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2))
                                    : const Text('Join room')),
                            const SizedBox(height: 8),
                            TextButton(
                                onPressed: () => context.go('/home'),
                                child: const Text('Cancel')),
                          ]))))));
}
