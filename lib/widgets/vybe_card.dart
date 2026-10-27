import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class VYBECard extends StatelessWidget {
  const VYBECard({
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.blur = 14,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double blur;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: AppColors.elevatedSurface.withValues(alpha: 0.76),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.12),
                blurRadius: 36,
                spreadRadius: -10,
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}