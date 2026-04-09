import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

void main() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final dir = await getApplicationDocumentsDirectory();
  final dbPath = path.join(dir.path, 'stardict.db');
  
  print('数据库路�? $dbPath');
  print('文件存在: ${File(dbPath).existsSync()}');
  
  if (File(dbPath).existsSync()) {
    final db = await openDatabase(dbPath, readOnly: true);
    
    // 查看所有表
    print('\n=== 数据库表 ===');
    final tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table'");
    for (var table in tables) {
      print('�? ${table['name']}');
    }
    
    // 查看 words 表结构（如果存在�?
    print('\n=== 表结�?===');
    try {
      final schema = await db.rawQuery("PRAGMA table_info(words)");
      for (var col in schema) {
        print('�? ${col['name']} (${col['type']})');
      }
    } catch (e) {
      print('words 表不存在: $e');
      
      // 看看有什么其他表
      if (tables.isNotEmpty) {
        final firstTableName = tables.first['name'];
        print('\n=== 尝试查看第一个表: $firstTableName ===');
        final schema = await db.rawQuery("PRAGMA table_info($firstTableName)");
        for (var col in schema) {
          print('�? ${col['name']} (${col['type']})');
        }
        
        // 查看第一条数�?
        print('\n=== 第一条数�?===');
        final rows = await db.query(firstTableName as String, limit: 1);
        if (rows.isNotEmpty) {
          print(rows.first);
        }
      }
    }
    
    await db.close();
  }
}
