import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../widgets/vybe_card.dart';
import '../../widgets/vybe_gradient_background.dart';

class AuthPageFrame extends StatelessWidget {
  const AuthPageFrame({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: VYBEGradientBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 450),
                child: VYBECard(
                  padding: const EdgeInsets.fromLTRB(30, 30, 30, 28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _AuthBrand(),
                      const SizedBox(height: 32),
                      child
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthBrand extends StatelessWidget {
  const _AuthBrand();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient:
                const LinearGradient(colors: AppColors.violetMagentaGradient),
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withValues(alpha: 0.3),
                blurRadius: 28,
              ),
            ],
          ),
          child: const Icon(Icons.graphic_eq_rounded,
              color: Colors.white, size: 29),
        ),
        const SizedBox(width: 14),
        Text(
          'VYBE',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
      ],
    );
  }
}

class AuthTextField extends StatelessWidget {
  const AuthTextField({
    required this.controller,
    required this.label,
    this.keyboardType,
    this.obscureText = false,
    this.textInputAction,
    this.onSubmitted,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;
  final bool obscureText;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      autofillHints: obscureText
          ? const [AutofillHints.password, AutofillHints.newPassword]
          : const [AutofillHints.email],
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.035),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.secondary),
        ),
      ),
    );
  }
}

class AuthErrorMessage extends StatelessWidget {
  const AuthErrorMessage({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.accent,
              ),
        ),
      ),
    );
  }
}

String authErrorMessage(Object error) {
  final code = error is FirebaseAuthException ? error.code : '';
  return switch (code) {
    'configuration-not-found' =>
      'Sign-in isn’t ready just yet. Give it another moment.',
    'invalid-email' => 'That email address does not look right.',
    'user-not-found' ||
    'wrong-password' ||
    'invalid-credential' =>
      'Those sign-in details did not match. Try again.',
    'email-already-in-use' => 'An account already uses that email.',
    'weak-password' => 'Choose a password with at least 6 characters.',
    'popup-closed-by-user' => 'The sign-in window was closed before finishing.',
    'network-request-failed' =>
      'Your connection is taking a moment. Try again when it feels ready.',
    _ => 'We couldn’t sign you in. Try again.',
  };
}

class AuthLoadingPage extends StatelessWidget {
  const AuthLoadingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const AuthPageFrame(
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(color: AppColors.secondary),
        ),
      ),
    );
  }
}
