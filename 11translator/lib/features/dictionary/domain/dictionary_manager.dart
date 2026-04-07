import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:rfdictionary/features/dictionary/data/datasources/stardict_datasource.dart';
import 'package:rfdictionary/core/di/providers.dart';

part 'dictionary_manager.g.dart';

enum DictionaryType {
  ecdict,
  stardictEnglishChinese,
  stardictEnglishFrench,
  stardictEnglishGerman,
  stardictEnglishSpanish,
  stardictEnglishItalian,
  stardictEnglishPortuguese,
  stardictEnglishRussian,
  stardictEnglishArabic,
  stardictEnglishJapanese,
  stardictEnglishKorean,
  stardictChineseEnglish,
  stardictFrenchEnglish,
  stardictGermanEnglish,
  stardictSpanishEnglish,
  stardictItalianEnglish,
  stardictPortugueseEnglish,
  stardictRussianEnglish,
}

enum DownloadStatus {
  idle,
  downloading,
  completed,
  failed,
}

enum LanguagePair {
  englishChinese,
  englishFrench,
  englishGerman,
  englishSpanish,
  englishItalian,
  englishPortuguese,
  englishRussian,
  englishArabic,
  englishJapanese,
  englishKorean,
  chineseEnglish,
  frenchEnglish,
  germanEnglish,
  spanishEnglish,
  italianEnglish,
  portugueseEnglish,
  russianEnglish,
}

extension LanguagePairExtension on LanguagePair {
  String get displayName {
    switch (this) {
      case LanguagePair.englishChinese:
        return '英语 → 汉语 / English → Chinese';
      case LanguagePair.englishFrench:
        return '英语 → 法语 / English → French';
      case LanguagePair.englishGerman:
        return '英语 → 德语 / English → German';
      case LanguagePair.englishSpanish:
        return '英语 → 西班牙语 / English → Spanish';
      case LanguagePair.englishItalian:
        return '英语 → 意大利语 / English → Italian';
      case LanguagePair.englishPortuguese:
        return '英语 → 葡萄牙语 / English → Portuguese';
      case LanguagePair.englishRussian:
        return '英语 → 俄语 / English → Russian';
      case LanguagePair.englishArabic:
        return '英语 → 阿拉伯语 / English → Arabic';
      case LanguagePair.englishJapanese:
        return '英语 → 日语 / English → Japanese';
      case LanguagePair.englishKorean:
        return '英语 → 韩语 / English → Korean';
      case LanguagePair.chineseEnglish:
        return '汉语 → 英语 / Chinese → English';
      case LanguagePair.frenchEnglish:
        return '法语 → 英语 / French → English';
      case LanguagePair.germanEnglish:
        return '德语 → 英语 / German → English';
      case LanguagePair.spanishEnglish:
        return '西班牙语 → 英语 / Spanish → English';
      case LanguagePair.italianEnglish:
        return '意大利语 → 英语 / Italian → English';
      case LanguagePair.portugueseEnglish:
        return '葡萄牙语 → 英语 / Portuguese → English';
      case LanguagePair.russianEnglish:
        return '俄语 → 英语 / Russian → English';
    }
  }
}

class DictionaryState {
  final DictionaryType type;
  final Set<DictionaryType> selectedDictionaries;
  final DownloadStatus downloadStatus;
  final double downloadProgress;
  final int downloadedBytes;
  final int totalBytes;
  final String? downloadError;

  DictionaryState({
    required this.type,
    this.selectedDictionaries = const {},
    this.downloadStatus = DownloadStatus.idle,
    this.downloadProgress = 0.0,
    this.downloadedBytes = 0,
    this.totalBytes = 0,
    this.downloadError,
  });

  DictionaryState copyWith({
    DictionaryType? type,
    Set<DictionaryType>? selectedDictionaries,
    DownloadStatus? downloadStatus,
    double? downloadProgress,
    int? downloadedBytes,
    int? totalBytes,
    String? downloadError,
  }) {
    return DictionaryState(
      type: type ?? this.type,
      selectedDictionaries: selectedDictionaries ?? this.selectedDictionaries,
      downloadStatus: downloadStatus ?? this.downloadStatus,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      downloadError: downloadError ?? this.downloadError,
    );
  }
}

