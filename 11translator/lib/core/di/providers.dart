import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rfdictionary/features/dictionary/data/datasources/dictionary_local_datasource.dart';
import 'package:rfdictionary/features/dictionary/data/datasources/stardict_datasource.dart';
import 'package:rfdictionary/features/dictionary/domain/dictionary_manager.dart';
import 'package:rfdictionary/features/llm/domain/model_manager.dart';

final dictionaryLocalDataSourceProvider = Provider<DictionaryLocalDataSource>((ref) {
  return DictionaryLocalDataSource();
});

final starDictDataSourceProvider = Provider<StarDictDataSource>((ref) {
  return StarDictDataSource();
});
