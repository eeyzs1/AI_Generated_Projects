import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rfdictionary/features/dictionary/data/datasources/dictionary_local_datasource.dart';

final dictionaryLocalDataSourceProvider = Provider<DictionaryLocalDataSource>((ref) {
  return DictionaryLocalDataSource();
});
