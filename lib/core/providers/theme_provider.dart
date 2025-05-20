// lib/core/providers/theme_provider.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  final SharedPreferences preferences;
  static const String themeModeKey = 'theme_mode';

  ThemeMode _themeMode = ThemeMode.system;

  ThemeProvider({required this.preferences}) {
    _loadThemeMode();
  }

  ThemeMode get themeMode => _themeMode;

  void _loadThemeMode() {
    final savedMode = preferences.getString(themeModeKey);
    if (savedMode != null) {
      _themeMode = _stringToThemeMode(savedMode);
    }
  }

  void setThemeMode(ThemeMode mode) {
    if (_themeMode == mode) return;
    _themeMode = mode;
    preferences.setString(themeModeKey, _themeModeToString(mode));
    notifyListeners();
  }

  String _themeModeToString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }

  ThemeMode _stringToThemeMode(String modeString) {
    switch (modeString) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }
}
