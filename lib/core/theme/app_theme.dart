// lib/core/theme/app_theme.dart

import 'package:flutter/material.dart';

/// Centralized color definitions for light & dark modes.
class AppColors {
  // --------- Core Color Palette ----------
  // Original provided colors
  static const Color darkCharcoal = Color(0xFF353535); // 53, 53, 53
  static const Color teal = Color(0xFF3C6E71); // 60, 110, 113
  static const Color pureWhite = Color(0xFFFFFFFF); // 255, 255, 255
  static const Color lightGray = Color(0xFFD9D9D9); // 217, 217, 217
  static const Color navyBlue = Color(0xFF284B63); // 40, 75, 99

  // --------- Light mode palette ----------
  // Primary colors - blues and teals
  static const Color primary = navyBlue; // Main primary
  static const Color primaryLight = Color(0xFF3A6A8C); // Lighter navy
  static const Color primaryDark = Color(0xFF1A3244); // Darker navy

  // Secondary colors - teals
  static const Color secondary = teal; // Main secondary
  static const Color secondaryLight = Color(0xFF4F9296); // Lighter teal
  static const Color secondaryDark = Color(0xFF2A4E50); // Darker teal

  // Accent colors - complementary to the main palette
  static const Color accent1 = Color(0xFF8ECAE6); // Soft blue
  static const Color accent2 = Color(0xFF95B8D1); // Muted blue
  static const Color accent3 = Color(0xFFE9C46A); // Muted gold/amber

  // Surface and background colors
  static const Color background = pureWhite;
  static const Color surface = Color(0xFFF7F7F7); // Off-white
  static const Color surfaceVariant = Color(0xFFEEF2F5); // Very light blue-gray

  // Text and icon colors
  static const Color onPrimary = pureWhite;
  static const Color onSecondary = pureWhite;
  static const Color onBackground = darkCharcoal;
  static const Color onSurface = darkCharcoal;
  static const Color textSecondary = Color(
    0xFF5C5C5C,
  ); // Mid-gray for secondary text

  // Status colors
  static const Color success = Color(0xFF4F9B55); // Green
  static const Color warning = Color(0xFFE9C46A); // Amber/gold
  static const Color error = Color(0xFFD62828); // Red
  static const Color info = Color(0xFF4F9BE6); // Blue

  // --------- Dark mode palette ---------
  static const Color darkBackground = Color(0xFF121212);
  static const Color darkSurface = Color(0xFF1E1E1E);
  static const Color darkSurfaceVariant = Color(0xFF2C2C2C);

  // Dark mode primary colors
  static const Color darkPrimary = Color(
    0xFF5A8CAF,
  ); // Lighter navy for dark mode
  static const Color darkPrimaryLight = Color(0xFF7AAED1); // Even lighter navy
  static const Color darkPrimaryDark = Color(0xFF3A6988); // Mid-tone navy

  // Dark mode secondary colors
  static const Color darkSecondary = Color(
    0xFF5C9EA2,
  ); // Lighter teal for dark mode
  static const Color darkSecondaryLight = Color(
    0xFF7CBEC2,
  ); // Even lighter teal
  static const Color darkSecondaryDark = Color(0xFF3C7E82); // Mid-tone teal

  // Dark mode accent colors
  static const Color darkAccent1 = Color(0xFF6BAFD1); // Darker soft blue
  static const Color darkAccent2 = Color(0xFF7A9CB5); // Darker muted blue
  static const Color darkAccent3 = Color(0xFFD4B14D); // Darker muted gold

  // Dark mode text and icon colors
  static const Color darkOnPrimary = darkCharcoal;
  static const Color darkOnSecondary = darkCharcoal;
  static const Color darkOnBackground = Color(0xFFE6E6E6); // Light gray
  static const Color darkOnSurface = Color(0xFFE6E6E6); // Light gray
  static const Color darkTextSecondary = Color(0xFFB3B3B3); // Light-mid gray

