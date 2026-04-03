import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:rfdictionary/core/utils/platform_utils.dart';
import 'package:rfdictionary/features/dictionary/domain/entities/word_entry.dart';

class DictionaryLocalDataSource {
  Database? _db;
  static const String _dbName = 'stardict.db';
  static const int _cacheSizeDesktop = 32768; // KB
  static const int _cacheSizeMobile = 4096;   // KB

  Future<Database> get db async {
    _db ??= await _openDatabase();
    return _db!;
  }

  static Stream<double> initDatabaseIfNeeded() async* {
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = path.join(dir.path, _dbName);

    if (File(dbPath).existsSync()) {
      try {
        final db = await openDatabase(dbPath, readOnly: true);
        final result = await db.rawQuery('PRAGMA integrity_check');
        await db.close();
        if (result.first.values.first == 'ok') {
          yield 1.0;
          return;
        }
      } catch (_) {
        // Database is corrupted, will re-copy
      }
      await File(dbPath).delete();
    }

    // 检查 assets 中是否有数据库文件
    try {
      yield 0.0;
      final data = await rootBundle.load('assets/$_dbName');
      final bytes = data.buffer.asUint8List();
      final total = bytes.length;
      const chunkSize = 65536; // 64KB chunks for better progress reporting
      int written = 0;

      final sink = File(dbPath).openWrite(mode: FileMode.write);
      while (written < total) {
        final end = (written + chunkSize).clamp(0, total);
        sink.add(bytes.sublist(written, end));
        written = end;
        yield written / total;
        // Small delay to allow UI to update
        await Future.delayed(const Duration(milliseconds: 1));
      }
      await sink.flush();
      await sink.close();
      yield 1.0;
    } catch (e) {
      // assets 中没有数据库文件，直接返回
      yield 1.0;
    }
  }

  Future<Database> _openDatabase() async {
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = path.join(dir.path, _dbName);
    
    // 检查数据库文件是否存在
    if (!File(dbPath).existsSync()) {
      throw StateError('词典数据库文件不存在');
    }
    
    return openDatabase(
      dbPath,
      readOnly: true,
      onOpen: (db) async {
        // Performance optimization: configure cache size (works with read-only)
        final cacheSize = PlatformUtils.isDesktop ? _cacheSizeDesktop : _cacheSizeMobile;
        await db.execute('PRAGMA cache_size = $cacheSize');
        // Note: WAL mode and other write-related pragmas are skipped for read-only databases
      },
    );
  }

