import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/history_repository.dart';
import '../../data/repositories/bookmark_repository.dart';
import '../../data/repositories/play_queue_repository.dart';
import '../../data/repositories/video_bookmark_repository.dart';
import '../../data/repositories/image_bookmark_repository.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() {
    db.close();
  });
  return db;
});

final historyDaoProvider = Provider((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.historyDao;
});

final bookmarkDaoProvider = Provider((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.bookmarkDao;
});

final playQueueDaoProvider = Provider((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.playQueueDao;
});

final videoBookmarkDaoProvider = Provider((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.videoBookmarkDao;
});

final imageBookmarkDaoProvider = Provider((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.imageBookmarkDao;
});

final historyRepositoryProvider = Provider((ref) {
  final dao = ref.watch(historyDaoProvider);
  return HistoryRepository(dao);
});

final bookmarkRepositoryProvider = Provider((ref) {
  final dao = ref.watch(bookmarkDaoProvider);
  return BookmarkRepository(dao);
});

final playQueueRepositoryProvider = Provider((ref) {
  final dao = ref.watch(playQueueDaoProvider);
  return PlayQueueRepository(dao);
});

final videoBookmarkRepositoryProvider = Provider((ref) {
  final dao = ref.watch(videoBookmarkDaoProvider);
  return VideoBookmarkRepository(dao);
});

final imageBookmarkRepositoryProvider = Provider((ref) {
  final dao = ref.watch(imageBookmarkDaoProvider);
  return ImageBookmarkRepository(dao);
});

final databaseProvider = appDatabaseProvider;
