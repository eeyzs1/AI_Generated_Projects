import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/play_queue_repository.dart';
import '../../data/models/play_queue.dart';

class PlayQueueService {
  final PlayQueueRepository _repository;

  PlayQueueService(this._repository);

  Future<List<PlayQueueItem>> getQueue() async {
    return await _repository.getAll();
  }

  Future<void> addToQueue(String path, String displayName) async {
    await _repository.add(path, displayName);
  }

  Future<void> removeFromQueue(String id) async {
    await _repository.remove(id);
  }

  // 新的删除方法，处理当前播放视频的情况
  // 返回值: true - 表示应该返回首页，false - 表示继续在当前页面
  Future<bool> removeFromQueueWithHandling(String id) async {
    final current = await _repository.getCurrentPlaying();
    final queue = await _repository.getAll();
    
    // 检查是否是当前播放的视频
    bool isCurrentPlaying = current != null && current.id == id;
    
    if (!isCurrentPlaying) {
      // 不是当前播放的视频，直接删除
      await _repository.remove(id);
      return false;
    }
    
    // 是当前播放的视频
    int currentIndex = queue.indexWhere((item) => item.id == id);
    bool isLastItem = currentIndex == queue.length - 1;
    
    if (queue.length <= 1) {
      // 只有一个视频，删除并返回首页
      await _repository.remove(id);
      return true;
    }
    
    if (!isLastItem) {
      // 不是最后一个视频，先播放下一个，再删除当前视频
      await playNext();
      await _repository.remove(id);
      return false;
    } else {
      // 是最后一个视频，但不止一个视频，从列表开头找一个来播放
      // 先获取要播放的第一个视频（不是当前视频）
      final firstItem = queue.firstWhere((item) => item.id != id, orElse: () => queue.first);
      // 先播放这个视频
      await _repository.setCurrentPlaying(firstItem.id);
      // 再删除当前视频
      await _repository.remove(id);
      return false;
    }
  }

  Future<void> clearQueue() async {
    await _repository.clearExceptCurrentPlaying();
  }

  Future<void> playItem(String id) async {
    await _repository.setCurrentPlaying(id);
  }

  Future<void> playNext() async {
    final current = await _repository.getCurrentPlaying();
    if (current == null) return;
    
    await _repository.markAsPlayed(current.id);
    final next = await _repository.getNextItem(current.sortOrder);
    if (next != null) {
      await _repository.setCurrentPlaying(next.id);
    } else {
      // 如果没有下一个项目，从队列第一个开始播放
      final queue = await _repository.getAll();
      if (queue.isNotEmpty) {
        await _repository.setCurrentPlaying(queue[0].id);
      }
    }
  }

  Future<void> playPrevious() async {
    final current = await _repository.getCurrentPlaying();
    if (current == null) return;
    
    await _repository.markAsPlayed(current.id);
    final queue = await _repository.getAll();
    final currentIndex = queue.indexWhere((item) => item.id == current.id);
    if (currentIndex > 0) {
      final previous = queue[currentIndex - 1];
      await _repository.setCurrentPlaying(previous.id);
    } else {
      // 如果没有上一个项目，从队列最后一个开始播放
      if (queue.isNotEmpty) {
        await _repository.setCurrentPlaying(queue.last.id);
      }
    }
  }

  Future<void> reorderQueue(int oldIndex, int newIndex) async {
    final queue = await _repository.getAll();
    if (oldIndex < 0 || oldIndex >= queue.length || newIndex < 0 || newIndex >= queue.length) {
      return;
    }
    
    final reordered = List<PlayQueueItem>.from(queue);
    final item = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, item);
    
    final orderedIds = reordered.map((item) => item.id).toList();
    await _repository.reorder(orderedIds);
  }

  Future<PlayQueueItem?> getCurrentPlaying() async {
    return await _repository.getCurrentPlaying();
  }

  Future<PlayQueueItem?> getNextItem() async {
    final current = await _repository.getCurrentPlaying();
    if (current == null) return null;
    return await _repository.getNextItem(current.sortOrder);
  }

  Future<void> markAsPlayed(String id) async {
    await _repository.markAsPlayed(id);
  }

  Future<void> updatePlayProgress(String id, double progress) async {
    await _repository.updatePlayProgress(id, progress);
  }

  Future<void> cleanupInvalidItems() async {
    await _repository.cleanupInvalidRecords();
  }
}