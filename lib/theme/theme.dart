import 'package:flutter/material.dart';

class NamizoTheme {
  // Dark cinematic palette
  static const Color netflixRed = Color(0xFF7C73FF);
  static const Color netflixBlack = Color(0xFF0D0F14);
  static const Color netflixDarkGrey = Color(0xFF151922);
  static const Color netflixGrey = Color(0xFF7E8798);
  static const Color netflixLightGrey = Color(0xFFB7BECC);
  static const Color netflixWhite = Color(0xFFF6F8FF);
  static const Color glassFill = Color(0x33293246);
  static const Color glassStroke = Color(0x40FFFFFF);

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: 'Satoshi',
    scaffoldBackgroundColor: netflixBlack,
    primaryColor: netflixRed,
    colorScheme: const ColorScheme.dark(
      primary: netflixRed,
      secondary: Color(0xFF8A7FFF),
      surface: netflixDarkGrey,
      surfaceContainer: netflixDarkGrey,
    ),
    
    // AppBar
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: netflixWhite,
        fontSize: 32,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.3,
      ),
    ),
    
    // Text Theme
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        color: netflixWhite,
        fontSize: 32,
        fontWeight: FontWeight.w700,
      ),
      displayMedium: TextStyle(
        color: netflixWhite,
        fontSize: 28,
        fontWeight: FontWeight.w700,
      ),
      displaySmall: TextStyle(
        color: netflixWhite,
        fontSize: 24,
        fontWeight: FontWeight.w700,
      ),
      headlineMedium: TextStyle(
        color: netflixWhite,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
      titleLarge: TextStyle(
        color: netflixWhite,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: TextStyle(
        color: netflixWhite,
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
      bodyLarge: TextStyle(
        color: netflixWhite,
        fontSize: 16,
      ),
      bodyMedium: TextStyle(
        color: netflixLightGrey,
        fontSize: 14,
        fontWeight: FontWeight.w400,
      ),
      bodySmall: TextStyle(
        color: netflixGrey,
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
      hintStyle: const TextStyle(color: netflixGrey),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    
    // Elevated Button
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: netflixRed,
        foregroundColor: netflixWhite,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
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
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: netflixRed,
    ),
  );
}
