import 'package:flutter/material.dart';

/// Provides the current ThemeMode + a setter to the widget tree.
class AppThemeController extends InheritedWidget {
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> setThemeMode;

  const AppThemeController({
    super.key,
    required this.themeMode,
    required this.setThemeMode,
    required super.child,
  });

  static AppThemeController of(BuildContext context) {
    final v = context.dependOnInheritedWidgetOfExactType<AppThemeController>();
    if (v == null) {
      throw StateError('AppThemeController not found in widget tree.');
    }
    return v;
  }

  @override
  bool updateShouldNotify(AppThemeController oldWidget) =>
      themeMode != oldWidget.themeMode;
}
