import 'dart:io';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';
import '../database/daos/play_queue_dao.dart';
import '../models/play_queue.dart';

class PlayQueueRepository {
  final PlayQueueDao _playQueueDao;

  PlayQueueRepository(this._playQueueDao);

  Future<List<PlayQueueItem>> getAll() async {
    final items = await _playQueueDao.getAll();
    final updatedItems = <PlayQueueItem>[];
    
    for (final item in items) {
      // 实时检查文件是否存在
      final isInvalid = !File(item.path).existsSync();
      if (isInvalid != item.isInvalid) {
        // 这里简化处理，直接返回带有更新状态的item
        updatedItems.add(PlayQueueItem(
          id: item.id,
          path: item.path,
          displayName: item.displayName,
          sortOrder: item.sortOrder,
          addedAt: item.addedAt,
          isCurrentPlaying: item.isCurrentPlaying,
          hasPlayed: item.hasPlayed,
          playProgress: item.playProgress,
          isInvalid: isInvalid,
        ));
      } else {
        updatedItems.add(item);
      }
    }
    
    return updatedItems;
  }

  Future<void> add(String path, String displayName) async {
    if (!File(path).existsSync()) {
      throw Exception('文件不存在: $path');
    }

    // 检查播放队列中是否已存在该视频
    final existingItems = await _playQueueDao.getAll();
    final isAlreadyInQueue = existingItems.any((item) => item.path == path);
    
    if (isAlreadyInQueue) {
      // 如果已在队列中，直接返回，不重复添加
      return;
    }

    final queueSize = existingItems.length;
    await _playQueueDao.insert(PlayQueueTableCompanion(
      id: Value(const Uuid().v4()),
      path: Value(path),
      displayName: Value(displayName),
      sortOrder: Value(queueSize),
      addedAt: Value(DateTime.now().millisecondsSinceEpoch),
      isCurrentPlaying: Value(0),
      hasPlayed: Value(0),
      playProgress: Value(0.0),
      isInvalid: Value(false),
    ));
  }

  Future<void> remove(String id) async {
    await _playQueueDao.deleteById(id);
  }

  Future<void> clear() async {
    await _playQueueDao.deleteAll();
  }

  Future<void> clearExceptCurrentPlaying() async {
    await _playQueueDao.deleteAllExceptCurrentPlaying();
  }

  Future<void> setCurrentPlaying(String id) async {
    await _playQueueDao.setCurrentPlaying(id);
  }

  Future<void> markAsPlayed(String id) async {
    await _playQueueDao.markAsPlayed(id);
  }

  Future<void> updatePlayProgress(String id, double progress) async {
    await _playQueueDao.updatePlayProgress(id, progress);
  }

  Future<void> reorder(List<String> orderedIds) async {
    await _playQueueDao.reorder(orderedIds);
  }

  Future<PlayQueueItem?> getNextItem(int currentSortOrder) async {
    final nextData = await _playQueueDao.getNextItem(currentSortOrder);
    if (nextData == null) return null;

    // 检查文件是否存在
    final isInvalid = !File(nextData.path).existsSync();
    return PlayQueueItem(
      id: nextData.id,
      path: nextData.path,
      displayName: nextData.displayName,
      sortOrder: nextData.sortOrder,
      addedAt: DateTime.fromMillisecondsSinceEpoch(nextData.addedAt),
      isCurrentPlaying: nextData.isCurrentPlaying == 1,
      hasPlayed: nextData.hasPlayed == 1,
      playProgress: nextData.playProgress,
      isInvalid: isInvalid,
    );
  }

  Future<PlayQueueItem?> getCurrentPlaying() async {
    final currentData = await _playQueueDao.getCurrentPlaying();
    if (currentData == null) return null;

    // 检查文件是否存在
    final isInvalid = !File(currentData.path).existsSync();
    return PlayQueueItem(
      id: currentData.id,
      path: currentData.path,
      displayName: currentData.displayName,
      sortOrder: currentData.sortOrder,
      addedAt: DateTime.fromMillisecondsSinceEpoch(currentData.addedAt),
      isCurrentPlaying: currentData.isCurrentPlaying == 1,
      hasPlayed: currentData.hasPlayed == 1,
      playProgress: currentData.playProgress,
      isInvalid: isInvalid,
    );
  }

  Future<void> cleanupInvalidRecords() async {
    final items = await _playQueueDao.getAll();
    for (final item in items) {
      if (!File(item.path).existsSync()) {
        await _playQueueDao.deleteById(item.id);
      }
    }
  }
}