import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:rfdictionary/features/dictionary/domain/entities/word_entry.dart';
import 'package:rfdictionary/features/llm/data/datasources/python_llm_datasource.dart';

class StarDictDataSource {
  String? _dictPath;
  PythonLlmDataSource? _pythonDataSource;
  bool _isDictionaryLoaded = false;

  StarDictDataSource();

  void setPythonDataSource(PythonLlmDataSource? dataSource) {
    _pythonDataSource = dataSource;
  }

  void setDictionaryPath(String? path) {
    _dictPath = path;
    _isDictionaryLoaded = false;
  }

  Future<String?> extractDictionary(String archivePath, String outputDir) async {
    if (_pythonDataSource == null) {
      return null;
    }
    return await _pythonDataSource!.extractDictionary(archivePath, outputDir);
  }

  Future<bool> loadDictionary() async {
    if (_pythonDataSource == null || _dictPath == null) {
      return false;
    }
    final success = await _pythonDataSource!.loadDictionary(_dictPath!);
    if (success) {
      _isDictionaryLoaded = true;
    }
    return success;
  }

  Future<WordEntry?> getWord(String word) async {
    if (_pythonDataSource == null || _dictPath == null) {
      return null;
    }

    if (!_isDictionaryLoaded) {
      final loaded = await loadDictionary();
      if (!loaded) {
        return null;
      }
    }

    final result = await _pythonDataSource!.lookupWord(_dictPath!, word);
    if (result == null || result['found'] != true) {
      return null;
    }

    return _parseStarDictResult(result);
  }

  WordEntry _parseStarDictResult(Map<String, dynamic> result) {
    final word = result['word'] as String;
    final definition = result['definition'] as String;

    final definitions = <Definition>[];
    final examples = <ExampleSentence>[];

    final lines = definition.split('\n');
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      if (trimmed.startsWith(RegExp(r'^[a-z]+\.'))) {
        final dotIndex = trimmed.indexOf('.');
        if (dotIndex != -1) {
          final partOfSpeech = trimmed.substring(0, dotIndex).trim();
          final chinese = trimmed.substring(dotIndex + 1).trim();
          definitions.add(Definition(
            partOfSpeech: partOfSpeech,
            chinese: chinese,
          ));
        }
      } else if (trimmed.startsWith('例：') || trimmed.startsWith('例句：')) {
        final exampleText = trimmed.substring(trimmed.indexOf('：') + 1).trim();
        examples.add(ExampleSentence(
          english: exampleText,
        ));
      } else if (definitions.isEmpty) {
        definitions.add(Definition(
          partOfSpeech: '',
          chinese: trimmed,
        ));
      }
    }

    if (definitions.isEmpty && definition.isNotEmpty) {
      definitions.add(Definition(
        partOfSpeech: '',
        chinese: definition,
      ));
    }

    return WordEntry(
      word: word,
      phonetic: null,
      definitions: definitions,
      examples: examples,
      exchanges: {},
    );
  }
}
