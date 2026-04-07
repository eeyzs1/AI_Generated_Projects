// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'translation_history_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$translationHistoryRepositoryHash() =>
    r'71c9a3c1aa9e6dd26b7a874630c55b505354090c';

/// See also [translationHistoryRepository].
@ProviderFor(translationHistoryRepository)
final translationHistoryRepositoryProvider =
    AutoDisposeProvider<TranslationHistoryRepository>.internal(
  translationHistoryRepository,
  name: r'translationHistoryRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$translationHistoryRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef TranslationHistoryRepositoryRef
    = AutoDisposeProviderRef<TranslationHistoryRepository>;
String _$translationHistoryListHash() =>
    r'67e2791ba8e5491874f32287467623c5e3796dc5';

/// See also [TranslationHistoryList].
@ProviderFor(TranslationHistoryList)
final translationHistoryListProvider = AutoDisposeAsyncNotifierProvider<
    TranslationHistoryList, List<TranslationHistory>>.internal(
  TranslationHistoryList.new,
  name: r'translationHistoryListProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$translationHistoryListHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$TranslationHistoryList
    = AutoDisposeAsyncNotifier<List<TranslationHistory>>;
String _$translationFavoriteListHash() =>
    r'5a2ecc67d652610d898419272f24af1002ad0b14';

/// See also [TranslationFavoriteList].
@ProviderFor(TranslationFavoriteList)
final translationFavoriteListProvider = AutoDisposeAsyncNotifierProvider<
    TranslationFavoriteList, List<TranslationHistory>>.internal(
  TranslationFavoriteList.new,
  name: r'translationFavoriteListProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$translationFavoriteListHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$TranslationFavoriteList
    = AutoDisposeAsyncNotifier<List<TranslationHistory>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
