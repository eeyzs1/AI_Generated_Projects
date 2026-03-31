import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'data/database/app_database.dart';
import 'data/repositories/history_repository.dart';
import 'data/repositories/bookmark_repository.dart';
import 'package:fvp/fvp.dart' as fvp;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化 fvp 库
  fvp.registerWith();

  final db = AppDatabase();
  final historyRepository = HistoryRepository(db);
  final bookmarkRepository = BookmarkRepository(db);

  await historyRepository.cleanupInvalidRecords();
  await bookmarkRepository.cleanupInvalidRecords();

  runApp(const ProviderScope(child: RFPlayerApp()));
}