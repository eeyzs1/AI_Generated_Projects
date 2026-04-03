import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum UIStyle { material3, fluent, adaptive }
enum ThemeModeOption { system, light, dark }
enum LanguageOption { system, zh, en }

const _kUIStyleKey = 'ui_style';
const _kThemeModeKey = 'theme_mode';
const _kLanguageKey = 'language';
const _kCurrentIndexKey = 'current_index';
const _kSeedColorKey = 'seed_color';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'appTitle': 'RFDictionary',
      'dictionary': 'Dictionary',
      'favorites': 'Favorites',
      'history': 'History',
      'settings': 'Settings',
      'searchHint': 'Enter word or sentence...',
      'recentSearches': 'Recent Searches',
      'startSearching': 'Start searching words',
      'appearance': 'Appearance',
      'uiStyle': 'UI Style',
      'material3': 'Material 3',
      'fluent': 'Fluent',
      'adaptive': 'Adaptive',
      'themeMode': 'Theme Mode',
      'system': 'System',
      'light': 'Light',
      'dark': 'Dark',
      'accentColor': 'Accent Color',
      'language': 'Language',
      'chinese': 'Chinese',
      'english': 'English',
      'aiFeatures': 'AI Features',
      'aiModel': 'AI Model',
      'notInstalled': 'Not Installed',
      'download': 'Download',
      'dataManagement': 'Data Management',
      'clearSearchHistory': 'Clear Search History',
      'clearAllFavorites': 'Clear All Favorites',
      'about': 'About',
      'version': 'Version',
      'ecdictInfo': 'ECDICT (~3.3M entries)',
      'completelyFree': 'Completely Free Dictionary',
    },
    'zh': {
      'appTitle': 'RFDictionary',
      'dictionary': '词典',
      'favorites': '收藏',
      'history': '历史',
      'settings': '设置',
      'searchHint': '输入单词或句子...',
      'recentSearches': '最近搜索',
      'startSearching': '开始搜索单词',
      'appearance': '外观',
      'uiStyle': 'UI 样式',
      'material3': 'Material 3',
      'fluent': 'Fluent',
      'adaptive': '自适应',
      'themeMode': '主题模式',
      'system': '跟随系统',
      'light': '浅色',
      'dark': '深色',
      'accentColor': '强调色',
      'language': '语言',
      'chinese': '中文',
      'english': '英文',
      'aiFeatures': 'AI 功能',
      'aiModel': 'AI 模型',
      'notInstalled': '未安装',
      'download': '下载',
      'dataManagement': '数据管理',
      'clearSearchHistory': '清除搜索历史',
      'clearAllFavorites': '清除所有收藏',
      'about': '关于',
      'version': '版本',
      'ecdictInfo': 'ECDICT (~330万词条)',
      'completelyFree': '完全免费的字典',
    },
  };

  String _t(String key) => _localizedValues[locale.languageCode]?[key] ?? _localizedValues['en']![key]!;

  String get appTitle => _t('appTitle');
  String get dictionary => _t('dictionary');
  String get favorites => _t('favorites');
  String get history => _t('history');
  String get settings => _t('settings');
  String get searchHint => _t('searchHint');
  String get recentSearches => _t('recentSearches');
  String get startSearching => _t('startSearching');
  String get appearance => _t('appearance');
  String get uiStyle => _t('uiStyle');
  String get material3 => _t('material3');
  String get fluent => _t('fluent');
  String get adaptive => _t('adaptive');
  String get themeMode => _t('themeMode');
  String get system => _t('system');
  String get light => _t('light');
  String get dark => _t('dark');
  String get accentColor => _t('accentColor');
  String get language => _t('language');
  String get chinese => _t('chinese');
  String get english => _t('english');
  String get aiFeatures => _t('aiFeatures');
  String get aiModel => _t('aiModel');
  String get notInstalled => _t('notInstalled');
  String get download => _t('download');
  String get dataManagement => _t('dataManagement');
  String get clearSearchHistory => _t('clearSearchHistory');
  String get clearAllFavorites => _t('clearAllFavorites');
  String get about => _t('about');
  String get version => _t('version');
  String get ecdictInfo => _t('ecdictInfo');
  String get completelyFree => _t('completelyFree');
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['en', 'zh'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  throw UnimplementedError('Must be initialized with SharedPreferences');
});

class SettingsState {
  final UIStyle uiStyle;
  final ThemeModeOption themeModeOption;
  final LanguageOption languageOption;
  final int currentIndex;
  final Color seedColor;

  SettingsState({
    required this.uiStyle,
    required this.themeModeOption,
    required this.languageOption,
    this.currentIndex = 0,
    this.seedColor = const Color(0xFFE8002D),
  });

  SettingsState copyWith({
    UIStyle? uiStyle,
    ThemeModeOption? themeModeOption,
    LanguageOption? languageOption,
    int? currentIndex,
    Color? seedColor,
  }) {
    return SettingsState(
      uiStyle: uiStyle ?? this.uiStyle,
      themeModeOption: themeModeOption ?? this.themeModeOption,
      languageOption: languageOption ?? this.languageOption,
      currentIndex: currentIndex ?? this.currentIndex,
      seedColor: seedColor ?? this.seedColor,
    );
  }
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  final SharedPreferences _prefs;

  SettingsNotifier(this._prefs)
      : super(SettingsState(
          uiStyle: UIStyle.values.byName(_prefs.getString(_kUIStyleKey) ?? 'fluent'),
          themeModeOption: ThemeModeOption.values.byName(_prefs.getString(_kThemeModeKey) ?? 'system'),
          languageOption: LanguageOption.values.byName(_prefs.getString(_kLanguageKey) ?? 'system'),
          currentIndex: _prefs.getInt(_kCurrentIndexKey) ?? 0,
          seedColor: Color(_prefs.getInt(_kSeedColorKey) ?? 0xFFE8002D),
        ));

  Future<void> setUIStyle(UIStyle style) async {
    state = state.copyWith(uiStyle: style);
    await _prefs.setString(_kUIStyleKey, style.name);
  }

  Future<void> setThemeMode(ThemeModeOption mode) async {
    state = state.copyWith(themeModeOption: mode);
    await _prefs.setString(_kThemeModeKey, mode.name);
  }

  Future<void> setLanguage(LanguageOption lang) async {
    state = state.copyWith(languageOption: lang);
    await _prefs.setString(_kLanguageKey, lang.name);
  }

  Future<void> setCurrentIndex(int index) async {
    state = state.copyWith(currentIndex: index);
    await _prefs.setInt(_kCurrentIndexKey, index);
  }

  Future<void> setSeedColor(Color color) async {
    state = state.copyWith(seedColor: color);
    await _prefs.setInt(_kSeedColorKey, color.value);
  }

  ThemeMode get effectiveThemeMode {
    return switch (state.themeModeOption) {
      ThemeModeOption.system => ThemeMode.system,
      ThemeModeOption.light => ThemeMode.light,
      ThemeModeOption.dark => ThemeMode.dark,
    };
  }

  Locale? get effectiveLocale {
    return switch (state.languageOption) {
      LanguageOption.system => null,
      LanguageOption.zh => const Locale('zh'),
      LanguageOption.en => const Locale('en'),
    };
  }

  bool get useMaterial3 {
    return switch (state.uiStyle) {
      UIStyle.material3 => true,
      UIStyle.fluent => false,
      UIStyle.adaptive => false,
    };
  }
}
