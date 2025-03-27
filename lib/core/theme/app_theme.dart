// lib/core/theme/app_theme.dart
import 'package:flutter/material.dart';

class AppColors {
  static Color primaryColor = const Color(0xFF1E88E5); // Blue
  static Color primaryAccent = const Color(0xFF90CAF9); // Light Blue
  static Color secondaryColor = const Color(0xFF388E3C); // Green
  static Color secondaryAccent = const Color(0xFFA5D6A7); // Light Green
  static Color titleColor = const Color(0xFF0D47A1); // Deep Blue
  static Color textColor = const Color(0xFF424242); // Dark Gray
  static Color successColor = const Color(0xFF43A047); // Fresh Green
  static Color highlightColor = const Color(0xFFFFEB3B); // Yellow
}

ThemeData primaryTheme = ThemeData(
  // seed color theme
  colorScheme: ColorScheme.fromSeed(
    seedColor: AppColors.primaryColor,
    primary: AppColors.primaryColor,
    primaryContainer: AppColors.primaryAccent,
    secondary: AppColors.secondaryColor,
    secondaryContainer: AppColors.secondaryAccent,
    surface: AppColors.secondaryAccent,
    error: Colors.red,
    onPrimary: Colors.white,
    onSecondary: Colors.white,
    onSurface: AppColors.textColor,
    onError: Colors.white,
    brightness: Brightness.light,
  ),

  // app bar theme colors
  appBarTheme: AppBarTheme(
    backgroundColor: AppColors.primaryColor,
    foregroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
    centerTitle: true,
  ),

  // text theme
  textTheme: TextTheme(
    bodyMedium: TextStyle(
      color: AppColors.textColor,
      fontSize: 16,
      letterSpacing: 0.5,
    ),
    titleMedium: TextStyle(
      color: AppColors.titleColor,
      fontSize: 18,
      fontWeight: FontWeight.bold,
    ),
  ),
);
