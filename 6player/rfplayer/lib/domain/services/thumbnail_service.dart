import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:fc_native_video_thumbnail/fc_native_video_thumbnail.dart';

import '../../core/utils/file_utils.dart';

/// 缩略图服务 - 生成和管理媒体文件缩略图
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
    final thumbFile = File(thumbPath);
    if (await thumbFile.exists()) {
      // 检查文件大小，如果文件大小为 0，就认为它是无效的
      final fileSize = await thumbFile.length();
      if (fileSize > 0) {
        _addToMemoryCache(cacheKey, thumbPath);
        return thumbPath;
      } else {
        // 删除无效的缓存文件
        await thumbFile.delete();
      }
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

  /// 生成视频缩略图（使用 video_thumbnail 插件）
  Future<String?> _generateVideoThumbnail(String filePath) async {
    try {
      final cacheDir = await cacheDirectory;
      final cacheKey = _getCacheKey(filePath);
      final thumbPath = p.join(cacheDir, '$cacheKey.jpg');
      
      // 确保缓存目录存在
      final dir = Directory(cacheDir);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      
      // 检查文件是否存在
      final videoFile = File(filePath);
      if (!await videoFile.exists()) {
        return null;
      }
      
      // 检查文件大小
      final fileSize = await videoFile.length();
      if (fileSize == 0) {
        return null;
      }
      
      // 使用 compute 在 Isolate 中生成缩略图，避免阻塞 UI
      final thumbnail = await compute(_generateVideoThumbnailInIsolate, {
        'filePath': filePath,
        'thumbPath': thumbPath,
        'rootIsolateToken': RootIsolateToken.instance!,
      });
      
      if (thumbnail != null) {
        // 检查生成的文件是否有效
        final thumbFile = File(thumbnail);
        if (await thumbFile.exists() && await thumbFile.length() > 100) {
          _addToMemoryCache(cacheKey, thumbnail);
          return thumbnail;
        } else {
          if (await thumbFile.exists()) {
            await thumbFile.delete();
          }
        }
      }
      // 所有方法都失败，返回 null
    } catch (e) {
      debugPrint('生成视频缩略图失败: $e');
    }
    return null;
  }

  /// 在 Isolate 中生成视频缩略图
  static Future<String?> _generateVideoThumbnailInIsolate(Map<String, dynamic> params) async {
    final filePath = params['filePath'] as String;
    final thumbPath = params['thumbPath'] as String;
    final rootIsolateToken = params['rootIsolateToken'] as RootIsolateToken;
    
    try {
      // 初始化 BackgroundIsolateBinaryMessenger
      BackgroundIsolateBinaryMessenger.ensureInitialized(rootIsolateToken);
      
      final thumbnailGenerator = FcNativeVideoThumbnail();
      final result = await thumbnailGenerator.saveThumbnailToFile(
        srcFile: filePath,
        destFile: thumbPath,
        width: 320,
        height: 180,
        format: 'jpeg',
        quality: 75,
      );
      
      if (result == true) {
        return thumbPath;
      } else {
        return null;
      }
    } catch (e) {
      debugPrint('Isolate 中生成视频缩略图失败: $e');
      return null;
    }
  }

  /// 生成图片缩略图（复制原图）
  Future<String?> _generateImageThumbnail(String filePath) async {
    try {
      final cacheDir = await cacheDirectory;
      final cacheKey = _getCacheKey(filePath);
      final thumbPath = p.join(cacheDir, '$cacheKey.jpg');

      // 使用 compute 在 Isolate 中复制文件，避免阻塞 UI
      final result = await compute(_copyFileInIsolate, {
        'sourcePath': filePath,
        'destinationPath': thumbPath,
      });

      if (result) {
        _addToMemoryCache(cacheKey, thumbPath);
        return thumbPath;
      }
    } catch (e) {
      debugPrint('生成图片缩略图失败: $e');
    }
    return null;
  }

  /// 在 Isolate 中复制文件
  static Future<bool> _copyFileInIsolate(Map<String, dynamic> params) async {
    final sourcePath = params['sourcePath'] as String;
    final destinationPath = params['destinationPath'] as String;
    
    try {
      final sourceFile = File(sourcePath);
      await sourceFile.copy(destinationPath);
      return true;
    } catch (e) {
      debugPrint('Isolate 中复制文件失败: $e');
      return false;
    }
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