  // Dark mode status colors
  static const Color darkSuccess = Color(0xFF62BD6A); // Brighter green
  static const Color darkWarning = Color(0xFFFFD166); // Brighter amber
  static const Color darkError = Color(0xFFE95E5E); // Softer red
  static const Color darkInfo = Color(0xFF62B5FF); // Brighter blue
}

/// Light theme (use as `theme:` in MaterialApp)
final ThemeData primaryTheme = ThemeData(
  brightness: Brightness.light,
  useMaterial3: true,

  // ColorScheme for light mode
  colorScheme: ColorScheme(
    brightness: Brightness.light,

    // Primary colors
    primary: AppColors.primary,
    onPrimary: AppColors.onPrimary,
    primaryContainer: AppColors.primaryLight,
    onPrimaryContainer: AppColors.onPrimary,

    // Secondary colors
    secondary: AppColors.secondary,
    onSecondary: AppColors.onSecondary,
    secondaryContainer: AppColors.secondaryLight,
    onSecondaryContainer: AppColors.onSecondary,

    // Tertiary/accent colors
    tertiary: AppColors.accent1,
    onTertiary: AppColors.darkCharcoal,
    tertiaryContainer: AppColors.accent2,
    onTertiaryContainer: AppColors.darkCharcoal,
    surface: AppColors.surface,
    onSurface: AppColors.onSurface,
    surfaceContainerHighest: AppColors.surfaceVariant,
    onSurfaceVariant: AppColors.textSecondary,

    // Other standard colors
    error: AppColors.error,
    onError: AppColors.pureWhite,
    outline: AppColors.lightGray,
    outlineVariant: AppColors.teal.withValues(alpha: 0.2),
    scrim: AppColors.darkCharcoal.withValues(alpha: 0.3),
    shadow: AppColors.darkCharcoal.withValues(alpha: 0.2),
  ),

  // AppBar styling
  appBarTheme: const AppBarTheme(
    backgroundColor: AppColors.primary,
    foregroundColor: AppColors.onPrimary,
    surfaceTintColor: Colors.transparent,
    centerTitle: true,
    elevation: 2,
  ),

  // Card styling
  cardTheme: CardThemeData(
    color: AppColors.surface,
    elevation: 2,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  ),

  // Elevated button styling
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.onPrimary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    ),
  ),

  // Outlined button styling
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: AppColors.primary,
      side: const BorderSide(color: AppColors.primary),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    ),
  ),

  // Text button styling
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: AppColors.primary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    ),
  ),

  // Floating action button styling
  floatingActionButtonTheme: const FloatingActionButtonThemeData(
    backgroundColor: AppColors.accent3,
    foregroundColor: AppColors.darkCharcoal,
  ),

  // Global text styles
  textTheme: const TextTheme(
    displayLarge: TextStyle(
      color: AppColors.onBackground,
      fontSize: 32,
      fontWeight: FontWeight.bold,
    ),
    displayMedium: TextStyle(
      color: AppColors.onBackground,
      fontSize: 28,
      fontWeight: FontWeight.bold,
    ),
    displaySmall: TextStyle(
      color: AppColors.onBackground,
      fontSize: 24,
      fontWeight: FontWeight.bold,
    ),
    headlineMedium: TextStyle(
      color: AppColors.onBackground,
      fontSize: 20,
      fontWeight: FontWeight.bold,
    ),
    titleLarge: TextStyle(
      color: AppColors.primary,
      fontSize: 20,
      fontWeight: FontWeight.bold,
    ),
    titleMedium: TextStyle(
      color: AppColors.primary,
      fontSize: 18,
      fontWeight: FontWeight.bold,
    ),
    titleSmall: TextStyle(
      color: AppColors.primary,
      fontSize: 16,
      fontWeight: FontWeight.bold,
    ),
    bodyLarge: TextStyle(
      color: AppColors.onBackground,
      fontSize: 16,
      letterSpacing: 0.5,
    ),
    bodyMedium: TextStyle(
      color: AppColors.onBackground,
      fontSize: 14,
      letterSpacing: 0.5,
    ),
    bodySmall: TextStyle(
      color: AppColors.textSecondary,
      fontSize: 12,
      letterSpacing: 0.4,
    ),
    labelLarge: TextStyle(
      color: AppColors.onPrimary,
      fontSize: 14,
      fontWeight: FontWeight.w500,
    ),
  ),

  // Input decoration
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: AppColors.surfaceVariant,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: AppColors.primary, width: 2),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    hintStyle: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.7)),
  ),

  // Divider color
  dividerTheme: const DividerThemeData(
    color: AppColors.lightGray,
    thickness: 1,
    space: 1,
  ),

  // Switch theme
  switchTheme: SwitchThemeData(
    thumbColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return AppColors.primary;
      }
      return AppColors.lightGray;
    }),
    trackColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return AppColors.primary.withValues(alpha: 0.3);
      }
      return AppColors.lightGray.withValues(alpha: 0.5);
    }),
  ),

  // Checkbox theme
  checkboxTheme: CheckboxThemeData(
    fillColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return AppColors.primary;
      }
      return null;
    }),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
  ),

  // Radio button theme
  radioTheme: RadioThemeData(
    fillColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return AppColors.primary;
      }
      return null;
    }),
  ),

  // Chip theme
  chipTheme: ChipThemeData(
    backgroundColor: AppColors.surfaceVariant,
    labelStyle: const TextStyle(color: AppColors.onBackground),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  ),

  // Bottom navigation bar theme
  bottomNavigationBarTheme: const BottomNavigationBarThemeData(
    backgroundColor: AppColors.surface,
    selectedItemColor: AppColors.primary,
    unselectedItemColor: AppColors.textSecondary,
  ),

  // List tile theme
  listTileTheme: const ListTileThemeData(
    tileColor: AppColors.surface,
    textColor: AppColors.onSurface,
    iconColor: AppColors.primary,
  ),
);

