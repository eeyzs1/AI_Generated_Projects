import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rfdictionary/core/utils/platform_utils.dart';

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  throw UnimplementedError('Must be initialized with SharedPreferences');
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  final SharedPreferences _prefs;
  static const String _key = 'theme_mode';

  ThemeModeNotifier(this._prefs)
      : super(PlatformUtils.isAndroid
            ? ThemeMode.system
            : _loadSavedTheme(_prefs));

  static ThemeMode _loadSavedTheme(SharedPreferences prefs) {
    final saved = prefs.getString(_key) ?? 'light';
    return switch (saved) {
      'dark' => ThemeMode.dark,
      'system' => ThemeMode.system,
      _ => ThemeMode.light,
    };
  }

  Future<void> setTheme(ThemeMode mode) async {
    if (PlatformUtils.isAndroid) return;
    state = mode;
    await _prefs.setString(_key, mode.name);
  }
}

Future<Override> provideThemeModeNotifier(SharedPreferences prefs) async {
  return themeModeProvider.overrideWith((ref) => ThemeModeNotifier(prefs));
}
