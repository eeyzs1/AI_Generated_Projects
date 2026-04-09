import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rfdictionary/core/di/providers.dart';
import 'package:rfdictionary/features/dictionary/domain/dictionary_manager.dart';

final searchQueryProvider = StateProvider<String>((ref) => '');

final searchFocusProvider = Provider<FocusNode>((ref) {
  final node = FocusNode();
  ref.onDispose(() => node.dispose());
  return node;
});

final searchSuggestionsProvider = FutureProvider<List<String>>((ref) async {
  final query = ref.watch(searchQueryProvider);
  if (query.length < 2) return [];

  final dictState = ref.watch(dictionaryManagerProvider);
  if (dictState.downloadStatus != DownloadStatus.completed &&
      dictState.downloadStatus != DownloadStatus.idle) {
    return [];
  }

  final dataSource = ref.read(dictionaryLocalDataSourceProvider);
  try {
    return await dataSource.getSuggestions(query, limit: 8);
  } catch (e) {
    return [];
  }
});