/// Dark theme (use as `darkTheme:` in MaterialApp)
final ThemeData darkTheme = ThemeData(
  brightness: Brightness.dark,
  useMaterial3: true,

  // ColorScheme for dark mode
  colorScheme: ColorScheme(
    brightness: Brightness.dark,

    // Primary colors
    primary: AppColors.darkPrimary,
    onPrimary: AppColors.darkOnPrimary,
    primaryContainer: AppColors.darkPrimaryLight,
    onPrimaryContainer: AppColors.darkOnPrimary,

    // Secondary colors
    secondary: AppColors.darkSecondary,
    onSecondary: AppColors.darkOnSecondary,
    secondaryContainer: AppColors.darkSecondaryLight,
    onSecondaryContainer: AppColors.darkOnSecondary,

    // Tertiary/accent colors
    tertiary: AppColors.darkAccent1,
    onTertiary: AppColors.darkCharcoal,
    tertiaryContainer: AppColors.darkAccent2,
    onTertiaryContainer: AppColors.darkCharcoal,
    surface: AppColors.darkSurface,
    onSurface: AppColors.darkOnSurface,
    surfaceContainerHighest: AppColors.darkSurfaceVariant,
    onSurfaceVariant: AppColors.darkTextSecondary,

    // Other standard colors
    error: AppColors.darkError,
    onError: AppColors.darkOnPrimary,
    outline: AppColors.darkTextSecondary.withValues(alpha: 0.5),
    outlineVariant: AppColors.darkSecondary.withValues(alpha: 0.2),
    scrim: Colors.black.withValues(alpha: 0.5),
    shadow: Colors.black.withValues(alpha: 0.2),
  ),

  // AppBar styling
  appBarTheme: const AppBarTheme(
    backgroundColor: AppColors.darkSurface,
    foregroundColor: AppColors.darkOnSurface,
    surfaceTintColor: Colors.transparent,
    centerTitle: true,
    elevation: 2,
  ),

  // Card styling
  cardTheme: CardThemeData(
    color: AppColors.darkSurfaceVariant,
    elevation: 4,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  ),

  // Elevated button styling
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.darkPrimary,
      foregroundColor: AppColors.darkOnPrimary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    ),
  ),

  // Outlined button styling
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: AppColors.darkPrimary,
      side: const BorderSide(color: AppColors.darkPrimary),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    ),
  ),

  // Text button styling
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: AppColors.darkPrimary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    ),
  ),

  // Floating action button styling
  floatingActionButtonTheme: const FloatingActionButtonThemeData(
    backgroundColor: AppColors.darkAccent3,
    foregroundColor: AppColors.darkCharcoal,
  ),

  // Global text styles
  textTheme: const TextTheme(
    displayLarge: TextStyle(
      color: AppColors.darkOnBackground,
      fontSize: 32,
      fontWeight: FontWeight.bold,
    ),
    displayMedium: TextStyle(
      color: AppColors.darkOnBackground,
      fontSize: 28,
      fontWeight: FontWeight.bold,
    ),
    displaySmall: TextStyle(
      color: AppColors.darkOnBackground,
      fontSize: 24,
      fontWeight: FontWeight.bold,
    ),
    headlineMedium: TextStyle(
      color: AppColors.darkOnBackground,
      fontSize: 20,
      fontWeight: FontWeight.bold,
    ),
    titleLarge: TextStyle(
      color: AppColors.darkPrimary,
      fontSize: 20,
      fontWeight: FontWeight.bold,
    ),
    titleMedium: TextStyle(
      color: AppColors.darkPrimary,
      fontSize: 18,
      fontWeight: FontWeight.bold,
    ),
    titleSmall: TextStyle(
      color: AppColors.darkPrimary,
      fontSize: 16,
      fontWeight: FontWeight.bold,
    ),
    bodyLarge: TextStyle(
      color: AppColors.darkOnBackground,
      fontSize: 16,
      letterSpacing: 0.5,
    ),
    bodyMedium: TextStyle(
      color: AppColors.darkOnBackground,
      fontSize: 14,
      letterSpacing: 0.5,
    ),
    bodySmall: TextStyle(
      color: AppColors.darkTextSecondary,
      fontSize: 12,
      letterSpacing: 0.4,
    ),
    labelLarge: TextStyle(
      color: AppColors.darkOnPrimary,
      fontSize: 14,
      fontWeight: FontWeight.w500,
    ),
  ),

  // Input decoration
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: AppColors.darkSurfaceVariant,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: AppColors.darkPrimary, width: 2),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    hintStyle: TextStyle(
      color: AppColors.darkTextSecondary.withValues(alpha: 0.7),
    ),
  ),

  // Divider color
  dividerTheme: const DividerThemeData(
    color: AppColors.darkSurfaceVariant,
    thickness: 1,
    space: 1,
  ),

  // Switch theme
  switchTheme: SwitchThemeData(
    thumbColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return AppColors.darkPrimary;
      }
      return AppColors.darkSurfaceVariant;
    }),
    trackColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return AppColors.darkPrimary.withValues(alpha: 0.3);
      }
      return AppColors.darkTextSecondary.withValues(alpha: 0.3);
    }),
  ),

  // Checkbox theme
  checkboxTheme: CheckboxThemeData(
    fillColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return AppColors.darkPrimary;
      }
      return null;
    }),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
  ),

  // Radio button theme
  radioTheme: RadioThemeData(
    fillColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return AppColors.darkPrimary;
      }
      return null;
    }),
  ),

  // Chip theme
  chipTheme: ChipThemeData(
    backgroundColor: AppColors.darkSurfaceVariant,
    labelStyle: const TextStyle(color: AppColors.darkOnBackground),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  ),

  // Bottom navigation bar theme
  bottomNavigationBarTheme: const BottomNavigationBarThemeData(
    backgroundColor: AppColors.darkSurface,
    selectedItemColor: AppColors.darkPrimary,
    unselectedItemColor: AppColors.darkTextSecondary,
  ),

  // List tile theme
  listTileTheme: const ListTileThemeData(
    tileColor: AppColors.darkSurface,
    textColor: AppColors.darkOnSurface,
    iconColor: AppColors.darkPrimary,
  ),
);