extension DictionaryTypeExtension on DictionaryType {
  String get displayName {
    switch (this) {
      case DictionaryType.ecdict:
        return 'ECDict (英汉词典 / English-Chinese)';
      case DictionaryType.stardictEnglishChinese:
        return 'StarDict (英→汉 / English→Chinese)';
      case DictionaryType.stardictEnglishFrench:
        return 'StarDict (英→法 / English→French)';
      case DictionaryType.stardictEnglishGerman:
        return 'StarDict (英→德 / English→German)';
      case DictionaryType.stardictEnglishSpanish:
        return 'StarDict (英→西 / English→Spanish)';
      case DictionaryType.stardictEnglishItalian:
        return 'StarDict (英→意 / English→Italian)';
      case DictionaryType.stardictEnglishPortuguese:
        return 'StarDict (英→葡 / English→Portuguese)';
      case DictionaryType.stardictEnglishRussian:
        return 'StarDict (英→俄 / English→Russian)';
      case DictionaryType.stardictEnglishArabic:
        return 'StarDict (英→阿 / English→Arabic)';
      case DictionaryType.stardictEnglishJapanese:
        return 'StarDict (英→日 / English→Japanese)';
      case DictionaryType.stardictEnglishKorean:
        return 'StarDict (英→韩 / English→Korean)';
      case DictionaryType.stardictChineseEnglish:
        return 'StarDict (汉→英 / Chinese→English)';
      case DictionaryType.stardictFrenchEnglish:
        return 'StarDict (法→英 / French→English)';
      case DictionaryType.stardictGermanEnglish:
        return 'StarDict (德→英 / German→English)';
      case DictionaryType.stardictSpanishEnglish:
        return 'StarDict (西→英 / Spanish→English)';
      case DictionaryType.stardictItalianEnglish:
        return 'StarDict (意→英 / Italian→English)';
      case DictionaryType.stardictPortugueseEnglish:
        return 'StarDict (葡→英 / Portuguese→English)';
      case DictionaryType.stardictRussianEnglish:
        return 'StarDict (俄→英 / Russian→English)';
    }
  }

  String get description {
    switch (this) {
      case DictionaryType.ecdict:
        return '包含超过 300 万词条的英汉词典（SQLite）\nEnglish-Chinese dictionary with over 3 million entries (SQLite)';
      case DictionaryType.stardictEnglishChinese:
        return 'StarDict 格式的英汉字典（Wiktionary）\nEnglish-Chinese dictionary in StarDict format (Wiktionary)';
      case DictionaryType.stardictEnglishFrench:
        return 'StarDict 格式的英法字典（Wiktionary）\nEnglish-French dictionary in StarDict format (Wiktionary)';
      case DictionaryType.stardictEnglishGerman:
        return 'StarDict 格式的英德字典（Wiktionary）\nEnglish-German dictionary in StarDict format (Wiktionary)';
      case DictionaryType.stardictEnglishSpanish:
        return 'StarDict 格式的英西字典（Wiktionary）\nEnglish-Spanish dictionary in StarDict format (Wiktionary)';
      case DictionaryType.stardictEnglishItalian:
        return 'StarDict 格式的英意字典（Wiktionary）\nEnglish-Italian dictionary in StarDict format (Wiktionary)';
      case DictionaryType.stardictEnglishPortuguese:
        return 'StarDict 格式的英葡字典（Wiktionary）\nEnglish-Portuguese dictionary in StarDict format (Wiktionary)';
      case DictionaryType.stardictEnglishRussian:
        return 'StarDict 格式的英俄字典（Wiktionary）\nEnglish-Russian dictionary in StarDict format (Wiktionary)';
      case DictionaryType.stardictEnglishArabic:
        return 'StarDict 格式的英阿字典（Wiktionary）\nEnglish-Arabic dictionary in StarDict format (Wiktionary)';
      case DictionaryType.stardictEnglishJapanese:
        return 'StarDict 格式的英日字典（Wiktionary）\nEnglish-Japanese dictionary in StarDict format (Wiktionary)';
      case DictionaryType.stardictEnglishKorean:
        return 'StarDict 格式的英韩字典（Wiktionary）\nEnglish-Korean dictionary in StarDict format (Wiktionary)';
      case DictionaryType.stardictChineseEnglish:
        return 'StarDict 格式的汉英字典（Wiktionary）\nChinese-English dictionary in StarDict format (Wiktionary)';
      case DictionaryType.stardictFrenchEnglish:
        return 'StarDict 格式的法英字典（Wiktionary）\nFrench-English dictionary in StarDict format (Wiktionary)';
      case DictionaryType.stardictGermanEnglish:
        return 'StarDict 格式的德英字典（Wiktionary）\nGerman-English dictionary in StarDict format (Wiktionary)';
      case DictionaryType.stardictSpanishEnglish:
        return 'StarDict 格式的西英字典（Wiktionary）\nSpanish-English dictionary in StarDict format (Wiktionary)';
      case DictionaryType.stardictItalianEnglish:
        return 'StarDict 格式的意英字典（Wiktionary）\nItalian-English dictionary in StarDict format (Wiktionary)';
      case DictionaryType.stardictPortugueseEnglish:
        return 'StarDict 格式的葡英字典（Wiktionary）\nPortuguese-English dictionary in StarDict format (Wiktionary)';
      case DictionaryType.stardictRussianEnglish:
        return 'StarDict 格式的俄英字典（Wiktionary）\nRussian-English dictionary in StarDict format (Wiktionary)';
    }
  }

