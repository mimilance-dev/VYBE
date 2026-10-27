import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class VYBEGradientBackground extends StatelessWidget {
  const VYBEGradientBackground({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.background, Color(0xFF0A0614), AppColors.deepBlue],
                stops: [0, 0.56, 1],
              ),
            ),
          ),
        ),
        Positioned(
          top: -210,
          right: -120,
          child: _Glow(color: AppColors.primary.withValues(alpha: 0.20), size: 520),
        ),
        Positioned(
          bottom: -290,
          left: -180,
          child: _Glow(color: AppColors.blue.withValues(alpha: 0.13), size: 560),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(painter: _AmbientLinePainter()),
          ),
        ),
        child,
      ],
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}

class _AmbientLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.018)
      ..strokeWidth = 1;

    for (var x = 0.0; x < size.width; x += 56) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}