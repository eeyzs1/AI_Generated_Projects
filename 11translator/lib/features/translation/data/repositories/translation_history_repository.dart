import 'package:hive/hive.dart';
import 'package:rfdictionary/features/translation/data/models/translation_history.dart';
import 'package:rfdictionary/features/translation/domain/entities/translation_result.dart';

class TranslationHistoryRepository {
  static const String _boxName = 'translation_history';
  Box<TranslationHistory>? _box;

  Future<Box<TranslationHistory>> get box async {
    if (_box == null || !_box!.isOpen) {
      _box = await Hive.openBox<TranslationHistory>(_boxName);
    }
    return _box!;
  }

  Future<void> addHistory(TranslationResult result) async {
    final historyBox = await box;
    
    final history = TranslationHistory.create(
      sourceText: result.sourceText,
      targetText: result.targetText,
      sourceLang: result.sourceLang,
      targetLang: result.targetLang,
      translatedAt: result.translatedAt,
    );
    
    await historyBox.add(history);
  }

  Future<List<TranslationHistory>> getAllHistory() async {
    final historyBox = await box;
    final all = historyBox.values.toList();
    all.sort((a, b) => b.translatedAt.compareTo(a.translatedAt));
    return all;
  }

  Future<List<TranslationHistory>> getFavorites() async {
    final historyBox = await box;
    final all = historyBox.values.where((h) => h.isFavorite).toList();
    all.sort((a, b) => b.translatedAt.compareTo(a.translatedAt));
    return all;
  }

  Future<void> toggleFavorite(TranslationHistory history) async {
    history.isFavorite = !history.isFavorite;
    await history.save();
  }

  Future<void> deleteHistory(TranslationHistory history) async {
    await history.delete();
  }

  Future<void> clearAllHistory() async {
    final historyBox = await box;
    await historyBox.clear();
  }
}
