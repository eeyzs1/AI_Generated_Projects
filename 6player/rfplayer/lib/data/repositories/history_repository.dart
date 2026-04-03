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
    // 清理无效记录的逻辑
  }

  Future<void> updateThumbnail(String path, String thumbnailPath) async {
    // 更新缩略图路径的逻辑
  }

  Stream<List<PlayHistory>> watchHistory({int limit = 50}) {
    return _dao.watchHistory(limit: limit);
  }

  Future<List<PlayHistory>> getRecent({int limit = 10}) {
    return _dao.getHistory(limit: limit, offset: 0);
  }

  Future<void> deleteByPath(String path) {
    // 实现根据路径删除历史记录的逻辑
    return Future.value();
  }
}