  String get fileName {
    switch (this) {
      case DictionaryType.ecdict:
        return 'stardict.db';
      case DictionaryType.stardictEnglishChinese:
        return 'stardict_english_chinese';
      case DictionaryType.stardictEnglishFrench:
        return 'stardict_english_french';
      case DictionaryType.stardictEnglishGerman:
        return 'stardict_english_german';
      case DictionaryType.stardictEnglishSpanish:
        return 'stardict_english_spanish';
      case DictionaryType.stardictEnglishItalian:
        return 'stardict_english_italian';
      case DictionaryType.stardictEnglishPortuguese:
        return 'stardict_english_portuguese';
      case DictionaryType.stardictEnglishRussian:
        return 'stardict_english_russian';
      case DictionaryType.stardictEnglishArabic:
        return 'stardict_english_arabic';
      case DictionaryType.stardictEnglishJapanese:
        return 'stardict_english_japanese';
      case DictionaryType.stardictEnglishKorean:
        return 'stardict_english_korean';
      case DictionaryType.stardictChineseEnglish:
        return 'stardict_chinese_english';
      case DictionaryType.stardictFrenchEnglish:
        return 'stardict_french_english';
      case DictionaryType.stardictGermanEnglish:
        return 'stardict_german_english';
      case DictionaryType.stardictSpanishEnglish:
        return 'stardict_spanish_english';
      case DictionaryType.stardictItalianEnglish:
        return 'stardict_italian_english';
      case DictionaryType.stardictPortugueseEnglish:
        return 'stardict_portuguese_english';
      case DictionaryType.stardictRussianEnglish:
        return 'stardict_russian_english';
    }
  }

  String get sizeInfo {
    switch (this) {
      case DictionaryType.ecdict:
        return '约 210MB / ~210MB';
      case DictionaryType.stardictEnglishChinese:
        return '约 70MB / ~70MB';
      case DictionaryType.stardictEnglishFrench:
        return '约 15MB / ~15MB';
      case DictionaryType.stardictEnglishGerman:
        return '约 10MB / ~10MB';
      case DictionaryType.stardictEnglishSpanish:
        return '约 15MB / ~15MB';
      case DictionaryType.stardictEnglishItalian:
        return '约 10MB / ~10MB';
      case DictionaryType.stardictEnglishPortuguese:
        return '约 8MB / ~8MB';
      case DictionaryType.stardictEnglishRussian:
        return '约 12MB / ~12MB';
      case DictionaryType.stardictEnglishArabic:
        return '约 5MB / ~5MB';
      case DictionaryType.stardictEnglishJapanese:
        return '约 8MB / ~8MB';
      case DictionaryType.stardictEnglishKorean:
        return '约 3MB / ~3MB';
      case DictionaryType.stardictChineseEnglish:
        return '约 12MB / ~12MB';
      case DictionaryType.stardictFrenchEnglish:
        return '约 15MB / ~15MB';
      case DictionaryType.stardictGermanEnglish:
        return '约 10MB / ~10MB';
      case DictionaryType.stardictSpanishEnglish:
        return '约 15MB / ~15MB';
      case DictionaryType.stardictItalianEnglish:
        return '约 10MB / ~10MB';
      case DictionaryType.stardictPortugueseEnglish:
        return '约 8MB / ~8MB';
      case DictionaryType.stardictRussianEnglish:
        return '约 12MB / ~12MB';
    }
  }

