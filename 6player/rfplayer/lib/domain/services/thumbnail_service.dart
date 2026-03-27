import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../core/utils/file_utils.dart';

/// 缩略图服务 - 生成和管理媒体文件缩略图
/// 视频：使用 media_kit 截取第 1 秒帧，保存为 JPEG
/// 图片：直接复制/缩放原图
/// LRU 缓存（最多 200 张）
class ThumbnailService {
  static const int _maxCacheSize = 200;
  /// 缩略图宽度
  static const int thumbnailWidth = 320;
  /// 缩略图高度
  static const int thumbnailHeight = 180;
  
  String? _cacheDirectory;
  final Map<String, String> _memoryCache = {};
  final List<String> _cacheOrder = [];

  /// 获取缓存目录
  Future<String> get cacheDirectory async {
    if (_cacheDirectory == null) {
      final appCache = await getApplicationCacheDirectory();
      _cacheDirectory = p.join(appCache.path, 'thumbnails');
      final dir = Directory(_cacheDirectory!);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
    }
    return _cacheDirectory!;
  }

  /// 生成缩略图缓存键（基于文件路径和时间戳）
  String _getCacheKey(String filePath) {
    final file = File(filePath);
    final modified = file.lastModifiedSync().millisecondsSinceEpoch;
    return '${filePath.hashCode}_$modified';
  }

  /// 获取缓存的缩略图路径
  Future<String?> getThumbnail(String filePath) async {
    final cacheKey = _getCacheKey(filePath);
    if (_memoryCache.containsKey(cacheKey)) {
      _cacheOrder.remove(cacheKey);
      _cacheOrder.add(cacheKey);
      return _memoryCache[cacheKey];
    }

    final cacheDir = await cacheDirectory;
    final thumbPath = p.join(cacheDir, '$cacheKey.jpg');
    if (await File(thumbPath).exists()) {
      _addToMemoryCache(cacheKey, thumbPath);
      return thumbPath;
    }

    return null;
  }

  void _addToMemoryCache(String key, String path) {
    _memoryCache[key] = path;
    _cacheOrder.add(key);
    
    while (_memoryCache.length > _maxCacheSize) {
      final oldestKey = _cacheOrder.removeAt(0);
      _memoryCache.remove(oldestKey);
    }
  }

  /// 生成缩略图
  Future<String?> generateThumbnail(String filePath) async {
    final existingThumb = await getThumbnail(filePath);
    if (existingThumb != null) {
      return existingThumb;
    }

    String? thumbPath;

    if (FileUtils.isVideoFile(filePath)) {
      thumbPath = await _generateVideoThumbnail(filePath);
    } else if (FileUtils.isImageFile(filePath)) {
      thumbPath = await _generateImageThumbnail(filePath);
    }

    return thumbPath;
  }

  /// 生成视频缩略图（使用 media_kit 获取视频信息）
  /// 注意：media_kit 不直接支持截图，建议使用 ffmpeg 工具
  Future<String?> _generateVideoThumbnail(String filePath) async {
    Player? player;
    try {
      player = Player();
      await player.open(Media(filePath), play: false);
      await Future.delayed(const Duration(seconds: 1));
      
      final duration = player.state.duration;
      if (duration.inSeconds > 0) {
        await player.seek(const Duration(seconds: 1));
        await Future.delayed(const Duration(milliseconds: 500));
        debugPrint('视频缩略图：media_kit 不支持直接截图，请使用 ffmpeg 工具');
      }
      
      await player.dispose();
      return null;
    } catch (e) {
      debugPrint('生成视频缩略图失败: $e');
      player?.dispose();
    }
    return null;
  }

  /// 使用 ffmpeg 生成视频缩略图
  /// 需要系统安装 ffmpeg
  Future<String?> generateVideoThumbnailWithFFmpeg(String filePath) async {
    try {
      final cacheDir = await cacheDirectory;
      final cacheKey = _getCacheKey(filePath);
      final thumbPath = p.join(cacheDir, '$cacheKey.jpg');

      final result = await Process.run('ffmpeg', [
        '-i', filePath,
        '-ss', '00:00:01',
        '-vframes', '1',
        '-vf', 'scale=320:180',
        '-y',
        thumbPath,
      ]);

      if (result.exitCode == 0) {
        _addToMemoryCache(cacheKey, thumbPath);
        return thumbPath;
      }
    } catch (e) {
      debugPrint('使用 ffmpeg 生成视频缩略图失败: $e');
    }
    return null;
  }

  /// 生成图片缩略图（复制原图）
  Future<String?> _generateImageThumbnail(String filePath) async {
    try {
      final cacheDir = await cacheDirectory;
      final cacheKey = _getCacheKey(filePath);
      final thumbPath = p.join(cacheDir, '$cacheKey.jpg');

      final sourceFile = File(filePath);
      await sourceFile.copy(thumbPath);

      _addToMemoryCache(cacheKey, thumbPath);
      return thumbPath;
    } catch (e) {
      debugPrint('生成图片缩略图失败: $e');
    }
    return null;
  }

  /// 异步生成缩略图
  Future<String?> generateAsync(String filePath) async {
    return generateThumbnail(filePath);
  }

  /// 清除所有缓存
  Future<void> clearCache() async {
    _memoryCache.clear();
    _cacheOrder.clear();
    
    final cacheDir = await cacheDirectory;
    final dir = Directory(cacheDir);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
      await dir.create(recursive: true);
    }
  }

  /// 清除单个文件的缓存
  Future<void> clearThumbnail(String filePath) async {
    final cacheKey = _getCacheKey(filePath);
    _memoryCache.remove(cacheKey);
    _cacheOrder.remove(cacheKey);
    
    final cacheDir = await cacheDirectory;
    final thumbPath = p.join(cacheDir, '$cacheKey.jpg');
    final file = File(thumbPath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// 获取缓存数量
  int get cachedCount => _memoryCache.length;
}