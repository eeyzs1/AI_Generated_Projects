import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rfdictionary/core/di/providers.dart';
import 'package:rfdictionary/features/dictionary/data/datasources/dictionary_local_datasource.dart';
import 'package:rfdictionary/features/dictionary/data/datasources/stardict_datasource.dart';
import 'package:rfdictionary/features/dictionary/domain/entities/word_entry.dart';
import 'package:rfdictionary/features/dictionary/domain/dictionary_manager.dart';
import 'package:rfdictionary/features/llm/data/datasources/python_llm_datasource.dart';
import 'package:rfdictionary/features/llm/domain/llm_service.dart';
import 'package:rfdictionary/features/llm/domain/model_manager.dart';
import 'package:rfdictionary/features/translation/data/repositories/translation_history_repository.dart';
import 'package:rfdictionary/features/translation/domain/entities/language.dart';
import 'package:rfdictionary/features/translation/domain/entities/translation_result.dart';
import 'package:rfdictionary/features/translation/domain/entities/translation_source.dart';
import 'package:rfdictionary/features/translation/domain/translation_history_provider.dart';

class TranslationState {
  final String sourceText;
  final String targetText;
  final Language sourceLang;
  final Language targetLang;
  final bool isTranslating;
  final String? error;
  final bool hasDictionaryResult;
  final bool hasLLMResult;
  final TranslationResult? result;
  final String? phonetic;
  final List<String>? definitions;
  final List<String>? examples;
  final bool isWordOrPhrase;

  TranslationState({
    this.sourceText = '',
    this.targetText = '',
    this.sourceLang = Language.english,
    this.targetLang = Language.chinese,
    this.isTranslating = false,
    this.error,
    this.hasDictionaryResult = false,
    this.hasLLMResult = false,
    this.result,
    this.phonetic,
    this.definitions,
    this.examples,
    this.isWordOrPhrase = false,
  });

  TranslationState copyWith({
    String? sourceText,
    String? targetText,
    Language? sourceLang,
    Language? targetLang,
    bool? isTranslating,
    String? error,
    bool? hasDictionaryResult,
    bool? hasLLMResult,
    TranslationResult? result,
    String? phonetic,
    List<String>? definitions,
    List<String>? examples,
    bool? isWordOrPhrase,
  }) {
    return TranslationState(
      sourceText: sourceText ?? this.sourceText,
      targetText: targetText ?? this.targetText,
      sourceLang: sourceLang ?? this.sourceLang,
      targetLang: targetLang ?? this.targetLang,
      isTranslating: isTranslating ?? this.isTranslating,
      error: error,
      hasDictionaryResult: hasDictionaryResult ?? this.hasDictionaryResult,
      hasLLMResult: hasLLMResult ?? this.hasLLMResult,
      result: result ?? this.result,
      phonetic: phonetic ?? this.phonetic,
      definitions: definitions ?? this.definitions,
      examples: examples ?? this.examples,
      isWordOrPhrase: isWordOrPhrase ?? this.isWordOrPhrase,
    );
  }
}

class TranslationNotifier extends StateNotifier<TranslationState> {
  final DictionaryLocalDataSource _dictionaryDataSource;
  final StarDictDataSource _starDictDataSource;
  final Ref _ref;

  TranslationNotifier(this._dictionaryDataSource, this._starDictDataSource, this._ref) : super(TranslationState());

  void updateSourceText(String text) {
    state = state.copyWith(sourceText: text);
  }

  void updateSourceLang(Language lang) {
    state = state.copyWith(sourceLang: lang);
  }

  void updateTargetLang(Language lang) {
    state = state.copyWith(targetLang: lang);
  }

  void swapLanguages() {
    state = state.copyWith(
      sourceLang: state.targetLang,
      targetLang: state.sourceLang,
      sourceText: state.targetText,
      targetText: state.sourceText,
    );
  }

  bool _isLongText(String text) {
    // 判断是否是长文本：超过 3 个单词或超过 20 个字符
    final wordCount = text.trim().split(RegExp(r'\s+')).length;
    final charCount = text.trim().length;
    return wordCount > 3 || charCount > 20;
  }

