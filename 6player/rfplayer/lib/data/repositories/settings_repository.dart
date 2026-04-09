import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_settings.dart';

class SettingsRepository {
  static const String _themeModeKey = 'theme_mode';
  static const String _uiStyleKey = 'ui_style';
  static const String _languageKey = 'language';
  static const String _rememberPositionKey = 'remember_position';
  static const String _historyMaxItemsKey = 'history_max_items';
  static const String _defaultOpenPathKey = 'default_open_path';
  static const String _showHiddenFilesKey = 'show_hidden_files';
  static const String _defaultPlaybackSpeedKey = 'default_playback_speed';

  T _parseEnum<T>(List<T> values, String? name, T defaultValue) {
    if (name == null) return defaultValue;
    for (final value in values) {
      if ((value as dynamic).name == name) {
        return value;
      }
    }
    return defaultValue;
  }

  Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    
    return AppSettings(
      themeMode: _parseEnum(
        AppThemeMode.values,
        prefs.getString(_themeModeKey),
        AppThemeMode.system,
      ),
      uiStyle: _parseEnum(
        UIStyle.values,
        prefs.getString(_uiStyleKey),
        UIStyle.adaptive,
      ),
      language: _parseEnum(
        AppLanguage.values,
        prefs.getString(_languageKey),
        AppLanguage.system,
      ),
      rememberPlaybackPosition: prefs.getBool(_rememberPositionKey) ?? true,
      historyMaxItems: prefs.getInt(_historyMaxItemsKey) ?? 100,
      defaultOpenPath: prefs.getString(_defaultOpenPathKey),
      showHiddenFiles: prefs.getBool(_showHiddenFilesKey) ?? false,
      defaultPlaybackSpeed: prefs.getDouble(_defaultPlaybackSpeedKey) ?? 1.0,
    );
  }

  Future<void> save(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    
    await prefs.setString(_themeModeKey, settings.themeMode.name);
    await prefs.setString(_uiStyleKey, settings.uiStyle.name);
    await prefs.setString(_languageKey, settings.language.name);
    await prefs.setBool(_rememberPositionKey, settings.rememberPlaybackPosition);
    await prefs.setInt(_historyMaxItemsKey, settings.historyMaxItems);
    if (settings.defaultOpenPath != null) {
      await prefs.setString(_defaultOpenPathKey, settings.defaultOpenPath!);
    } else {
      await prefs.remove(_defaultOpenPathKey);
    }
    await prefs.setBool(_showHiddenFilesKey, settings.showHiddenFiles);
    await prefs.setDouble(_defaultPlaybackSpeedKey, settings.defaultPlaybackSpeed);
  }
}