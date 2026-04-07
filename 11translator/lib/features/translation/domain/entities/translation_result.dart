import 'package:rfdictionary/features/translation/domain/entities/language.dart';
import 'package:rfdictionary/features/translation/domain/entities/translation_source.dart';

class TranslationResult {
  final String sourceText;
  final String targetText;
  final Language sourceLang;
  final Language targetLang;
  final DateTime translatedAt;
  final TranslationSource source;
  final String? dictionaryExplanation;
  final String? phonetic;
  final List<String>? definitions;
  final List<String>? examples;
  final bool isWordOrPhrase;

  TranslationResult({
    required this.sourceText,
    required this.targetText,
    required this.sourceLang,
    required this.targetLang,
    required this.translatedAt,
    required this.source,
    this.dictionaryExplanation,
    this.phonetic,
    this.definitions,
    this.examples,
    this.isWordOrPhrase = false,
  });

  TranslationResult copyWith({
    String? sourceText,
    String? targetText,
    Language? sourceLang,
    Language? targetLang,
    DateTime? translatedAt,
    TranslationSource? source,
    String? dictionaryExplanation,
    String? phonetic,
    List<String>? definitions,
    List<String>? examples,
    bool? isWordOrPhrase,
  }) {
    return TranslationResult(
      sourceText: sourceText ?? this.sourceText,
      targetText: targetText ?? this.targetText,
      sourceLang: sourceLang ?? this.sourceLang,
      targetLang: targetLang ?? this.targetLang,
      translatedAt: translatedAt ?? this.translatedAt,
      source: source ?? this.source,
      dictionaryExplanation: dictionaryExplanation ?? this.dictionaryExplanation,
      phonetic: phonetic ?? this.phonetic,
      definitions: definitions ?? this.definitions,
      examples: examples ?? this.examples,
      isWordOrPhrase: isWordOrPhrase ?? this.isWordOrPhrase,
    );
  }
}