  Future<void> translate() async {
    if (state.sourceText.trim().isEmpty) return;

    state = state.copyWith(
      isTranslating: true,
      error: null,
    );

    try {
      await _translateWithTraditional();
    } catch (e) {
      state = state.copyWith(
        isTranslating: false,
        error: '翻译失败：${e.toString()}',
      );
    }
  }

  Map<String, dynamic> _parseWordResult(String text) {
    String? translation;
    String? phonetic;
    String? definition;
    String? example;

    final lines = text.split('\n').where((line) => line.trim().isNotEmpty).toList();
    
    for (final line in lines) {
      final trimmed = line.trim();
      // 处理多种可能的格式
      if (trimmed.startsWith(RegExp(r'翻译[:：]')) || trimmed.startsWith(RegExp(r'\*\*翻译[:：]\*\*')) || trimmed.startsWith(RegExp(r'【翻译】')) || trimmed.startsWith(RegExp(r'\[翻译\]'))) {
        translation = trimmed.replaceFirst(RegExp(r'^[*【\[翻译：:\]]*\s*'), '').trim();
      } else if (trimmed.startsWith(RegExp(r'(音标|拼音)[:：]')) || trimmed.startsWith(RegExp(r'\*\*(音标|拼音)[:：]\*\*')) || trimmed.startsWith(RegExp(r'【(音标|拼音)】')) || trimmed.startsWith(RegExp(r'\[(音标|拼音)\]'))) {
        phonetic = trimmed.replaceFirst(RegExp(r'^[*【\[(音标|拼音)：:\]]*\s*'), '').trim();
      } else if (trimmed.startsWith(RegExp(r'释义[:：]')) || trimmed.startsWith(RegExp(r'\*\*释义[:：]\*\*')) || trimmed.startsWith(RegExp(r'【释义】')) || trimmed.startsWith(RegExp(r'\[释义\]'))) {
        definition = trimmed.replaceFirst(RegExp(r'^[*【\[释义：:\]]*\s*'), '').trim();
      } else if (trimmed.startsWith(RegExp(r'例句[:：]')) || trimmed.startsWith(RegExp(r'\*\*例句[:：]\*\*')) || trimmed.startsWith(RegExp(r'【例句】')) || trimmed.startsWith(RegExp(r'\[例句\]'))) {
        example = trimmed.replaceFirst(RegExp(r'^[*【\[例句：:\]]*\s*'), '').trim();
      }
    }

    // 如果没找到翻译，就用整个文本的前50字符作为翻译
    if (translation == null || translation.isEmpty) {
      translation = text.substring(0, text.length > 50 ? 50 : text.length);
    }

    return {
      'translation': translation,
      'phonetic': phonetic,
      'definition': definition,
      'example': example,
    };
  }

