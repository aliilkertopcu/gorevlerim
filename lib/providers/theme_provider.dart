import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// ignore: depend_on_referenced_packages
import 'package:riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Theme mode options
enum AppThemeMode {
  light,
  dark,
  system,
}

/// Theme notifier - manages theme state and persistence
class ThemeNotifier extends StateNotifier<AppThemeMode> {
  ThemeNotifier() : super(AppThemeMode.system) {
    _loadTheme();
  }

  static const _key = 'theme_mode';

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_key);
    if (value != null) {
      state = AppThemeMode.values.firstWhere(
        (e) => e.name == value,
        orElse: () => AppThemeMode.system,
      );
    }
  }

  Future<void> setTheme(AppThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
  }

  ThemeMode get themeMode {
    switch (state) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.system:
        return ThemeMode.system;
    }
  }
}

final themeNotifierProvider = StateNotifierProvider<ThemeNotifier, AppThemeMode>((ref) {
  return ThemeNotifier();
});

/// Convenience provider for ThemeMode - watches state for reactivity
final themeModeProvider = Provider<ThemeMode>((ref) {
  final appThemeMode = ref.watch(themeNotifierProvider);
  switch (appThemeMode) {
    case AppThemeMode.light:
      return ThemeMode.light;
    case AppThemeMode.dark:
      return ThemeMode.dark;
    case AppThemeMode.system:
      return ThemeMode.system;
  }
});
