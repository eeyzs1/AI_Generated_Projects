part of 'translation_history_provider.dart';

typedef TranslationHistoryRepositoryRef = Ref;

final translationHistoryRepositoryProvider =
    AutoDisposeProvider<TranslationHistoryRepository>(
  translationHistoryRepository,
  name: r'translationHistoryRepository',
  dependencies: const <ProviderBase>[],
);

typedef TranslationHistoryListRef = Ref;

abstract class _$TranslationHistoryList extends AutoDisposeAsyncNotifier<List<TranslationHistory>> {
}

final translationHistoryListProvider = AutoDisposeAsyncNotifierProvider<TranslationHistoryList, List<TranslationHistory>>(
  TranslationHistoryList.new,
  name: r'translationHistoryList',
  dependencies: [translationHistoryRepositoryProvider],
);

typedef TranslationFavoriteListRef = Ref;

abstract class _$TranslationFavoriteList extends AutoDisposeAsyncNotifier<List<TranslationHistory>> {
}

final translationFavoriteListProvider = AutoDisposeAsyncNotifierProvider<TranslationFavoriteList, List<TranslationHistory>>(
  TranslationFavoriteList.new,
  name: r'translationFavoriteList',
  dependencies: [translationHistoryRepositoryProvider],
);
