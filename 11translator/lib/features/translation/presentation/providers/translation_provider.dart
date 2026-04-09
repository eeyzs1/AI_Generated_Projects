import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rfdictionary/core/di/providers.dart';
import 'package:rfdictionary/features/dictionary/data/datasources/stardict_datasource.dart';
import 'package:rfdictionary/features/dictionary/domain/dictionary_repository.dart';
import 'package:rfdictionary/features/dictionary/domain/entities/word_entry.dart';
import 'package:rfdictionary/features/dictionary/domain/dictionary_manager.dart';
import 'package:rfdictionary/features/llm/data/datasources/python_llm_datasource.dart';
import 'package:rfdictionary/features/llm/domain/llm_service.dart';
import 'package:rfdictionary/features/translation/domain/entities/language.dart';
import 'package:rfdictionary/features/translation/domain/entities/translation_result.dart';
import 'package:rfdictionary/features/translation/domain/entities/translation_source.dart';
import 'package:rfdictionary/features/translation/domain/translation_history_provider.dart';

const _unset = Object();

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
    Object? error = _unset,
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
      error: identical(error, _unset) ? this.error : error as String?,
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
  final DictionaryRepository _dictionaryRepository;
  final Ref _ref;

  TranslationNotifier(this._dictionaryRepository, this._ref) : super(TranslationState());

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
        error: '\u7FFB\u8BD1\u5931\u8D25\uFF1A${e.toString()}',
      );
    }
  }

  Future<void> _translateWithTraditional() async {
    String? translationResult;
    String? dictionaryExplanation;
    TranslationSource source = TranslationSource.dictionary;
    bool isWordOrPhrase = false;
    String? phonetic;
    List<String>? definitions;
    List<String>? examples;

    final dictPath = await _ref.read(dictionaryManagerProvider.notifier).getValidDictionaryPath();

    final llmService = _ref.read(llmServiceProvider.notifier);
    isWordOrPhrase = llmService.isWordOrPhrase(state.sourceText);
    final llmDataSource = llmService.dataSource;

    if (isWordOrPhrase) {
      if (state.sourceLang == Language.english && state.targetLang == Language.chinese) {
        WordEntry? wordEntry;

        await _dictionaryRepository.setPath(dictPath);
        try {
          wordEntry = await _dictionaryRepository.getWord(state.sourceText);
        } catch (_) {
        }

        if (wordEntry != null && wordEntry.definitions.isNotEmpty) {
          translationResult = wordEntry.definitions.first.chinese;
          phonetic = wordEntry.phonetic;
          definitions = wordEntry.definitions.map((d) => d.chinese).toList();
          examples = wordEntry.examples.map((e) => e.english).toList();
          dictionaryExplanation = wordEntry.definitions.map((d) => '${d.partOfSpeech} ${d.chinese}').join('\n');
          source = TranslationSource.dictionary;
        }
      }

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
          translationResult = '\u65E0\u6CD5\u7FFB\u8BD1';
        }
      }
    } else {
      try {
        if (llmDataSource is PythonLlmDataSource) {
          translationResult = await llmDataSource.translateWithOpusMt(
            state.sourceText,
            sourceLang: state.sourceLang == Language.english ? 'en' : 'zh',
            targetLang: state.targetLang == Language.chinese ? 'zh' : 'en',
          );
          source = TranslationSource.opusMt;
        }
      } catch (e) {
        translationResult = '\u65E0\u6CD5\u7FFB\u8BD1';
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

    try {
      final historyRepo = _ref.read(translationHistoryRepositoryProvider);
      await historyRepo.addHistory(result);
      _ref.invalidate(translationHistoryListProvider);
    } catch (_) {
      debugPrint('Failed to save translation history');
    }

    final usedOpusMt = source == TranslationSource.opusMt;
    final hasDictionaryResult = source == TranslationSource.dictionary && translationResult != '\u65E0\u6CD5\u7FFB\u8BD1';

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

  void clear() {
    state = TranslationState(
      sourceLang: state.sourceLang,
      targetLang: state.targetLang,
    );
  }
}

final translationProvider = StateNotifierProvider<TranslationNotifier, TranslationState>((ref) {
  final dictState = ref.watch(dictionaryManagerProvider);
  final llmDataSource = ref.watch(llmDataSourceProvider);

  DictionaryRepository repository;
  if (dictState.type.isStarDictFormat) {
    repository = StarDictDataSource(
      pythonDataSource: llmDataSource is PythonLlmDataSource ? llmDataSource : null,
    );
  } else {
    repository = ref.watch(dictionaryLocalDataSourceProvider);
  }

  return TranslationNotifier(repository, ref);
});
