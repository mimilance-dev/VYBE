import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/auth_state_notifier.dart';
import '../../theme/app_colors.dart';
import '../../widgets/vybe_button.dart';
import 'auth_widgets.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _emailMode = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) setState(() => _error = authErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(authStateProvider.notifier);
    return AuthPageFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Welcome back',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text('Listen together.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 28),
          if (!_emailMode) ...[
            VYBEButton(
              label: 'Continue with Google',
              icon: Icons.login_rounded,
              variant: VYBEButtonVariant.secondary,
              expand: true,
              onPressed: _busy ? null : () => _run(notifier.signInWithGoogle),
            ),
            const SizedBox(height: 12),
            VYBEButton(
              label: 'Continue with email',
              icon: Icons.mail_outline_rounded,
              expand: true,
              onPressed: _busy ? null : () => setState(() => _emailMode = true),
            ),
            const SizedBox(height: 18),
            TextButton(
              onPressed: _busy ? null : () => _run(notifier.signInAsGuest),
              child: const Text('Continue as a guest'),
            ),
            TextButton(
              onPressed: _busy ? null : () => context.go('/signup'),
              child: const Text('New here? Create an account'),
            ),
          ] else ...[
            AuthTextField(
              controller: _emailController,
              label: 'Email',
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 14),
            AuthTextField(
              controller: _passwordController,
              label: 'Password',
              obscureText: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submitEmail(notifier),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _busy ? null : () => context.go('/forgot-password'),
                child: const Text('Forgot password?'),
              ),
            ),
            VYBEButton(
              label: 'Sign in',
              icon: Icons.arrow_forward_rounded,
              expand: true,
              onPressed: _busy ? null : () => _submitEmail(notifier),
            ),
            TextButton(
              onPressed: _busy ? null : () => context.go('/signup'),
              child: const Text('Create an account'),
            ),
          ],
          if (_busy) ...[
            const SizedBox(height: 18),
            const Center(
              child: SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.secondary,
                ),
              ),
            ),
          ],
          if (_error != null) AuthErrorMessage(message: _error!),
          const SizedBox(height: 12),
          Text(
            'A little closer, wherever you are.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.muted,
                ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitEmail(AuthStateNotifier notifier) => _run(
        () => notifier.signInWithEmail(
          email: _emailController.text,
          password: _passwordController.text,
        ),
      );
}