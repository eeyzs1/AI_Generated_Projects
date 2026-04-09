import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/services/thumbnail_service.dart';
import '../../data/models/play_history.dart';

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
final thumbnailGeneratorProvider = FutureProvider.family<String?, ({String filePath, String? displayName, MediaType? type})>((ref, params) async {
  final service = ref.read(thumbnailServiceProvider);
  // 只生成缩略图，不更新历史记录（避免循环刷新）
  return await service.generateThumbnail(params.filePath, type: params.type);
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
  final futures = filePaths.map((path) async {
    results[path] = await service.getThumbnail(path);
  });
  await Future.wait(futures);
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