import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/services/play_queue_service.dart';
import '../../../data/models/play_queue.dart';
import './database_provider.dart';

final playQueueServiceProvider = Provider<PlayQueueService>((ref) {
  final repository = ref.read(playQueueRepositoryProvider);
  return PlayQueueService(repository);
});

final playQueueProvider = StateNotifierProvider<PlayQueueNotifier, List<PlayQueueItem>>((ref) {
  return PlayQueueNotifier(ref);
});

class PlayQueueNotifier extends StateNotifier<List<PlayQueueItem>> {
  final Ref _ref;
  PlayQueueService get _service => _ref.read(playQueueServiceProvider);

  PlayQueueNotifier(this._ref) : super([]) {
    _loadQueue();
  }

  Future<void> _loadQueue() async {
    final queue = await _service.getQueue();
    state = queue;
  }

  Future<void> addToQueue(String path, String displayName) async {
    await _service.addToQueue(path, displayName);
    await _loadQueue();
  }

  Future<void> removeFromQueue(String id) async {
    await _service.removeFromQueue(id);
    await _loadQueue();
  }

  Future<bool> removeFromQueueWithHandling(String id) async {
    final shouldNavigateBack = await _service.removeFromQueueWithHandling(id);
    await _loadQueue();
    return shouldNavigateBack;
  }

  Future<void> clearQueue() async {
    await _service.clearQueue();
    await _loadQueue();
  }

  Future<void> playItem(String id) async {
    await _service.playItem(id);
    await _loadQueue();
  }

  Future<void> playNext() async {
    await _service.playNext();
    await _loadQueue();
  }

  Future<void> playPrevious() async {
    await _service.playPrevious();
    await _loadQueue();
  }

  Future<void> reorderQueue(int oldIndex, int newIndex) async {
    await _service.reorderQueue(oldIndex, newIndex);
    await _loadQueue();
  }

  Future<PlayQueueItem?> getCurrentPlaying() async {
    return await _service.getCurrentPlaying();
  }

  Future<PlayQueueItem?> getNextItem() async {
    return await _service.getNextItem();
  }

  Future<void> cleanupInvalidItems() async {
    await _service.cleanupInvalidItems();
    await _loadQueue();
  }
}
