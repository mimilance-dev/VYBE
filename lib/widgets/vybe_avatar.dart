import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class VYBEAvatar extends StatelessWidget {
  const VYBEAvatar({
    required this.initials,
    required this.label,
    this.color = AppColors.primary,
    this.isOnline = false,
    this.size = 40,
    super.key,
  });

  final String initials;
  final String label;
  final Color color;
  final bool isOnline;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label${isOnline ? ', online' : ''}',
      image: true,
      child: SizedBox(
        width: size + 4,
        height: size + 4,
        child: Stack(
          children: [
            CircleAvatar(
              radius: size / 2,
              backgroundColor: color.withValues(alpha: 0.22),
              child: Text(
                initials,
                style: TextStyle(
                  fontSize: size * 0.32,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            if (isOnline)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 11,
                  height: 11,
                  decoration: BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.elevatedSurface, width: 2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}