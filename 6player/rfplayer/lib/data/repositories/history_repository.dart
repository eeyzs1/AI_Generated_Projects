import 'dart:io';
import '../database/daos/history_dao.dart';
import '../models/play_history.dart';

class HistoryRepository {
  final HistoryDao _dao;

  HistoryRepository(this._dao);

  Future<List<PlayHistory>> getHistory({int limit = 50, int offset = 0}) async {
    return await _dao.getHistory(limit: limit, offset: offset);
  }

  Future<PlayHistory?> getByPath(String path) async {
    return await _dao.getByPath(path);
  }

  Future<void> upsert(PlayHistory history) async {
    await _dao.upsert(history);
  }

  Future<void> updatePosition(String path, Duration position) async {
    await _dao.updatePosition(path, position);
  }

  Future<void> deleteById(String id) async {
    await _dao.deleteById(id);
  }

  Future<void> deleteAll() async {
    await _dao.deleteAll();
  }

  Future<void> cleanupInvalidRecords() async {
    final records = await _dao.getHistory(limit: 1000, offset: 0);
    for (final record in records) {
      if (!record.path.startsWith('content://')) {
        if (!File(record.path).existsSync()) {
          await _dao.deleteById(record.id);
        }
      }
    }
  }

  Future<void> updateThumbnail(String path, String thumbnailPath) async {
    final history = await getByPath(path);
    if (history != null) {
      final updated = PlayHistory(
        id: history.id,
        path: history.path,
        displayName: history.displayName,
        extension: history.extension,
        type: history.type,
        thumbnailPath: thumbnailPath,
        lastPosition: history.lastPosition,
        totalDuration: history.totalDuration,
        lastPlayedAt: history.lastPlayedAt,
        playCount: history.playCount,
      );
      await upsert(updated);
    }
  }

  Stream<List<PlayHistory>> watchHistory({int limit = 50}) {
    return _dao.watchHistory(limit: limit);
  }

  Future<List<PlayHistory>> getRecent({int limit = 10}) {
    return _dao.getHistory(limit: limit, offset: 0);
  }

  Future<void> deleteByPath(String path) async {
    await _dao.deleteByPath(path);
  }
}