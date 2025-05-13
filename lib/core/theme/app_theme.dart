// lib/core/theme/app_theme.dart

import 'package:flutter/material.dart';

/// Centralized color definitions for light & dark modes.
class AppColors {
  // --------- Light mode palette ----------
  static const Color deepTeal = Color(0xFF004E64); //  0, 78,100
  static const Color skyBlue = Color(0xFF00A5CF); //  0,165,207
  static const Color pastelMint = Color(0xFF9FFFCB); //159,255,203
  static const Color seaGreen = Color(0xFF25A18E); // 37,161,142
  static const Color lightGreen = Color(0xFF7AE582); //122,229,130
  static const Color coral = Color(0xFFFF6F61); //255,111, 97 – warm accent
  static const Color mustard = Color(
    0xFFFFC85C,
  ); //255,200, 92 – golden highlight
  static const Color charcoal = Color(0xFF333333); // 51, 51, 51 – dark neutral
  static const Color fog = Color(0xFFF4F4F4); //244,244,244 – light neutral

  // --------- Dark mode overrides ---------
  static const Color darkBackground = Color(0xFF121212);
  static const Color darkSurface = Color(0xFF1E1E1E);
  static const Color darkOnSurface = Color(0xFFE0E0E0);
  static const Color darkPrimary = skyBlue; // reuse skyBlue
  static const Color darkOnPrimary = charcoal;
}

/// Light theme (use as `theme:` in MaterialApp)
final ThemeData primaryTheme = ThemeData(
  brightness: Brightness.light,

  // seed-based ColorScheme for light mode
  colorScheme: ColorScheme.fromSeed(
    seedColor: AppColors.deepTeal,
    brightness: Brightness.light,

    // primary & secondary
    primary: AppColors.deepTeal,
    onPrimary: Colors.white,
    secondary: AppColors.seaGreen,
    onSecondary: Colors.white,

    // tertiary: call-to-action, FAB, etc.
    tertiary: AppColors.coral,
    onTertiary: Colors.white,

    // surfaces & backgrounds
    background: AppColors.fog,
    onBackground: AppColors.charcoal,
    surface: Colors.white,
    onSurface: AppColors.charcoal,

    // error
    error: Colors.red,
    onError: Colors.white,
  ),

  // AppBar styling
  appBarTheme: AppBarTheme(
    backgroundColor: AppColors.deepTeal,
    foregroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
    centerTitle: true,
  ),

  // global text styles
  textTheme: TextTheme(
    bodyMedium: TextStyle(
      color: AppColors.charcoal,
      fontSize: 16,
      letterSpacing: 0.5,
    ),
    titleMedium: TextStyle(
      color: AppColors.deepTeal,
      fontSize: 18,
      fontWeight: FontWeight.bold,
    ),
  ),

  // highlight / selection color
  highlightColor: AppColors.mustard,
);

/// Dark theme (use as `darkTheme:` in MaterialApp)
final ThemeData darkTheme = ThemeData(
  brightness: Brightness.dark,

  // seed-based ColorScheme for dark mode
  colorScheme: ColorScheme.fromSeed(
    seedColor: AppColors.darkPrimary,
    brightness: Brightness.dark,

    // primary & secondary
    primary: AppColors.darkPrimary,
    onPrimary: AppColors.darkOnPrimary,
    secondary: AppColors.seaGreen,
    onSecondary: AppColors.darkOnSurface,

    // tertiary: call-to-action, FAB, etc.
    tertiary: AppColors.coral,
    onTertiary: AppColors.darkOnSurface,

    // surfaces & backgrounds
    background: AppColors.darkBackground,
    onBackground: AppColors.darkOnSurface,
    surface: AppColors.darkSurface,
    onSurface: AppColors.darkOnSurface,

    // error (slightly softer on dark)
    error: Colors.red.shade400,
    onError: AppColors.darkOnSurface,
  ),

  // AppBar styling
  appBarTheme: AppBarTheme(
    backgroundColor: AppColors.darkSurface,
    foregroundColor: AppColors.darkOnSurface,
    surfaceTintColor: Colors.transparent,
    centerTitle: true,
  ),

  // global text styles
  textTheme: TextTheme(
    bodyMedium: TextStyle(
      color: AppColors.darkOnSurface,
      fontSize: 16,
      letterSpacing: 0.5,
    ),
    titleMedium: TextStyle(
      color: AppColors.darkPrimary,
      fontSize: 18,
      fontWeight: FontWeight.bold,
    ),
  ),

  // highlight / selection color (toned for dark)
  highlightColor: AppColors.mustard.withOpacity(0.8),
);
