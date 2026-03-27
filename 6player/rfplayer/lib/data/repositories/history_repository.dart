import 'dart:io';
import '../database/app_database.dart';
import '../models/play_history.dart';

class HistoryRepository {
  final AppDatabase _db;

  HistoryRepository(this._db);

  Future<List<PlayHistory>> getHistory({int limit = 50, int offset = 0}) {
    return _db.historyDao.getHistory(limit: limit, offset: offset);
  }

  Future<PlayHistory?> getByPath(String path) {
    return _db.historyDao.getByPath(path);
  }

  Future<void> upsert(PlayHistory history) {
    return _db.historyDao.upsert(history);
  }

  Future<void> updatePosition(String path, Duration position) {
    return _db.historyDao.updatePosition(path, position);
  }

  Future<void> deleteById(String id) {
    return _db.historyDao.deleteById(id);
  }

  Future<void> deleteAll() {
    return _db.historyDao.deleteAll();
  }

  Stream<List<PlayHistory>> watchHistory({int limit = 50}) {
    return _db.historyDao.watchHistory(limit: limit);
  }

  Future<List<PlayHistory>> getRecent({int limit = 10}) {
    return _db.historyDao.getHistory(limit: limit, offset: 0);
  }

  Future<void> deleteByPath(String path) {
    return _db.historyDao.deleteByPath(path);
  }

  /// 检查历史记录中的文件是否存在，删除不存在的记录
  Future<int> cleanupInvalidRecords() async {
    final allHistory = await getHistory(limit: 1000);
    int deletedCount = 0;
    
    for (final history in allHistory) {
      final file = File(history.path);
      if (!await file.exists()) {
        await deleteById(history.id);
        deletedCount++;
      }
    }
    
    return deletedCount;
  }
}