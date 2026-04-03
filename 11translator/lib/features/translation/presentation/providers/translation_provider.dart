import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rfdictionary/core/di/providers.dart';
import 'package:rfdictionary/features/dictionary/data/datasources/dictionary_local_datasource.dart';
import 'package:rfdictionary/features/dictionary/domain/entities/word_entry.dart';
import 'package:rfdictionary/features/llm/domain/llm_service.dart';
import 'package:rfdictionary/features/llm/domain/model_manager.dart';
import 'package:rfdictionary/features/translation/domain/entities/language.dart';
import 'package:rfdictionary/features/translation/domain/entities/translation_result.dart';
import 'package:rfdictionary/features/translation/domain/entities/translation_source.dart';

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
    );
  }
}

class TranslationNotifier extends StateNotifier<TranslationState> {
  final DictionaryLocalDataSource _dictionaryDataSource;
  final Ref _ref;

  TranslationNotifier(this._dictionaryDataSource, this._ref) : super(TranslationState());

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

  bool _isLlmAvailable() {
    final llmStatus = _ref.read(llmServiceProvider);
    return llmStatus == LlmStatus.ready;
  }

  Future<void> translate() async {
    if (state.sourceText.trim().isEmpty) return;

    state = state.copyWith(
      isTranslating: true,
      error: null,
    );

    try {
      // 先确保模型已加载
      await _ensureModelLoaded();

      if (_isLlmAvailable()) {
        // 有 LLM，优先使用 LLM
        await _translateWithLlm();
      } else {
        // 没有 LLM，使用传统方案
        await _translateWithTraditional();
      }
    } catch (e) {
      state = state.copyWith(
        isTranslating: false,
        error: '翻译失败：${e.toString()}',
      );
    }
  }

  Future<void> _ensureModelLoaded() async {
    final modelManager = _ref.read(modelManagerProvider.notifier);
    final modelPath = await modelManager.getModelPath();
    final llmStatus = _ref.read(llmServiceProvider);

    if (modelPath.isNotEmpty && llmStatus != LlmStatus.ready) {
      try {
        await _ref.read(llmServiceProvider.notifier).initialize(modelPath);
      } catch (e) {
        // 模型加载失败，继续使用传统方案
      }
    }
  }

  Future<void> _translateWithLlm() async {
    final llmService = _ref.read(llmServiceProvider.notifier);
    final targetLangCode = state.targetLang == Language.chinese ? 'zh' : 'en';
    
    StringBuffer translationBuffer = StringBuffer();
    
    try {
      await for (final token in llmService.translate(state.sourceText, targetLang: targetLangCode)) {
        translationBuffer.write(token);
        state = state.copyWith(
          targetText: translationBuffer.toString(),
          hasLLMResult: true,
        );
      }

      final result = TranslationResult(
        sourceText: state.sourceText,
        targetText: translationBuffer.toString(),
        sourceLang: state.sourceLang,
        targetLang: state.targetLang,
        translatedAt: DateTime.now(),
        source: TranslationSource.llm,
      );

      state = state.copyWith(
        isTranslating: false,
        result: result,
      );
    } catch (e) {
      // LLM 失败时，回退到传统方案
      await _translateWithTraditional();
    }
  }

  Future<void> _translateWithTraditional() async {
    String? translationResult;
    String? dictionaryExplanation;

    if (state.sourceLang == Language.english && state.targetLang == Language.chinese) {
      // 英文 -> 中文
      translationResult = await _translateEnToZh(state.sourceText);
    } else if (state.sourceLang == Language.chinese && state.targetLang == Language.english) {
      // 中文 -> 英文：当前只能逐词翻译或返回原文
      translationResult = await _translateZhToEn(state.sourceText);
    } else {
      translationResult = state.sourceText;
    }

    final result = TranslationResult(
      sourceText: state.sourceText,
      targetText: translationResult,
      sourceLang: state.sourceLang,
      targetLang: state.targetLang,
      translatedAt: DateTime.now(),
      source: TranslationSource.dictionary,
      dictionaryExplanation: dictionaryExplanation,
    );

    state = state.copyWith(
      targetText: translationResult,
      isTranslating: false,
      hasDictionaryResult: true,
      result: result,
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

  Future<String> _translateEnToZh(String text) async {
    // 彻底摆脱 ECDICT，直接返回提示
    return '本地 LLM 翻译功能正在开发中，请稍后使用';
  }

  Future<String> _translateZhToEn(String text) async {
    // 中文 -> 英文：当前没有反向词典，返回原文
    // 后续可以添加反向词典或用 LLM
    return text;
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
  return TranslationNotifier(dataSource, ref);
});
