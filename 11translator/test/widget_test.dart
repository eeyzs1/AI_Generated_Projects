import 'package:flutter_test/flutter_test.dart';
import 'package:rfdictionary/features/llm/domain/llm_service.dart';
import 'package:rfdictionary/features/dictionary/domain/entities/word_entry.dart';
import 'package:rfdictionary/features/translation/domain/entities/language.dart';
import 'package:rfdictionary/features/translation/domain/entities/translation_source.dart';

bool _isWordOrPhrase(String text) {
  final cleaned = text.trim();
  final words = cleaned.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  return words.length <= 3 && cleaned.length <= 50;
}

void main() {
  group('InferenceParams', () {
    test('defaults have expected values', () {
      const params = InferenceParams.defaults;
      expect(params.temperature, 0.0);
      expect(params.topP, 1.0);
      expect(params.topK, 1);
      expect(params.maxTokens, 256);
      expect(params.repeatPenalty, 1.05);
      expect(params.stop, isNull);
    });

    test('custom params override defaults', () {
      const params = InferenceParams(
        temperature: 0.5,
        topP: 0.9,
        maxTokens: 100,
      );
      expect(params.temperature, 0.5);
      expect(params.topP, 0.9);
      expect(params.maxTokens, 100);
    });
  });

  group('isWordOrPhrase', () {
    test('identifies single words', () {
      expect(_isWordOrPhrase('hello'), isTrue);
      expect(_isWordOrPhrase('apple'), isTrue);
    });

    test('identifies short phrases', () {
      expect(_isWordOrPhrase('good morning'), isTrue);
      expect(_isWordOrPhrase('a lot of'), isTrue);
    });

    test('rejects long text', () {
      expect(
        _isWordOrPhrase(
          'This is a long sentence that should not be considered a word or phrase',
        ),
        isFalse,
      );
    });

    test('rejects text over 50 chars', () {
      expect(
        _isWordOrPhrase('a ' * 26),
        isFalse,
      );
    });
  });

  group('WordEntry', () {
    test('creates with required fields', () {
      const entry = WordEntry(
        word: 'test',
        definitions: [
          Definition(partOfSpeech: 'n', chinese: '测试'),
        ],
        examples: [],
        exchanges: {},
      );
      expect(entry.word, 'test');
      expect(entry.definitions.length, 1);
      expect(entry.definitions.first.chinese, '测试');
      expect(entry.phonetic, isNull);
    });
  });

  group('Language', () {
    test('displayName returns correct values', () {
      expect(Language.english.displayName, 'English');
      expect(Language.chinese.displayName, '中文');
    });

    test('code returns correct values', () {
      expect(Language.english.code, 'en');
      expect(Language.chinese.code, 'zh');
    });
  });

  group('TranslationSource', () {
    test('has expected values', () {
      expect(TranslationSource.values, contains(TranslationSource.dictionary));
      expect(TranslationSource.values, contains(TranslationSource.opusMt));
    });
  });

  group('LlmStatus', () {
    test('has all expected values', () {
      expect(LlmStatus.values, containsAll([
        LlmStatus.notLoaded,
        LlmStatus.loading,
        LlmStatus.ready,
        LlmStatus.error,
      ],),);
    });
  });
}
