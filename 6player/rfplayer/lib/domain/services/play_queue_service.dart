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

  Future<void> clearQueue() async {
    await _repository.clear();
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
    }
  }

  Future<void> playPrevious() async {
    final current = await _repository.getCurrentPlaying();
    if (current == null) return;
    
    final queue = await _repository.getAll();
    final currentIndex = queue.indexWhere((item) => item.id == current.id);
    if (currentIndex > 0) {
      final previous = queue[currentIndex - 1];
      await _repository.setCurrentPlaying(previous.id);
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