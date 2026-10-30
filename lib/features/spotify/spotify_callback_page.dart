import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_colors.dart';
import '../../widgets/vybe_button.dart';
import '../auth/auth_widgets.dart';
import 'spotify_connection.dart';

/// Landing page for Spotify's OAuth redirect. It completes the PKCE exchange
/// once, then returns to the app.
class SpotifyCallbackPage extends ConsumerStatefulWidget {
  const SpotifyCallbackPage({
    this.code,
    this.state,
    this.error,
    super.key,
  });

  final String? code;
  final String? state;
  final String? error;

  @override
  ConsumerState<SpotifyCallbackPage> createState() =>
      _SpotifyCallbackPageState();
}

class _SpotifyCallbackPageState extends ConsumerState<SpotifyCallbackPage> {
  String? _error;

  @override
  void initState() {
    super.initState();
    Future.microtask(_complete);
  }

  Future<void> _complete() async {
    try {
      await ref.read(spotifyConnectionProvider.notifier).completeAuthorization(
            code: widget.code,
            returnedState: widget.state,
            error: widget.error,
          );
      if (mounted) context.go('/home');
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    return AuthPageFrame(
      child: error == null
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(color: AppColors.secondary),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text("Spotify didn't connect",
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall),
                AuthErrorMessage(message: error),
                const SizedBox(height: 24),
                VYBEButton(
                  label: 'Back home',
                  expand: true,
                  onPressed: () => context.go('/home'),
                ),
              ],
            ),
    );
  }
}
