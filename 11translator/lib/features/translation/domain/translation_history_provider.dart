import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:rfdictionary/features/translation/data/models/translation_history.dart';
import 'package:rfdictionary/features/translation/data/repositories/translation_history_repository.dart';

part 'translation_history_provider.g.dart';

@riverpod
TranslationHistoryRepository translationHistoryRepository(TranslationHistoryRepositoryRef ref) {
  return TranslationHistoryRepository();
}

@riverpod
class TranslationHistoryList extends _$TranslationHistoryList {
  @override
  Future<List<TranslationHistory>> build() async {
    final repo = ref.watch(translationHistoryRepositoryProvider);
    return await repo.getAllHistory();
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }

  Future<void> toggleFavorite(TranslationHistory history) async {
    final repo = ref.watch(translationHistoryRepositoryProvider);
    await repo.toggleFavorite(history);
    await refresh();
  }

  Future<void> deleteHistory(TranslationHistory history) async {
    final repo = ref.watch(translationHistoryRepositoryProvider);
    await repo.deleteHistory(history);
    await refresh();
  }

  Future<void> clearAllHistory() async {
    final repo = ref.watch(translationHistoryRepositoryProvider);
    await repo.clearAllHistory();
    await refresh();
  }
}

@riverpod
class TranslationFavoriteList extends _$TranslationFavoriteList {
  @override
  Future<List<TranslationHistory>> build() async {
    final repo = ref.watch(translationHistoryRepositoryProvider);
    return await repo.getFavorites();
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}
