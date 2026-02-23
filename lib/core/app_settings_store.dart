import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persisted app settings (local-only).
///
/// NOTE: AI is opt-in and not required for baseline functionality.
/// This store is intentionally tiny and stable.
class AppSettingsStore {
  static const String _kThemeMode = 'app.theme_mode';

  /// Loads persisted theme mode.
  ///
  /// Default: ThemeMode.dark (Jen demo default).
  Future<ThemeMode> loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kThemeMode);
    return _parseThemeMode(raw) ?? ThemeMode.dark;
  }

  /// Persists theme mode.
  Future<void> setThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kThemeMode, _serializeThemeMode(mode));
  }

  ThemeMode? _parseThemeMode(String? raw) {
    switch (raw) {
      case 'system':
        return ThemeMode.system;
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return null;
    }
  }

  String _serializeThemeMode(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'system';
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
    }
  }
}
