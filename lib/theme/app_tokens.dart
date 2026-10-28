import 'package:flutter/material.dart';

abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

abstract final class AppRadii {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 20;
  static const double xl = 28;
}

abstract final class AppBlur {
  static const double subtle = 8;
  static const double glass = 18;
  static const double ambient = 48;
}

abstract final class AppMotion {
  static const Duration instant = Duration(milliseconds: 100);
  static const Duration fast = Duration(milliseconds: 180);
  static const Duration calm = Duration(milliseconds: 320);
  static const Duration pulse = Duration(seconds: 3);

  static Duration duration(BuildContext context, Duration duration) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : duration;
}

abstract final class AppDecorations {
  static const backgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF05030A), Color(0xFF0B0920), Color(0xFF17123A)],
  );
  static const primaryGradient = LinearGradient(
    colors: [Color(0xFF7C3AED), Color(0xFFA855F7)],
  );
  static const accentGradient = LinearGradient(
    colors: [Color(0xFF8B5CF6), Color(0xFFD946EF)],
  );
  static const coolGradient = LinearGradient(
    colors: [Color(0xFF2563EB), Color(0xFF8B5CF6)],
  );

  static BoxDecoration glass({double radius = AppRadii.lg}) => BoxDecoration(
        color: const Color(0xD9100D20),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.065)),
      );

  static List<BoxShadow> softGlow(Color color, {double opacity = .18}) => [
        BoxShadow(
            color: color.withValues(alpha: opacity),
            blurRadius: 36,
            spreadRadius: -12),
      ];
}
