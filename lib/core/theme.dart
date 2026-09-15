import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Pharco Corporation brand colors, taken from the company logo
/// (dark-gray wordmark + orange running-figure mark).
class PharcoColors {
  static const orange = Color(0xFFFAA61D);
  static const orangeDark = Color(0xFFE8930C);
  static const charcoal = Color(0xFF3A3A3A);
  static const background = Color(0xFFF7F7F8);
  static const success = Color(0xFF2E9E5B);
  static const danger = Color(0xFFD64545);
  static const pending = Color(0xFF3A79C4);
}

class PharcoTheme {
  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: PharcoColors.orange,
        primary: PharcoColors.orange,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: PharcoColors.background,
      textTheme: GoogleFonts.interTextTheme(),
    );

    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: PharcoColors.background,
        foregroundColor: PharcoColors.charcoal,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: PharcoColors.charcoal,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: PharcoColors.orange,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: PharcoColors.orange, width: 1.5),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}

/// Visual treatment for a RequestStatus badge.
class StatusStyle {
  final Color color;
  final Color background;
  const StatusStyle(this.color, this.background);
}
