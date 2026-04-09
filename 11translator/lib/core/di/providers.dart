import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rfdictionary/features/dictionary/data/datasources/dictionary_local_datasource.dart';
import 'package:rfdictionary/features/dictionary/data/datasources/stardict_datasource.dart';
import 'package:rfdictionary/features/llm/data/datasources/python_llm_datasource.dart';
import 'package:rfdictionary/features/llm/domain/llm_service.dart';

final dictionaryLocalDataSourceProvider = Provider<DictionaryLocalDataSource>((ref) {
  return DictionaryLocalDataSource();
});

final starDictDataSourceProvider = Provider<StarDictDataSource>((ref) {
  final llmDataSource = ref.watch(llmDataSourceProvider);
  return StarDictDataSource(
    pythonDataSource: llmDataSource is PythonLlmDataSource ? llmDataSource : null,
  );
});
