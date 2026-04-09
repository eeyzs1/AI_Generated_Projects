import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:archive/archive_io.dart';
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
        return '\u82F1\u8BED \u2192 \u6C49\u8BED / English \u2192 Chinese';
      case LanguagePair.englishFrench:
        return '\u82F1\u8BED \u2192 \u6CD5\u8BED / English \u2192 French';
      case LanguagePair.englishGerman:
        return '\u82F1\u8BED \u2192 \u5FB7\u8BED / English \u2192 German';
      case LanguagePair.englishSpanish:
        return '\u82F1\u8BED \u2192 \u897F\u73ED\u7259\u8BED / English \u2192 Spanish';
      case LanguagePair.englishItalian:
        return '\u82F1\u8BED \u2192 \u610F\u5927\u5229\u8BED / English \u2192 Italian';
      case LanguagePair.englishPortuguese:
        return '\u82F1\u8BED \u2192 \u8461\u8404\u7259\u8BED / English \u2192 Portuguese';
      case LanguagePair.englishRussian:
        return '\u82F1\u8BED \u2192 \u4FC4\u8BED / English \u2192 Russian';
      case LanguagePair.englishArabic:
        return '\u82F1\u8BED \u2192 \u963F\u62C9\u4F2F\u8BED / English \u2192 Arabic';
      case LanguagePair.englishJapanese:
        return '\u82F1\u8BED \u2192 \u65E5\u8BED / English \u2192 Japanese';
      case LanguagePair.englishKorean:
        return '\u82F1\u8BED \u2192 \u97E9\u8BED / English \u2192 Korean';
      case LanguagePair.chineseEnglish:
        return '\u6C49\u8BED \u2192 \u82F1\u8BED / Chinese \u2192 English';
      case LanguagePair.frenchEnglish:
        return '\u6CD5\u8BED \u2192 \u82F1\u8BED / French \u2192 English';
      case LanguagePair.germanEnglish:
        return '\u5FB7\u8BED \u2192 \u82F1\u8BED / German \u2192 English';
      case LanguagePair.spanishEnglish:
        return '\u897F\u73ED\u7259\u8BED \u2192 \u82F1\u8BED / Spanish \u2192 English';
      case LanguagePair.italianEnglish:
        return '\u610F\u5927\u5229\u8BED \u2192 \u82F1\u8BED / Italian \u2192 English';
      case LanguagePair.portugueseEnglish:
        return '\u8461\u8404\u7259\u8BED \u2192 \u82F1\u8BED / Portuguese \u2192 English';
      case LanguagePair.russianEnglish:
        return '\u4FC4\u8BED \u2192 \u82F1\u8BED / Russian \u2192 English';
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
        return 'ECDict (\u82F1\u6C49\u8BCD\u5178 / English-Chinese)';
      case DictionaryType.stardictEnglishChinese:
        return 'StarDict (\u82F1\u2192\u4E2D / English\u2192Chinese)';
      case DictionaryType.stardictEnglishFrench:
        return 'StarDict (\u82F1\u2192\u6CD5 / English\u2192French)';
      case DictionaryType.stardictEnglishGerman:
        return 'StarDict (\u82F1\u2192\u5FB7 / English\u2192German)';
      case DictionaryType.stardictEnglishSpanish:
        return 'StarDict (\u82F1\u2192\u897F / English\u2192Spanish)';
      case DictionaryType.stardictEnglishItalian:
        return 'StarDict (\u82F1\u2192\u610F / English\u2192Italian)';
      case DictionaryType.stardictEnglishPortuguese:
        return 'StarDict (\u82F1\u2192\u8461 / English\u2192Portuguese)';
      case DictionaryType.stardictEnglishRussian:
        return 'StarDict (\u82F1\u2192\u4FC4 / English\u2192Russian)';
      case DictionaryType.stardictEnglishArabic:
        return 'StarDict (\u82F1\u2192\u963F / English\u2192Arabic)';
      case DictionaryType.stardictEnglishJapanese:
        return 'StarDict (\u82F1\u2192\u65E5 / English\u2192Japanese)';
      case DictionaryType.stardictEnglishKorean:
        return 'StarDict (\u82F1\u2192\u97E9 / English\u2192Korean)';
      case DictionaryType.stardictChineseEnglish:
        return 'StarDict (\u6C49\u2192\u82F1 / Chinese\u2192English)';
      case DictionaryType.stardictFrenchEnglish:
        return 'StarDict (\u6CD5\u2192\u82F1 / French\u2192English)';
      case DictionaryType.stardictGermanEnglish:
        return 'StarDict (\u5FB7\u2192\u82F1 / German\u2192English)';
      case DictionaryType.stardictSpanishEnglish:
        return 'StarDict (\u897F\u2192\u82F1 / Spanish\u2192English)';
      case DictionaryType.stardictItalianEnglish:
        return 'StarDict (\u610F\u2192\u82F1 / Italian\u2192English)';
      case DictionaryType.stardictPortugueseEnglish:
        return 'StarDict (\u8461\u2192\u82F1 / Portuguese\u2192English)';
      case DictionaryType.stardictRussianEnglish:
        return 'StarDict (\u4FC4\u2192\u82F1 / Russian\u2192English)';
    }
  }

  String get description {
    switch (this) {
      case DictionaryType.ecdict:
        return '\u5305\u542B\u8D85\u8FC7 300 \u4E07\u8BCD\u6761\u7684\u82F1\u6C49\u8BCD\u5178\uFF08SQLite\uFF09\nEnglish-Chinese dictionary with over 3 million entries (SQLite)';
      case DictionaryType.stardictEnglishChinese:
        return 'StarDict \u683C\u5F0F\u7684\u82F1\u6C49\u5B57\u5178\uFF08Wiktionary\uFF09\nEnglish-Chinese dictionary in StarDict format (Wiktionary)';
      case DictionaryType.stardictEnglishFrench:
        return 'StarDict \u683C\u5F0F\u7684\u82F1\u6CD5\u5B57\u5178\uFF08Wiktionary\uFF09\nEnglish-French dictionary in StarDict format (Wiktionary)';
      case DictionaryType.stardictEnglishGerman:
        return 'StarDict \u683C\u5F0F\u7684\u82F1\u5FB7\u5B57\u5178\uFF08Wiktionary\uFF09\nEnglish-German dictionary in StarDict format (Wiktionary)';
      case DictionaryType.stardictEnglishSpanish:
        return 'StarDict \u683C\u5F0F\u7684\u82F1\u897F\u5B57\u5178\uFF08Wiktionary\uFF09\nEnglish-Spanish dictionary in StarDict format (Wiktionary)';
      case DictionaryType.stardictEnglishItalian:
        return 'StarDict \u683C\u5F0F\u7684\u82F1\u610F\u5B57\u5178\uFF08Wiktionary\uFF09\nEnglish-Italian dictionary in StarDict format (Wiktionary)';
      case DictionaryType.stardictEnglishPortuguese:
        return 'StarDict \u683C\u5F0F\u7684\u82F1\u8461\u5B57\u5178\uFF08Wiktionary\uFF09\nEnglish-Portuguese dictionary in StarDict format (Wiktionary)';
      case DictionaryType.stardictEnglishRussian:
        return 'StarDict \u683C\u5F0F\u7684\u82F1\u4FC4\u5B57\u5178\uFF08Wiktionary\uFF09\nEnglish-Russian dictionary in StarDict format (Wiktionary)';
      case DictionaryType.stardictEnglishArabic:
        return 'StarDict \u683C\u5F0F\u7684\u82F1\u963F\u5B57\u5178\uFF08Wiktionary\uFF09\nEnglish-Arabic dictionary in StarDict format (Wiktionary)';
      case DictionaryType.stardictEnglishJapanese:
        return 'StarDict \u683C\u5F0F\u7684\u82F1\u65E5\u5B57\u5178\uFF08Wiktionary\uFF09\nEnglish-Japanese dictionary in StarDict format (Wiktionary)';
      case DictionaryType.stardictEnglishKorean:
        return 'StarDict \u683C\u5F0F\u7684\u82F1\u97E9\u5B57\u5178\uFF08Wiktionary\uFF09\nEnglish-Korean dictionary in StarDict format (Wiktionary)';
      case DictionaryType.stardictChineseEnglish:
        return 'StarDict \u683C\u5F0F\u7684\u6C49\u82F1\u5B57\u5178\uFF08Wiktionary\uFF09\nChinese-English dictionary in StarDict format (Wiktionary)';
      case DictionaryType.stardictFrenchEnglish:
        return 'StarDict \u683C\u5F0F\u7684\u6CD5\u82F1\u5B57\u5178\uFF08Wiktionary\uFF09\nFrench-English dictionary in StarDict format (Wiktionary)';
      case DictionaryType.stardictGermanEnglish:
        return 'StarDict \u683C\u5F0F\u7684\u5FB7\u82F1\u5B57\u5178\uFF08Wiktionary\uFF09\nGerman-English dictionary in StarDict format (Wiktionary)';
      case DictionaryType.stardictSpanishEnglish:
        return 'StarDict \u683C\u5F0F\u7684\u897F\u82F1\u5B57\u5178\uFF08Wiktionary\uFF09\nSpanish-English dictionary in StarDict format (Wiktionary)';
      case DictionaryType.stardictItalianEnglish:
        return 'StarDict \u683C\u5F0F\u7684\u610F\u82F1\u5B57\u5178\uFF08Wiktionary\uFF09\nItalian-English dictionary in StarDict format (Wiktionary)';
      case DictionaryType.stardictPortugueseEnglish:
        return 'StarDict \u683C\u5F0F\u7684\u8461\u82F1\u5B57\u5178\uFF08Wiktionary\uFF09\nPortuguese-English dictionary in StarDict format (Wiktionary)';
      case DictionaryType.stardictRussianEnglish:
        return 'StarDict \u683C\u5F0F\u7684\u4FC4\u82F1\u5B57\u5178\uFF08Wiktionary\uFF09\nRussian-English dictionary in StarDict format (Wiktionary)';
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
        return '\u7EA6210MB / ~210MB';
      case DictionaryType.stardictEnglishChinese:
        return '\u7EA670MB / ~70MB';
      case DictionaryType.stardictEnglishFrench:
        return '\u7EA615MB / ~15MB';
      case DictionaryType.stardictEnglishGerman:
        return '\u7EA610MB / ~10MB';
      case DictionaryType.stardictEnglishSpanish:
        return '\u7EA615MB / ~15MB';
      case DictionaryType.stardictEnglishItalian:
        return '\u7EA610MB / ~10MB';
      case DictionaryType.stardictEnglishPortuguese:
        return '\u7EA68MB / ~8MB';
      case DictionaryType.stardictEnglishRussian:
        return '\u7EA612MB / ~12MB';
      case DictionaryType.stardictEnglishArabic:
        return '\u7EA65MB / ~5MB';
      case DictionaryType.stardictEnglishJapanese:
        return '\u7EA68MB / ~8MB';
      case DictionaryType.stardictEnglishKorean:
        return '\u7EA63MB / ~3MB';
      case DictionaryType.stardictChineseEnglish:
        return '\u7EA612MB / ~12MB';
      case DictionaryType.stardictFrenchEnglish:
        return '\u7EA615MB / ~15MB';
      case DictionaryType.stardictGermanEnglish:
        return '\u7EA610MB / ~10MB';
      case DictionaryType.stardictSpanishEnglish:
        return '\u7EA615MB / ~15MB';
      case DictionaryType.stardictItalianEnglish:
        return '\u7EA610MB / ~10MB';
      case DictionaryType.stardictPortugueseEnglish:
        return '\u7EA68MB / ~8MB';
      case DictionaryType.stardictRussianEnglish:
        return '\u7EA612MB / ~12MB';
    }
  }

  int get approximateSizeBytes {
    switch (this) {
      case DictionaryType.ecdict:
        return 210 * 1024 * 1024;
      case DictionaryType.stardictEnglishChinese:
        return 70 * 1024 * 1024;
      case DictionaryType.stardictEnglishFrench:
        return 15 * 1024 * 1024;
      case DictionaryType.stardictEnglishGerman:
        return 10 * 1024 * 1024;
      case DictionaryType.stardictEnglishSpanish:
        return 15 * 1024 * 1024;
      case DictionaryType.stardictEnglishItalian:
        return 10 * 1024 * 1024;
      case DictionaryType.stardictEnglishPortuguese:
        return 8 * 1024 * 1024;
      case DictionaryType.stardictEnglishRussian:
        return 12 * 1024 * 1024;
      case DictionaryType.stardictEnglishArabic:
        return 5 * 1024 * 1024;
      case DictionaryType.stardictEnglishJapanese:
        return 8 * 1024 * 1024;
      case DictionaryType.stardictEnglishKorean:
        return 3 * 1024 * 1024;
      case DictionaryType.stardictChineseEnglish:
        return 12 * 1024 * 1024;
      case DictionaryType.stardictFrenchEnglish:
        return 15 * 1024 * 1024;
      case DictionaryType.stardictGermanEnglish:
        return 10 * 1024 * 1024;
      case DictionaryType.stardictSpanishEnglish:
        return 15 * 1024 * 1024;
      case DictionaryType.stardictItalianEnglish:
        return 10 * 1024 * 1024;
      case DictionaryType.stardictPortugueseEnglish:
        return 8 * 1024 * 1024;
      case DictionaryType.stardictRussianEnglish:
        return 12 * 1024 * 1024;
    }
  }

  String? get downloadUrl {
    switch (this) {
      case DictionaryType.ecdict:
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
        downloadError: '\u8BE5\u8BCD\u5178\u6682\u4E0D\u652F\u6301\u76F4\u63A5\u4E0B\u8F7D',
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

      if (File(tempPath).existsSync()) {
        String finalPath;

        if (state.type.isStarDictFormat) {
          final archivePath = '$savePath.tar.zst';
          await File(tempPath).rename(archivePath);

          final extractDir = path.join(path.dirname(savePath), state.type.fileName);
          final extractDirObj = Directory(extractDir);
          if (!extractDirObj.existsSync()) {
            await extractDirObj.create(recursive: true);
          }

          final starDictDataSource = ref.read(starDictDataSourceProvider);
          final ifoPath = await starDictDataSource.extractDictionary(archivePath, extractDir);

          if (ifoPath != null) {
            finalPath = ifoPath;
            await File(archivePath).delete();
          } else {
            throw Exception('\u89E3\u538B StarDict \u8BCD\u5178\u5931\u8D25');
          }
        }
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
            throw Exception('ZIP \u6587\u4EF6\u4E2D\u672A\u627E\u5230 .db \u6570\u636E\u5E93\u6587\u4EF6');
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
          downloadError: '\u4E0B\u8F7D\u5DF2\u53D6\u6D88',
        );
      } else {
        state = state.copyWith(
          downloadStatus: DownloadStatus.failed,
          downloadError: '\u4E0B\u8F7D\u5931\u8D25: ${e.toString()}',
        );
      }

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
