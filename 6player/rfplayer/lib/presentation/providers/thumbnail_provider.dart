import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/services/thumbnail_service.dart';
import '../../data/models/play_history.dart';
import 'database_provider.dart';

/// ThumbnailService 的单例 Provider
final thumbnailServiceProvider = Provider<ThumbnailService>((ref) {
  final service = ThumbnailService();
  ref.onDispose(() {
    // 可以在这里添加清理逻辑
  });
  return service;
});

/// 缩略图生成 Provider
/// 用于异步生成单个文件的缩略图
final thumbnailGeneratorProvider = FutureProvider.family<String?, String>((ref, filePath) async {
  final service = ref.read(thumbnailServiceProvider);
  final historyRepo = ref.read(historyRepositoryProvider);
  
  final thumbPath = await service.generateThumbnail(filePath);
  
  // 生成缩略图后，更新历史记录
  if (thumbPath != null) {
    try {
      final history = await historyRepo.getByPath(filePath);
      if (history != null) {
        final updatedHistory = PlayHistory(
          id: history.id,
          path: history.path,
          displayName: history.displayName,
          extension: history.extension,
          type: history.type,
          lastPosition: history.lastPosition,
          totalDuration: history.totalDuration,
          lastPlayedAt: history.lastPlayedAt,
          playCount: history.playCount,
          thumbnailPath: thumbPath,
        );
        await historyRepo.upsert(updatedHistory);
      }
    } catch (e) {
      debugPrint('更新历史记录缩略图失败: $e');
    }
  }
  
  return thumbPath;
});

/// 获取缓存的缩略图路径
final cachedThumbnailProvider = FutureProvider.family<String?, String>((ref, filePath) async {
  final service = ref.read(thumbnailServiceProvider);
  return service.getThumbnail(filePath);
});

/// 批量获取多个文件的缩略图
final batchThumbnailsProvider = FutureProvider.family<Map<String, String?>, List<String>>((ref, filePaths) async {
  final service = ref.read(thumbnailServiceProvider);
  final results = <String, String?>{};  
  for (final path in filePaths) {
    results[path] = await service.getThumbnail(path);
  }
  return results;
});

/// 缓存状态管理
class ThumbnailCacheNotifier extends StateNotifier<AsyncValue<void>> {
  final ThumbnailService _service;
  
  ThumbnailCacheNotifier(this._service) : super(const AsyncValue.data(null));

  /// 清除所有缓存
  Future<void> clearAll() async {
    state = const AsyncValue.loading();
    try {
      await _service.clearCache();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// 清除单个文件的缓存
  Future<void> clearOne(String filePath) async {
    await _service.clearThumbnail(filePath);
  }
}

/// 缓存管理 Provider
final thumbnailCacheProvider = StateNotifierProvider<ThumbnailCacheNotifier, AsyncValue<void>>((ref) {
  final service = ref.read(thumbnailServiceProvider);
  return ThumbnailCacheNotifier(service);
});