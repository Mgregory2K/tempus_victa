import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persisted app settings (local-only).
///
/// NOTE: AI is opt-in and not required for baseline functionality.
/// This store is intentionally tiny and stable.
class AppSettingsStore {
  static const String _kDevMode = 'app.dev_mode';
  static const String _kThemeMode = 'app.theme_mode';
  static const String _kAssistantEnabled = 'app.assistant_enabled';
  static const String _kSuggestionStrictness = 'app.suggestion_strictness'; // 0=aggressive 1=balanced 2=conservative


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


  /// Loads Dev Mode flag (internal-only).
  ///
  /// Default: false.
  Future<bool> loadDevMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kDevMode) ?? false;
  }

  /// Persists Dev Mode flag (internal-only).
  Future<void> setDevMode(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kDevMode, enabled);
  }

  /// Toggles Dev Mode and returns the new value.
  Future<bool> toggleDevMode() async {
    final current = await loadDevMode();
    final next = !current;
    await setDevMode(next);
    return next;
  }

  /// Assistant Mode controls predictive suggestion banners (local-only).
  /// Default: true.
  Future<bool> loadAssistantEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kAssistantEnabled) ?? true;
  }

  Future<void> setAssistantEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAssistantEnabled, enabled);
  }

  /// Suggestion strictness:
  /// 0 = aggressive (more suggestions)
  /// 1 = balanced
  /// 2 = conservative (high confidence only)
  /// Default: 1.
  Future<int> loadSuggestionStrictness() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getInt(_kSuggestionStrictness);
    if (v == null) return 1;
    if (v < 0) return 0;
    if (v > 2) return 2;
    return v;
  }

  Future<void> setSuggestionStrictness(int v) async {
    final prefs = await SharedPreferences.getInstance();
    final clamped = v < 0 ? 0 : (v > 2 ? 2 : v);
    await prefs.setInt(_kSuggestionStrictness, clamped);
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