  int get approximateSizeBytes {
    switch (this) {
      case DictionaryType.ecdict:
        return 210 * 1024 * 1024; // 210MB (实际ZIP文件大小)
      case DictionaryType.stardictEnglishChinese:
        return 70 * 1024 * 1024; // 70MB
      case DictionaryType.stardictEnglishFrench:
        return 15 * 1024 * 1024; // 15MB
      case DictionaryType.stardictEnglishGerman:
        return 10 * 1024 * 1024; // 10MB
      case DictionaryType.stardictEnglishSpanish:
        return 15 * 1024 * 1024; // 15MB
      case DictionaryType.stardictEnglishItalian:
        return 10 * 1024 * 1024; // 10MB
      case DictionaryType.stardictEnglishPortuguese:
        return 8 * 1024 * 1024; // 8MB
      case DictionaryType.stardictEnglishRussian:
        return 12 * 1024 * 1024; // 12MB
      case DictionaryType.stardictEnglishArabic:
        return 5 * 1024 * 1024; // 5MB
      case DictionaryType.stardictEnglishJapanese:
        return 8 * 1024 * 1024; // 8MB
      case DictionaryType.stardictEnglishKorean:
        return 3 * 1024 * 1024; // 3MB
      case DictionaryType.stardictChineseEnglish:
        return 12 * 1024 * 1024; // 12MB
      case DictionaryType.stardictFrenchEnglish:
        return 15 * 1024 * 1024; // 15MB
      case DictionaryType.stardictGermanEnglish:
        return 10 * 1024 * 1024; // 10MB
      case DictionaryType.stardictSpanishEnglish:
        return 15 * 1024 * 1024; // 15MB
      case DictionaryType.stardictItalianEnglish:
        return 10 * 1024 * 1024; // 10MB
      case DictionaryType.stardictPortugueseEnglish:
        return 8 * 1024 * 1024; // 8MB
      case DictionaryType.stardictRussianEnglish:
        return 12 * 1024 * 1024; // 12MB
    }
  }

