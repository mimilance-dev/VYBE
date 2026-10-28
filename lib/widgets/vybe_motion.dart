import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

class VybePressable extends StatefulWidget {
  const VybePressable({required this.child, this.onPressed, super.key});
  final Widget child;
  final VoidCallback? onPressed;

  @override
  State<VybePressable> createState() => _VybePressableState();
}

class _VybePressableState extends State<VybePressable> {
  bool _pressed = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        cursor: widget.onPressed == null ? MouseCursor.defer : SystemMouseCursors.click,
        child: GestureDetector(
          onTapDown: widget.onPressed == null ? null : (_) => setState(() => _pressed = true),
          onTapCancel: () => setState(() => _pressed = false),
          onTapUp: (_) => setState(() => _pressed = false),
          onTap: widget.onPressed,
          child: Semantics(button: true, enabled: widget.onPressed != null, child: AnimatedScale(
            scale: _pressed ? 0.97 : (_hovered ? 1.015 : 1),
            duration: AppMotion.duration(context, _pressed ? AppMotion.instant : AppMotion.fast),
            curve: Curves.easeOutCubic,
            child: widget.child,
          )),
        ),
      );
}

class VybeConnectionTransition extends StatelessWidget {
  const VybeConnectionTransition({required this.connected, required this.child, super.key});
  final bool connected;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: AppMotion.duration(context, AppMotion.calm),
        curve: Curves.easeOutCubic,
        foregroundDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          border: Border.all(color: connected
              ? const Color(0x5534D399)
              : const Color(0x22A855F7)),
        ),
        child: child,
      );
}
