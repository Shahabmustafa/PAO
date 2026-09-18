import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App-wide theme mode, shared between MyApp and the Settings > Theme
/// screen. Persisted locally so the chosen theme survives an app restart.
class ThemeController {
  ThemeController._();

  static const _prefsKey = 'theme_mode';

  static final ValueNotifier<ThemeMode> themeMode = ValueNotifier<ThemeMode>(
    ThemeMode.light,
  );

  /// Loads the previously saved theme mode from local storage, if any.
  /// Call once, before [runApp], so the right theme applies from the first
  /// frame.
  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);
    themeMode.value = ThemeMode.values.firstWhere(
      (mode) => mode.name == saved,
      orElse: () => ThemeMode.light,
    );
  }

  static Future<void> setThemeMode(ThemeMode mode) async {
    themeMode.value = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, mode.name);
  }
}