  String? get downloadUrl {
    switch (this) {
      case DictionaryType.ecdict:
        // ECDict 的 GitHub release 下载地址
        return 'https://github.com/skywind3000/ECDICT/releases/download/1.0.28/ecdict-sqlite-28.zip';
      case DictionaryType.stardictEnglishChinese:
        return 'https://github.com/xxyzz/wiktionary_stardict/releases/download/20260324/English-Chinese.tar.zst';
      case DictionaryType.stardictEnglishFrench:
        return 'https://github.com/xxyzz/wiktionary_stardict/releases/download/20260324/English-French.tar.zst';
      case DictionaryType.stardictEnglishGerman:
        return 'https://github.com/xxyzz/wiktionary_stardict/releases/download/20260324/English-German.tar.zst';
      case DictionaryType.stardictEnglishSpanish:
        return 'https://github.com/xxyzz/wiktionary_stardict/releases/download/20260324/English-Spanish.tar.zst';
      case DictionaryType.stardictEnglishItalian:
        return 'https://github.com/xxyzz/wiktionary_stardict/releases/download/20260324/English-Italian.tar.zst';
      case DictionaryType.stardictEnglishPortuguese:
        return 'https://github.com/xxyzz/wiktionary_stardict/releases/download/20260324/English-Portuguese.tar.zst';
      case DictionaryType.stardictEnglishRussian:
        return 'https://github.com/xxyzz/wiktionary_stardict/releases/download/20260324/English-Russian.tar.zst';
      case DictionaryType.stardictEnglishArabic:
        return 'https://github.com/xxyzz/wiktionary_stardict/releases/download/20260324/English-Arabic.tar.zst';
      case DictionaryType.stardictEnglishJapanese:
        return 'https://github.com/xxyzz/wiktionary_stardict/releases/download/20260324/English-Japanese.tar.zst';
      case DictionaryType.stardictEnglishKorean:
        return 'https://github.com/xxyzz/wiktionary_stardict/releases/download/20260324/English-Korean.tar.zst';
      case DictionaryType.stardictChineseEnglish:
        return 'https://github.com/xxyzz/wiktionary_stardict/releases/download/20260324/Chinese-English.tar.zst';
      case DictionaryType.stardictFrenchEnglish:
        return 'https://github.com/xxyzz/wiktionary_stardict/releases/download/20260324/French-English.tar.zst';
      case DictionaryType.stardictGermanEnglish:
        return 'https://github.com/xxyzz/wiktionary_stardict/releases/download/20260324/German-English.tar.zst';
      case DictionaryType.stardictSpanishEnglish:
        return 'https://github.com/xxyzz/wiktionary_stardict/releases/download/20260324/Spanish-English.tar.zst';
      case DictionaryType.stardictItalianEnglish:
        return 'https://github.com/xxyzz/wiktionary_stardict/releases/download/20260324/Italian-English.tar.zst';
      case DictionaryType.stardictPortugueseEnglish:
        return 'https://github.com/xxyzz/wiktionary_stardict/releases/download/20260324/Portuguese-English.tar.zst';
      case DictionaryType.stardictRussianEnglish:
        return 'https://github.com/xxyzz/wiktionary_stardict/releases/download/20260324/Russian-English.tar.zst';
    }
  }

  bool get isStarDictFormat {
    switch (this) {
      case DictionaryType.ecdict:
        return false;
      case DictionaryType.stardictEnglishChinese:
      case DictionaryType.stardictEnglishFrench:
      case DictionaryType.stardictEnglishGerman:
      case DictionaryType.stardictEnglishSpanish:
      case DictionaryType.stardictEnglishItalian:
      case DictionaryType.stardictEnglishPortuguese:
      case DictionaryType.stardictEnglishRussian:
      case DictionaryType.stardictEnglishArabic:
      case DictionaryType.stardictEnglishJapanese:
      case DictionaryType.stardictEnglishKorean:
      case DictionaryType.stardictChineseEnglish:
      case DictionaryType.stardictFrenchEnglish:
      case DictionaryType.stardictGermanEnglish:
      case DictionaryType.stardictSpanishEnglish:
      case DictionaryType.stardictItalianEnglish:
      case DictionaryType.stardictPortugueseEnglish:
      case DictionaryType.stardictRussianEnglish:
        return true;
    }
  }

  LanguagePair? get languagePair {
    switch (this) {
      case DictionaryType.ecdict:
      case DictionaryType.stardictEnglishChinese:
        return LanguagePair.englishChinese;
      case DictionaryType.stardictEnglishFrench:
        return LanguagePair.englishFrench;
      case DictionaryType.stardictEnglishGerman:
        return LanguagePair.englishGerman;
      case DictionaryType.stardictEnglishSpanish:
        return LanguagePair.englishSpanish;
      case DictionaryType.stardictEnglishItalian:
        return LanguagePair.englishItalian;
      case DictionaryType.stardictEnglishPortuguese:
        return LanguagePair.englishPortuguese;
      case DictionaryType.stardictEnglishRussian:
        return LanguagePair.englishRussian;
      case DictionaryType.stardictEnglishArabic:
        return LanguagePair.englishArabic;
      case DictionaryType.stardictEnglishJapanese:
        return LanguagePair.englishJapanese;
      case DictionaryType.stardictEnglishKorean:
        return LanguagePair.englishKorean;
      case DictionaryType.stardictChineseEnglish:
        return LanguagePair.chineseEnglish;
      case DictionaryType.stardictFrenchEnglish:
        return LanguagePair.frenchEnglish;
      case DictionaryType.stardictGermanEnglish:
        return LanguagePair.germanEnglish;
      case DictionaryType.stardictSpanishEnglish:
        return LanguagePair.spanishEnglish;
      case DictionaryType.stardictItalianEnglish:
        return LanguagePair.italianEnglish;
      case DictionaryType.stardictPortugueseEnglish:
        return LanguagePair.portugueseEnglish;
      case DictionaryType.stardictRussianEnglish:
        return LanguagePair.russianEnglish;
    }
  }
}

