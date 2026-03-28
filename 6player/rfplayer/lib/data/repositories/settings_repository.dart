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

  Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    
    return AppSettings(
      themeMode: ThemeMode.values[prefs.getInt(_themeModeKey) ?? 0],
      uiStyle: UIStyle.values[prefs.getInt(_uiStyleKey) ?? 2],
      language: AppLanguage.values[prefs.getInt(_languageKey) ?? 0],
      rememberPlaybackPosition: prefs.getBool(_rememberPositionKey) ?? true,
      historyMaxItems: prefs.getInt(_historyMaxItemsKey) ?? 100,
      defaultOpenPath: prefs.getString(_defaultOpenPathKey),
      showHiddenFiles: prefs.getBool(_showHiddenFilesKey) ?? false,
      defaultPlaybackSpeed: prefs.getDouble(_defaultPlaybackSpeedKey) ?? 1.0,
    );
  }

  Future<void> save(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    
    await prefs.setInt(_themeModeKey, settings.themeMode.index);
    await prefs.setInt(_uiStyleKey, settings.uiStyle.index);
    await prefs.setInt(_languageKey, settings.language.index);
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