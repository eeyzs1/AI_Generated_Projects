import 'package:rfdictionary/features/dictionary/domain/entities/word_entry.dart';

abstract class DictionaryRepository {
  Future<WordEntry?> getWord(String word);
  Future<void> setPath(String? path);
}
