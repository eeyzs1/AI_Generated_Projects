import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/history_repository.dart';
import '../../data/repositories/bookmark_repository.dart';

final appDatabaseProvider = Provider((ref) => AppDatabase());

final historyRepositoryProvider = Provider((ref) {
  final db = ref.read(appDatabaseProvider);
  return HistoryRepository(db);
});

final bookmarkRepositoryProvider = Provider((ref) {
  final db = ref.read(appDatabaseProvider);
  return BookmarkRepository(db);
});