@Riverpod(keepAlive: true)
class DictionaryManager extends _$DictionaryManager {
  static const String _kDictionaryPathKey = 'dictionary_path';
  static const String _kDictionaryTypeKey = 'dictionary_type';
  static const String _kSelectedDictionariesKey = 'selected_dictionaries';

  CancelToken? _cancelToken;

  @override
  DictionaryState build() {
    return DictionaryState(type: DictionaryType.ecdict);
  }

  Future<void> loadSavedDictionary() async {
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getInt(_kDictionaryTypeKey);
    if (index != null && index >= 0 && index < DictionaryType.values.length) {
      state = state.copyWith(type: DictionaryType.values[index]);
    }
    
    final selectedIndices = prefs.getStringList(_kSelectedDictionariesKey);
    if (selectedIndices != null) {
      final selected = selectedIndices
          .map((idx) => int.tryParse(idx))
          .whereType<int>()
          .where((idx) => idx >= 0 && idx < DictionaryType.values.length)
          .map((idx) => DictionaryType.values[idx])
          .toSet();
      state = state.copyWith(selectedDictionaries: selected);
    }
  }

  Future<void> selectDictionary(DictionaryType type) async {
    state = state.copyWith(type: type);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kDictionaryTypeKey, type.index);
  }

  Future<void> toggleDictionarySelection(DictionaryType type) async {
    final current = Set<DictionaryType>.from(state.selectedDictionaries);
    if (current.contains(type)) {
      current.remove(type);
    } else {
      current.add(type);
    }
    state = state.copyWith(selectedDictionaries: current);
    
    final prefs = await SharedPreferences.getInstance();
    final indices = current.map((t) => t.index.toString()).toList();
    await prefs.setStringList(_kSelectedDictionariesKey, indices);
  }

  Set<LanguagePair> getAvailableLanguagePairs() {
    final pairs = <LanguagePair>{};
    for (final dict in state.selectedDictionaries) {
      final pair = dict.languagePair;
      if (pair != null) {
        pairs.add(pair);
      }
    }
    return pairs;
  }

  Future<void> setDictionaryPath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kDictionaryPathKey, path);
  }

  Future<String?> getDictionaryPath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kDictionaryPathKey);
  }

  Future<bool> isDictionaryAvailable() async {
    final savedPath = await getDictionaryPath();
    if (savedPath != null && File(savedPath).existsSync()) {
      return true;
    }
    
    // 检查默认位置
    final dir = await getApplicationDocumentsDirectory();
    final defaultPath = path.join(dir.path, state.type.fileName);
    if (File(defaultPath).existsSync()) {
      return true;
    }
    
    return false;
  }

  Future<String?> getValidDictionaryPath() async {
    final savedPath = await getDictionaryPath();
    if (savedPath != null && File(savedPath).existsSync()) {
      return savedPath;
    }
    
    // 检查默认位置
    final dir = await getApplicationDocumentsDirectory();
    final defaultPath = path.join(dir.path, state.type.fileName);
    if (File(defaultPath).existsSync()) {
      return defaultPath;
    }
    
    return null;
  }

  Future<void> clearDictionaryPath() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kDictionaryPathKey);
  }

  Future<void> startDownload({String? customDirectory}) async {
    if (state.downloadStatus == DownloadStatus.downloading) {
      return;
    }

    final url = state.type.downloadUrl;
    if (url == null) {
      state = state.copyWith(
        downloadStatus: DownloadStatus.failed,
        downloadError: '该词典暂不支持直接下载',
      );
      return;
    }

    state = state.copyWith(
      downloadStatus: DownloadStatus.downloading,
      downloadProgress: 0.0,
      downloadedBytes: 0,
      totalBytes: state.type.approximateSizeBytes,
      downloadError: null,
    );
    _cancelToken = CancelToken();

    try {
      String savePath;
      
      if (customDirectory != null && Directory(customDirectory).existsSync()) {
        savePath = path.join(customDirectory, state.type.fileName);
      } else {
        final dir = await getApplicationDocumentsDirectory();
        savePath = path.join(dir.path, state.type.fileName);
      }
      
      final tempPath = '$savePath.tmp';

      // 如果临时文件存在，删除它
      if (File(tempPath).existsSync()) {
        await File(tempPath).delete();
      }

      final dio = Dio();
      
      await dio.download(
        url,
        tempPath,
        cancelToken: _cancelToken,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            state = state.copyWith(
              downloadProgress: received / total,
              downloadedBytes: received,
              totalBytes: total,
            );
          }
        },
      );

      // 下载完成
      if (File(tempPath).existsSync()) {
        String finalPath;
        
        // StarDict 格式：下载后解压
        if (state.type.isStarDictFormat) {
          final archivePath = savePath + '.tar.zst';
          await File(tempPath).rename(archivePath);
          
          // 创建解压目录
          final extractDir = path.join(path.dirname(savePath), state.type.fileName);
          final extractDirObj = Directory(extractDir);
          if (!await extractDirObj.existsSync()) {
            await extractDirObj.create(recursive: true);
          }
          
          // 解压词典
          final starDictDataSource = ref.read(starDictDataSourceProvider);
          final ifoPath = await starDictDataSource.extractDictionary(archivePath, extractDir);
          
          if (ifoPath != null) {
            finalPath = ifoPath;
            // 清理归档文件
            await File(archivePath).delete();
          } else {
            throw Exception('解压 StarDict 词典失败');
          }
        }
        // ZIP 文件：解压
        else if (url.toLowerCase().endsWith('.zip') || tempPath.toLowerCase().endsWith('.zip')) {
          final zipPath = tempPath;
          final extractDir = Directory(path.dirname(savePath));
          final bytes = await File(zipPath).readAsBytes();
          final archive = ZipDecoder().decodeBytes(bytes);
          
          String? dbFilePath;
          for (final file in archive) {
            if (file.isFile && file.name.toLowerCase().endsWith('.db')) {
              dbFilePath = path.join(extractDir.path, path.basename(file.name));
              final outputStream = OutputFileStream(dbFilePath);
              outputStream.writeBytes(file.content as List<int>);
              await outputStream.close();
              break;
            }
          }
          
          await File(zipPath).delete();
          
          if (dbFilePath != null) {
            finalPath = dbFilePath;
          } else {
            throw Exception('ZIP 文件中未找到 .db 数据库文件');
          }
        } else {
          await File(tempPath).rename(savePath);
          finalPath = savePath;
        }
        
        await setDictionaryPath(finalPath);
        state = state.copyWith(
          downloadStatus: DownloadStatus.completed,
          downloadProgress: 1.0,
        );
      }
    } catch (e) {
      if (_cancelToken?.isCancelled ?? false) {
        state = state.copyWith(
          downloadStatus: DownloadStatus.idle,
          downloadError: '下载已取消',
        );
      } else {
        state = state.copyWith(
          downloadStatus: DownloadStatus.failed,
          downloadError: '下载失败: ${e.toString()}',
        );
      }
      
      // 清理临时文件
      try {
        String tempPath;
        if (customDirectory != null) {
          tempPath = path.join(customDirectory, '${state.type.fileName}.tmp');
        } else {
          final dir = await getApplicationDocumentsDirectory();
          tempPath = path.join(dir.path, '${state.type.fileName}.tmp');
        }
        if (File(tempPath).existsSync()) {
          await File(tempPath).delete();
        }
      } catch (_) {}
    }
  }

  void cancelDownload() {
    _cancelToken?.cancel();
  }

  void resetDownload() {
    state = state.copyWith(
      downloadStatus: DownloadStatus.idle,
      downloadProgress: 0.0,
      downloadedBytes: 0,
      totalBytes: 0,
      downloadError: null,
    );
  }
}
