import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class AppTextStyles {
  static TextTheme textTheme(TextTheme base) {
    return GoogleFonts.manropeTextTheme(base).copyWith(
      displayLarge: GoogleFonts.manrope(
        fontSize: 64,
        height: 1.04,
        fontWeight: FontWeight.w700,
        color: const Color(0xFFF8F7FF),
      ),
      displayMedium: GoogleFonts.manrope(
        fontSize: 48,
        height: 1.08,
        fontWeight: FontWeight.w700,
        color: const Color(0xFFF8F7FF),
      ),
      headlineSmall: GoogleFonts.manrope(
        fontSize: 24,
        height: 1.2,
        fontWeight: FontWeight.w700,
        color: const Color(0xFFF8F7FF),
      ),
      titleMedium: GoogleFonts.manrope(
        fontSize: 16,
        height: 1.35,
        fontWeight: FontWeight.w600,
        color: const Color(0xFFF8F7FF),
      ),
      bodyLarge: GoogleFonts.manrope(
        fontSize: 17,
        height: 1.6,
        color: const Color(0xFFB8B2CC),
      ),
      bodyMedium: GoogleFonts.manrope(
        fontSize: 14,
        height: 1.5,
        color: const Color(0xFFB8B2CC),
      ),
      labelLarge: GoogleFonts.manrope(
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}