  Future<void> _translateWithTraditional() async {
    String? translationResult;
    String? dictionaryExplanation;
    TranslationSource source = TranslationSource.dictionary;
    bool isWordOrPhrase = false;
    String? phonetic;
    List<String>? definitions;
    List<String>? examples;

    // 从词典管理器获取有效路径并设置到数据源
    final dictManager = _ref.read(dictionaryManagerProvider.notifier);
    final dictState = _ref.read(dictionaryManagerProvider);
    final dictPath = await dictManager.getValidDictionaryPath();
    
    // 检查是否是单词/短语
    final llmService = _ref.read(llmServiceProvider.notifier);
    isWordOrPhrase = llmService.isWordOrPhrase(state.sourceText);
    final llmDataSource = llmService.dataSource;

    if (isWordOrPhrase) {
      // ========== 单词/短语翻译流程 ==========
      if (state.sourceLang == Language.english && state.targetLang == Language.chinese) {
        WordEntry? wordEntry;
        
        // 检查是否是 StarDict 格式
        if (dictState.type.isStarDictFormat && dictPath != null) {
          // 设置 StarDict 数据源
          if (llmDataSource is PythonLlmDataSource) {
            _starDictDataSource.setPythonDataSource(llmDataSource);
          }
          _starDictDataSource.setDictionaryPath(dictPath);
          
          try {
            wordEntry = await _starDictDataSource.getWord(state.sourceText);
          } catch (_) {
            // 词典查询失败
          }
        } else {
          // 使用 SQLite 数据源
          _dictionaryDataSource.setCustomPath(dictPath);
          try {
            wordEntry = await _dictionaryDataSource.getWord(state.sourceText);
          } catch (_) {
            // 词典查询失败
          }
        }
        
        // 处理查询结果
        if (wordEntry != null && wordEntry.definitions.isNotEmpty) {
          translationResult = wordEntry.definitions.first.chinese;
          phonetic = wordEntry.phonetic;
          definitions = wordEntry.definitions.map((d) => d.chinese).toList();
          examples = wordEntry.examples.map((e) => e.english).toList();
          dictionaryExplanation = wordEntry.definitions.map((d) => '${d.partOfSpeech} ${d.chinese}').join('\n');
          source = TranslationSource.dictionary;
        }
      }
      
      // 词典失败，使用 OPUS-MT 兜底
      if (translationResult == null || translationResult.isEmpty) {
        try {
          if (llmDataSource is PythonLlmDataSource) {
            translationResult = await llmDataSource.translateWithOpusMt(
              state.sourceText,
              sourceLang: state.sourceLang == Language.english ? 'en' : 'zh',
              targetLang: state.targetLang == Language.chinese ? 'zh' : 'en',
            );
            source = TranslationSource.opusMt;
          }
        } catch (_) {
          translationResult = '无法翻译';
        }
      }
    } else {
      // ========== 长句/段落翻译流程 ==========
      try {
        // 直接使用 OPUS-MT
        if (llmDataSource is PythonLlmDataSource) {
          translationResult = await llmDataSource.translateWithOpusMt(
            state.sourceText,
            sourceLang: state.sourceLang == Language.english ? 'en' : 'zh',
            targetLang: state.targetLang == Language.chinese ? 'zh' : 'en',
          );
          source = TranslationSource.opusMt;
        }
      } catch (e) {
        print('[ERROR] OPUS-MT 翻译失败: $e');
        translationResult = '无法翻译';
      }
    }

    final result = TranslationResult(
      sourceText: state.sourceText,
      targetText: translationResult ?? '',
      sourceLang: state.sourceLang,
      targetLang: state.targetLang,
      translatedAt: DateTime.now(),
      source: source,
      dictionaryExplanation: dictionaryExplanation,
      phonetic: phonetic,
      definitions: definitions,
      examples: examples,
      isWordOrPhrase: isWordOrPhrase,
    );

    // 保存翻译历史
    try {
      final historyRepo = _ref.read(translationHistoryRepositoryProvider);
      await historyRepo.addHistory(result);
      // 刷新历史列表
      _ref.invalidate(translationHistoryListProvider);
    } catch (e) {
      // 忽略保存历史的错误
    }

    final usedOpusMt = source == TranslationSource.opusMt;
    final hasDictionaryResult = source == TranslationSource.dictionary && translationResult != '无法翻译';

    state = state.copyWith(
      targetText: translationResult,
      isTranslating: false,
      hasLLMResult: usedOpusMt,
      hasDictionaryResult: hasDictionaryResult,
      result: result,
      phonetic: phonetic,
      definitions: definitions,
      examples: examples,
      isWordOrPhrase: isWordOrPhrase,
    );
  }

  /// 更好的分词方法，处理标点符号
  List<String> _tokenize(String text) {
    // 1. 在标点符号前后加空格，让它们被正确分割
    String processed = text.replaceAllMapped(
      RegExp(r'([.,!?;，。！？；])'),
      (match) => ' ${match.group(1)} ',
    );
    
    // 2. 分割成单词（包括标点符号作为独立token）
    final tokens = processed.trim().split(RegExp(r'\s+'));
    
    return tokens;
  }

  void clear() {
    state = TranslationState(
      sourceLang: state.sourceLang,
      targetLang: state.targetLang,
    );
  }
}

final translationProvider = StateNotifierProvider<TranslationNotifier, TranslationState>((ref) {
  final dataSource = ref.watch(dictionaryLocalDataSourceProvider);
  final starDictDataSource = ref.watch(starDictDataSourceProvider);
  return TranslationNotifier(dataSource, starDictDataSource, ref);
});
