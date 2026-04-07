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
      'dictionarySettings': 'Dictionary Settings',
      'dictionaryManagement': 'Dictionary Management',
      'dictionaryReady': 'Dictionary Ready',
      'pleaseSelectDictionary': 'Please select dictionary file',
      'manage': 'Manage',
      'installed': 'Installed',
      'selectModel': 'Select Model',
      'downloadModel': 'Download Model',
      'downloading': 'Downloading',
      'downloadCompleted': 'Download Completed',
      'downloadFailed': 'Download Failed',
      'cancelDownload': 'Cancel Download',
      'retry': 'Retry',
      'clear': 'Clear',
      'reset': 'Reset',
      'selectModelFile': 'Select Model File',
      'modelReady': 'Model Ready',
      'pleaseSelectModel': 'Please select model file',
      'startDownload': 'Start Download',
      'downloadingInBackground': 'Downloading in background, you can continue using other features',
      'usageInstructions': 'Usage Instructions',
      'step1SelectModel': '1. Select the model type you want to use',
      'step2DownloadModel': '2. Click "Start Download" to get the model file, or "Select Model File" to choose an existing file',
      'step3SupportedFormats': '3. Supported formats: .gguf',
      'downloadRecommendations': 'Download Recommendations:',
      'qwen05bDesc': '- Qwen2.5-0.5B: Lightweight, suitable for resource-constrained devices',
      'qwen15bDesc': '- Qwen2.5-1.5B: Balanced, recommended for most users',
      'noModelWarning': 'If no model file is available, AI translation for long sentences will not work.',
      'selectDictionary': 'Select Dictionary',
      'downloadDictionary': 'Download Dictionary',
      'selectDictionaryFile': 'Select Dictionary File',
      'clearSettings': 'Clear Settings',
      'step1SelectDictionary': '1. Select the dictionary type you want to use',
      'step2DownloadDictionary': '2. Click "Start Download" to get the dictionary file, or "Select Dictionary File" to choose an existing file',
      'step3SupportedDictionaryFormats': '3. Supported formats: .db, .sqlite, .sqlite3, .zip',
      'dictionaryRecommendations': 'Download Recommendations:',
      'ecdictDesc': '- ECDict: Recommended, contains over 3 million entries',
      'wiktionaryDesc': '- Wiktionary: Free resource from Wiktionary',
      'noDictionaryWarning': 'If no dictionary file is available, word translation will show "Unable to translate", but AI translation for long sentences will still work.',
      'downloadStatus': 'Download Status',
      'fileSize': 'File Size',
      'dictionaryStatus': 'Dictionary Status',
      'modelStatus': 'Model Status',
      'cancel': 'Cancel',
      'ok': 'OK',
      'allModelsDownloaded': 'All models are downloaded!',
      'deleteModel': 'Delete Model?',
      'deleteModelConfirm': 'Are you sure you want to delete',
      'delete': 'Delete',
      'modelAlreadyInstalled': 'Model already installed',
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
      'dictionarySettings': '词典设置',
      'dictionaryManagement': '词典管理',
      'dictionaryReady': '词典已就绪',
      'pleaseSelectDictionary': '请选择词典文件',
      'manage': '管理',
      'installed': '已安装',
      'selectModel': '选择模型',
      'downloadModel': '下载模型',
      'downloading': '下载中',
      'downloadCompleted': '下载完成',
      'downloadFailed': '下载失败',
      'cancelDownload': '取消下载',
      'retry': '重试',
      'clear': '清除',
      'reset': '重置',
      'selectModelFile': '选择模型文件',
      'modelReady': '模型已就绪',
      'pleaseSelectModel': '请选择模型文件',
      'startDownload': '开始下载',
      'downloadingInBackground': '下载将在后台进行，您可以继续使用应用的其他功能',
      'usageInstructions': '使用说明',
      'step1SelectModel': '1. 选择您想要使用的模型类型',
      'step2DownloadModel': '2. 点击"开始下载"获取模型文件，或者"选择模型文件"选择已有的文件',
      'step3SupportedFormats': '3. 支持的格式：.gguf',
      'downloadRecommendations': '下载建议：',
      'qwen05bDesc': '- Qwen2.5-0.5B: 轻量型，适合资源受限设备',
      'qwen15bDesc': '- Qwen2.5-1.5B: 平衡型，推荐大多数用户使用',
      'noModelWarning': '如果没有模型文件，长句的 AI 翻译将无法使用。',
      'selectDictionary': '选择词典',
      'downloadDictionary': '下载词典',
      'selectDictionaryFile': '选择词典文件',
      'clearSettings': '清除设置',
      'step1SelectDictionary': '1. 选择您想要使用的词典类型',
      'step2DownloadDictionary': '2. 点击"开始下载"获取词典文件，或者"选择词典文件"选择已有的文件',
      'step3SupportedDictionaryFormats': '3. 支持的格式：.db, .sqlite, .sqlite3, .zip',
      'dictionaryRecommendations': '下载建议：',
      'ecdictDesc': '- ECDict: 推荐使用，包含超过 300 万词条',
      'wiktionaryDesc': '- Wiktionary: 来自维基词典的免费资源',
      'noDictionaryWarning': '如果没有词典文件，单词翻译会显示"无法翻译"，但长句仍可使用 AI 翻译。',
      'downloadStatus': '下载状态',
      'fileSize': '文件大小',
      'dictionaryStatus': '词典状态',
      'modelStatus': '模型状态',
      'cancel': '取消',
      'ok': '确定',
      'allModelsDownloaded': '所有模型都已下载！',
      'deleteModel': '删除模型？',
      'deleteModelConfirm': '确定要删除',
      'delete': '删除',
      'modelAlreadyInstalled': '模型已安装',
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
  
  String get dictionarySettings => _t('dictionarySettings');
  String get dictionaryManagement => _t('dictionaryManagement');
  String get dictionaryReady => _t('dictionaryReady');
  String get pleaseSelectDictionary => _t('pleaseSelectDictionary');
  String get manage => _t('manage');
  String get installed => _t('installed');
  String get selectModel => _t('selectModel');
  String get downloadModel => _t('downloadModel');
  String get downloading => _t('downloading');
  String get downloadCompleted => _t('downloadCompleted');
  String get downloadFailed => _t('downloadFailed');
  String get cancelDownload => _t('cancelDownload');
  String get retry => _t('retry');
  String get clear => _t('clear');
  String get reset => _t('reset');
  String get selectModelFile => _t('selectModelFile');
  String get modelReady => _t('modelReady');
  String get pleaseSelectModel => _t('pleaseSelectModel');
  String get startDownload => _t('startDownload');
  String get downloadingInBackground => _t('downloadingInBackground');
  String get usageInstructions => _t('usageInstructions');
  String get step1SelectModel => _t('step1SelectModel');
  String get step2DownloadModel => _t('step2DownloadModel');
  String get step3SupportedFormats => _t('step3SupportedFormats');
  String get downloadRecommendations => _t('downloadRecommendations');
  String get qwen05bDesc => _t('qwen05bDesc');
  String get qwen15bDesc => _t('qwen15bDesc');
  String get noModelWarning => _t('noModelWarning');
  String get selectDictionary => _t('selectDictionary');
  String get downloadDictionary => _t('downloadDictionary');
  String get selectDictionaryFile => _t('selectDictionaryFile');
  String get clearSettings => _t('clearSettings');
  String get step1SelectDictionary => _t('step1SelectDictionary');
  String get step2DownloadDictionary => _t('step2DownloadDictionary');
  String get step3SupportedDictionaryFormats => _t('step3SupportedDictionaryFormats');
  String get dictionaryRecommendations => _t('dictionaryRecommendations');
  String get ecdictDesc => _t('ecdictDesc');
  String get wiktionaryDesc => _t('wiktionaryDesc');
  String get noDictionaryWarning => _t('noDictionaryWarning');
  String get downloadStatus => _t('downloadStatus');
  String get fileSize => _t('fileSize');
  String get dictionaryStatus => _t('dictionaryStatus');
  String get modelStatus => _t('modelStatus');
  String get cancel => _t('cancel');
  String get ok => _t('ok');
  String get allModelsDownloaded => _t('allModelsDownloaded');
  String get deleteModel => _t('deleteModel');
  String get deleteModelConfirm => _t('deleteModelConfirm');
  String get delete => _t('delete');
  String get modelAlreadyInstalled => _t('modelAlreadyInstalled');
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