  Future<bool> isDatabaseAvailable() async {
    try {
      final database = await db;
      // 尝试查询一下看数据库是否工作
      await database.rawQuery('SELECT 1');
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 清理释义文本，提取纯翻译内容
  String _cleanDefinition(String text) {
    // 1. 移除像 "的"、"地"、"得" 这类助词开头的描述
    // 2. 移除括号里的说明
    // 3. 提取主要的中文释义
    String cleaned = text;
    
    // 移除括号及其内容（包括中文和英文括号）
    cleaned = cleaned.replaceAll(RegExp(r'\([^)]*\)'), '');
    cleaned = cleaned.replaceAll(RegExp(r'\[[^\]]*\]'), '');
    cleaned = cleaned.replaceAll(RegExp(r'（[^）]*）'), '');
    
    // 移除 "的"、"地"、"得" 开头的短语（如 "be的现在时复数或第二人称单数" → ""）
    cleaned = cleaned.replaceAll(RegExp(r'^[a-zA-Z]+的.*$'), '');
    cleaned = cleaned.replaceAll(RegExp(r'^.*的$'), '');
    
    // 移除像 "vi."、"vt."、"n." 这类词性标记
    cleaned = cleaned.replaceAll(RegExp(r'[a-z]+\.'), '');
    
    // 提取纯中文词或短语（尝试匹配常见的中文释义格式）
    // 常见格式: "n. 苹果" → "苹果"
    // 或者: "苹果" → "苹果"
    final chineseMatch = RegExp(r'[\u4e00-\u9fa5]+(?:、[\u4e00-\u9fa5]+)*').firstMatch(cleaned);
    if (chineseMatch != null) {
      cleaned = chineseMatch.group(0)!;
    }
    
    // 清理前后空格
    cleaned = cleaned.trim();
    
    return cleaned;
  }

  Future<WordEntry?> getWord(String word) async {
    try {
      // 预处理：移除标点符号，转为小写
      final cleanWord = word.replaceAll(RegExp(r'[^\w\s]'), '').toLowerCase().trim();
      if (cleanWord.isEmpty) {
        return null;
      }
      
      final database = await db;
      
      // 先看看有什么表
      final tables = await database.rawQuery("SELECT name FROM sqlite_master WHERE type='table'");
      
      String tableName = 'words';
      if (tables.isEmpty) {
        return null;
      }
      
      // 如果没有 words 表，用第一个表
      bool hasWordsTable = tables.any((t) => t['name'] == 'words');
      if (!hasWordsTable) {
        tableName = tables.first['name'] as String;
      }
      
      // 查看表结构，找到 word 和 translation 列
      final schema = await database.rawQuery("PRAGMA table_info($tableName)");
      String wordColumn = 'word';
      String translationColumn = 'translation';
      
      // 查找合适的列名
      for (var col in schema) {
        final colName = col['name'] as String;
        if (colName.toLowerCase().contains('word')) {
          wordColumn = colName;
        }
        if (colName.toLowerCase().contains('translation') || 
            colName.toLowerCase().contains('trans') ||
            colName.toLowerCase() == 'zh' ||
            colName.toLowerCase() == 'chinese') {
          translationColumn = colName;
        }
      }
      
      // 查询单词
      final results = await database.query(
        tableName,
        where: '$wordColumn = ?',
        whereArgs: [cleanWord],
        limit: 1,
      );
      
      if (results.isEmpty) return null;
      
      final row = results.first;
      
      // 尝试创建 WordEntry
      final definitions = <Definition>[];
      if (row.containsKey(translationColumn) && row[translationColumn] != null) {
        final trans = row[translationColumn] as String;
        final parts = trans.split('\n');
        for (final part in parts) {
          if (part.trim().isNotEmpty) {
            final cleaned = _cleanDefinition(part.trim());
            if (cleaned.isNotEmpty) {
              definitions.add(Definition(
                partOfSpeech: '',
                chinese: cleaned,
              ));
            }
          }
        }
      }
      
      if (definitions.isEmpty) {
        // 如果找不到 translation 列，尝试用第一个文本列
        for (var entry in row.entries) {
          if (entry.value is String && (entry.value as String).isNotEmpty) {
            final cleaned = _cleanDefinition(entry.value as String);
            if (cleaned.isNotEmpty) {
              definitions.add(Definition(
                partOfSpeech: '',
                chinese: cleaned,
              ));
              break;
            }
          }
        }
      }
      
      // 如果还是没有定义，尝试使用原始单词（如果是中文）
      if (definitions.isEmpty && RegExp(r'^[\u4e00-\u9fa5]+$').hasMatch(cleanWord)) {
        definitions.add(Definition(
          partOfSpeech: '',
          chinese: cleanWord,
        ));
      }
      
      return WordEntry(
        word: row[wordColumn] as String? ?? word,
        phonetic: null,
        definitions: definitions,
        examples: [],
        exchanges: {},
      );
    } catch (e) {
      // 数据库不存在或查询失败，返回 null
      return null;
    }
  }

  Future<List<String>> getSuggestions(String prefix, {int limit = 8}) async {
    if (prefix.isEmpty) return [];
    
    try {
      final database = await db;
      final results = await database.query(
        'words',
        columns: ['word'],
        where: 'word LIKE ?',
        whereArgs: ['${prefix.toLowerCase()}%'],
        orderBy: 'frq DESC, bnc DESC',
        limit: limit,
      );
      
      return results.map((r) => r['word'] as String).toList();
    } catch (e) {
      // 数据库不存在或查询失败，返回空列表
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getExamples(int wordId, {int limit = 10}) async {
    try {
      final database = await db;
      return database.query(
        'examples',
        where: 'word_id = ?',
        whereArgs: [wordId],
        limit: limit,
      );
    } catch (e) {
      // 数据库不存在或查询失败，返回空列表
      return [];
    }
  }

  WordEntry _mapToWordEntry(Map<String, dynamic> row) {
    final word = row['word'] as String;
    final phonetic = row['phonetic'] as String?;
    
    // Parse definitions
    final definitions = <Definition>[];
    final translation = row['translation'] as String?;
    final pos = row['pos'] as String?;
    
    if (translation != null) {
      final parts = translation.split('\n');
      for (final part in parts) {
        if (part.trim().isNotEmpty) {
          definitions.add(Definition(
            partOfSpeech: pos ?? '',
            chinese: part.trim(),
          ));
        }
      }
    }

    return WordEntry(
      word: word,
      phonetic: phonetic,
      definitions: definitions,
      examples: [],
      exchanges: {},
    );
  }
}
