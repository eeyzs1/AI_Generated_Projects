import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/history_repository.dart';
import '../../data/models/play_history.dart';
import './database_provider.dart';

// 使用 StreamProvider 自动监听历史记录变化
final historyProvider = StreamProvider.autoDispose<List<PlayHistory>>((ref) {
  final repository = ref.watch(historyRepositoryProvider);
  return repository.watchHistory();
});

// 保留一个简单的 Provider 用于操作历史记录
final historyActionsProvider = Provider<HistoryActions>((ref) {
  final repository = ref.watch(historyRepositoryProvider);
  return HistoryActions(repository);
});

class HistoryActions {
  final HistoryRepository _repository;

  HistoryActions(this._repository);

  Future<void> deleteHistory(String id) async {
    await _repository.deleteById(id);
  }

  Future<void> clearAllHistory() async {
    await _repository.deleteAll();
  }

  Future<void> updatePosition(String path, Duration position) async {
    await _repository.updatePosition(path, position);
  }

  Future<void> upsertHistory(PlayHistory history) async {
    await _repository.upsert(history);
  }
}