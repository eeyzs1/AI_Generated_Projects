import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'app.dart';
import 'data/database/app_database.dart';
import 'data/repositories/history_repository.dart';
import 'data/repositories/bookmark_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 初始化MediaKit，使用默认配置
  MediaKit.ensureInitialized();
  
  // 初始化数据库
  final db = AppDatabase();
  
  // 清理无效的历史记录和书签
  final historyRepository = HistoryRepository(db);
  final bookmarkRepository = BookmarkRepository(db);
  
  await historyRepository.cleanupInvalidRecords();
  await bookmarkRepository.cleanupInvalidRecords();
  
  runApp(const ProviderScope(child: RFPlayerApp()));
}