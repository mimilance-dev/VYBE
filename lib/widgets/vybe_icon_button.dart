import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class VYBEIconButton extends StatelessWidget {
  const VYBEIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.filled = false,
    this.size = 44,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool filled;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      constraints: BoxConstraints.tightFor(width: size, height: size),
      style: IconButton.styleFrom(
        foregroundColor: AppColors.textPrimary,
        backgroundColor: filled
            ? AppColors.primary
            : Colors.white.withValues(alpha: 0.055),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      icon: Icon(icon, size: 20),
    );
  }
}