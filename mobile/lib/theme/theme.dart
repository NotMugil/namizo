import 'dart:ui';

import 'package:flutter/material.dart';

class NamizoTheme {
  const NamizoTheme._();

  // ── Core palette ──────────────────────────────────────────────────────
  static const Color primary = Color(0xFFF6A13A);
  static const Color secondary = Color(0xFFFFC27A);
  static const Color background = Color(0xFF0D0F14);
  static const Color surface = Color(0xFF151922);
  static const Color textPrimary = Color(0xFFF6F8FF);
  static const Color textSecondary = Color(0xFF7E8798);
  static const Color textTertiary = Color(0xFFB7BECC);

  static const Color glassFill = Color(0x33293246);
  static const Color glassStroke = Color(0x40FFFFFF);

  static BoxDecoration glassDecoration({
    BorderRadius borderRadius = const BorderRadius.all(Radius.circular(14)),
  }) => BoxDecoration(
    color: glassFill,
    borderRadius: borderRadius,
    border: Border.all(color: glassStroke, width: 0.5),
  );

  static BoxDecoration glassBlurDecoration({
    BorderRadius borderRadius = const BorderRadius.all(Radius.circular(14)),
    double sigmaX = 12,
    double sigmaY = 12,
  }) => BoxDecoration(
    color: glassFill,
    borderRadius: borderRadius,
    border: Border.all(color: glassStroke, width: 0.5),
  );

  static ImageFilter glassBlur({double sigma = 12}) =>
      ImageFilter.blur(sigmaX: sigma, sigmaY: sigma);

  // ── Semantic accent colors (toasts, status) ───────────────────────────
  static const Color error = Color(0xFFEF4444);
  static const Color success = Color(0xFF22C55E);
  static const Color info = Color(0xFF3B82F6);
  static const Color warning = Color(0xFFF59E0B);

  // ── Reusable text styles ──────────────────────────────────────────────
  static const TextStyle sectionHeaderStyle = TextStyle(
    color: Colors.white70,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 1.2,
  );

  static const TextStyle pageHeaderStyle = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
  );

  // ── Theme data ────────────────────────────────────────────────────────
  static ThemeData darkTheme({required String fontFamily}) => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: fontFamily,
    scaffoldBackgroundColor: background,
    primaryColor: primary,
    colorScheme: const ColorScheme.dark(
      primary: primary,
      secondary: secondary,
      surface: surface,
      surfaceContainer: surface,
    ),

    // AppBar
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: textPrimary,
        fontSize: 32,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.3,
      ),
    ),

    // Text Theme
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        color: textPrimary,
        fontSize: 32,
        fontWeight: FontWeight.w700,
      ),
      displayMedium: TextStyle(
        color: textPrimary,
        fontSize: 28,
        fontWeight: FontWeight.w700,
      ),
      displaySmall: TextStyle(
        color: textPrimary,
        fontSize: 24,
        fontWeight: FontWeight.w700,
      ),
      headlineMedium: TextStyle(
        color: textPrimary,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
      titleLarge: TextStyle(
        color: textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: TextStyle(
        color: textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
      bodyLarge: TextStyle(color: textPrimary, fontSize: 16),
      bodyMedium: TextStyle(
        color: textTertiary,
        fontSize: 14,
        fontWeight: FontWeight.w400,
      ),
      bodySmall: TextStyle(
        color: textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w400,
      ),
    ),

    // Input Decoration
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: glassFill,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(999),
        borderSide: const BorderSide(color: glassStroke),
      ),
      hintStyle: const TextStyle(color: textSecondary),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),

    // Elevated Button
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: textPrimary,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),

    // Card
    cardTheme: const CardThemeData(
      color: glassFill,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
      ),
    ),

    // Progress Indicator
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: primary),
  );
}
