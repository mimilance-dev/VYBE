import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_environment.dart';
import '../../theme/app_colors.dart';
import '../../widgets/vybe_button.dart';
import '../auth/auth_widgets.dart';
import 'spotify_connection.dart';

class SpotifyConnectCard extends ConsumerStatefulWidget {
  const SpotifyConnectCard({super.key});

  @override
  ConsumerState<SpotifyConnectCard> createState() => _SpotifyConnectCardState();
}

class _SpotifyConnectCardState extends ConsumerState<SpotifyConnectCard> {
  bool _busy = false;
  String? _error;

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final connected = ref.watch(spotifyConnectionProvider).valueOrNull ?? false;
    final configured = AppEnvironment.spotifyClientId.isNotEmpty;
    final notifier = ref.read(spotifyConnectionProvider.notifier);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Colors.white.withValues(alpha: 0.035),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Wrap(
        spacing: 20,
        runSpacing: 14,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  connected ? 'Spotify connected' : 'Connect Spotify',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  configured
                      ? (connected
                          ? 'Your Spotify account is linked on this browser.'
                          : 'Link your Spotify account to search tracks in VYBE.')
                      : 'Spotify is not configured for this build yet.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.muted),
                ),
                if (_error != null) AuthErrorMessage(message: _error!),
              ],
            ),
          ),
          VYBEButton(
            label: connected ? 'Disconnect' : 'Connect Spotify',
            variant: connected
                ? VYBEButtonVariant.secondary
                : VYBEButtonVariant.primary,
            onPressed: _busy || !configured
                ? null
                : () => _run(connected ? notifier.disconnect : notifier.connect),
          ),
        ],
      ),
    );
  }
}
