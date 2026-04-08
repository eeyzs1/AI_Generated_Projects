import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:fc_native_video_thumbnail/fc_native_video_thumbnail.dart';
import '../../data/models/play_history.dart' show MediaType;

class ThumbnailService {
  static final ThumbnailService _instance = ThumbnailService._internal();
  factory ThumbnailService() => _instance;
  ThumbnailService._internal();

  final FcNativeVideoThumbnail _plugin = FcNativeVideoThumbnail();
  final Map<String, String> _memoryCache = {};

  Future<String> get cacheDirectory async {
    final dir = await getTemporaryDirectory();
    final thumbDir = Directory(p.join(dir.path, 'thumbnails'));
    if (!await thumbDir.exists()) {
      await thumbDir.create(recursive: true);
    }
    return thumbDir.path;
  }

  String _getCacheKey(String filePath) {
    final file = File(filePath);
    if (file.existsSync()) {
      final stat = file.statSync();
      return '${filePath.hashCode}_${stat.modified.millisecondsSinceEpoch}';
    }
    return filePath.hashCode.toString();
  }

  void _addToMemoryCache(String key, String path) {
    _memoryCache[key] = path;
  }

  Future<String?> _getFromMemoryCache(String key) async {
    return _memoryCache[key];
  }

  MediaType? getMediaType(String filePath) {
    final ext = p.extension(filePath).toLowerCase();
    if (['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp'].contains(ext)) {
      return MediaType.image;
    }
    if (['.mp4', '.mkv', '.avi', '.mov', '.wmv', '.flv', '.webm', '.3gp', '.m4v'].contains(ext)) {
      return MediaType.video;
    }
    return null;
  }

  Future<String?> getThumbnail(String filePath) async {
    return await generateThumbnail(filePath);
  }

  Future<String?> generateThumbnail(String filePath, {MediaType? type}) async {
    debugPrint('[ThumbnailService] generateThumbnail called for: $filePath, type: $type');
    
    final mediaType = type ?? getMediaType(filePath);
    debugPrint('[ThumbnailService] isVideo: ${mediaType == MediaType.video}, isImage: ${mediaType == MediaType.image}');

    final cacheKey = _getCacheKey(filePath);
    
    final cached = await _getFromMemoryCache(cacheKey);
    if (cached != null) {
      debugPrint('[ThumbnailService] Found in memory cache: $cached');
      return cached;
    }

    final cacheDir = await cacheDirectory;
    final thumbPath = p.join(cacheDir, '$cacheKey.jpg');
    
    if (File(thumbPath).existsSync()) {
      debugPrint('[ThumbnailService] Found existing thumbnail: $thumbPath');
      _addToMemoryCache(cacheKey, thumbPath);
      return thumbPath;
    }

    String? result;
    if (mediaType == MediaType.video) {
      result = await _generateVideoThumbnail(filePath, thumbPath, cacheKey);
    } else if (mediaType == MediaType.image) {
      result = await _generateImageThumbnail(filePath, thumbPath, cacheKey);
    }

    debugPrint('[ThumbnailService] Generated thumbnail path: $result');
    return result;
  }

  Future<void> clearCache() async {
    try {
      final cacheDir = await cacheDirectory;
      final dir = Directory(cacheDir);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
        await dir.create(recursive: true);
      }
      _memoryCache.clear();
      debugPrint('[ThumbnailService] Cache cleared');
    } catch (e) {
      debugPrint('[ThumbnailService] Failed to clear cache: $e');
    }
  }

  Future<void> clearThumbnail(String filePath) async {
    try {
      final cacheKey = _getCacheKey(filePath);
      _memoryCache.remove(cacheKey);
      
      final cacheDir = await cacheDirectory;
      final thumbPath = p.join(cacheDir, '$cacheKey.jpg');
      final file = File(thumbPath);
      if (await file.exists()) {
        await file.delete();
      }
      debugPrint('[ThumbnailService] Thumbnail cleared for: $filePath');
    } catch (e) {
      debugPrint('[ThumbnailService] Failed to clear thumbnail: $e');
    }
  }

  Future<String?> _generateVideoThumbnail(String filePath, String thumbPath, String cacheKey) async {
    try {
      debugPrint('[Thumbnail] ======== 开始生成缩略图 ========');
      debugPrint('[Thumbnail] _generateVideoThumbnail called for: $filePath');
      debugPrint('[Thumbnail] Platform: ${Platform.operatingSystem}');
      
      final cacheDir = await cacheDirectory;
      debugPrint('[Thumbnail] Cache key: $cacheKey, thumbPath: $thumbPath');
      debugPrint('[Thumbnail] Cache directory: $cacheDir');
      
      final dir = Directory(cacheDir);
      if (!await dir.exists()) {
        debugPrint('[Thumbnail] Creating cache directory...');
        await dir.create(recursive: true);
      }
      
      final isContentUri = filePath.startsWith('content://');
      debugPrint('[Thumbnail] Content URI detected: $isContentUri');
      
      if (!isContentUri) {
        debugPrint('[Thumbnail] Checking regular file path...');
        final videoFile = File(filePath);
        if (!await videoFile.exists()) {
          debugPrint('[Thumbnail] ERROR: Video file does not exist: $filePath');
          return null;
        }
        debugPrint('[Thumbnail] Video file exists');
        
        final fileSize = await videoFile.length();
        debugPrint('[Thumbnail] Video file size: $fileSize bytes');
        if (fileSize == 0) {
          debugPrint('[Thumbnail] ERROR: Video file is empty: $filePath');
          return null;
        }
        
        final extension = p.extension(filePath).toLowerCase();
        debugPrint('[Thumbnail] Video file extension: $extension');
      } else {
        debugPrint('[Thumbnail] Content URI detected, skipping file existence check');
      }
      
      debugPrint('[Thumbnail] Starting compute for thumbnail generation...');
      final thumbnail = await compute(_generateVideoThumbnailInIsolate, {
        'filePath': filePath,
        'thumbPath': thumbPath,
        'isContentUri': isContentUri,
        'rootIsolateToken': RootIsolateToken.instance!,
      });
      
      debugPrint('[Thumbnail] Compute returned: $thumbnail');
      
      if (thumbnail != null) {
        final thumbFile = File(thumbnail);
        final exists = await thumbFile.exists();
        final size = exists ? await thumbFile.length() : 0;
        debugPrint('[Thumbnail] Thumbnail file exists: $exists, size: $size bytes');
        
        if (exists && size > 100) {
          _addToMemoryCache(cacheKey, thumbnail);
          debugPrint('[Thumbnail] ======== 缩略图生成成功 ========');
          return thumbnail;
        } else {
          debugPrint('[Thumbnail] ERROR: Thumbnail file invalid (too small or missing)');
          if (exists) {
            await thumbFile.delete();
          }
        }
      } else {
        debugPrint('[Thumbnail] ERROR: compute returned null');
      }
      
      debugPrint('[Thumbnail] ======== 缩略图生成失败 ========');
    } catch (e, stackTrace) {
      debugPrint('[Thumbnail] ERROR: 生成视频缩略图失败: $e');
      debugPrint('[Thumbnail] Stack trace: $stackTrace');
    }
    return null;
  }
  
  static Future<String?> _generateVideoThumbnailInIsolate(Map<String, dynamic> params) async {
    final filePath = params['filePath'] as String;
    final thumbPath = params['thumbPath'] as String;
    final isContentUri = params['isContentUri'] as bool;
    final rootIsolateToken = params['rootIsolateToken'] as RootIsolateToken;
    
    debugPrint('[Thumbnail Isolate] ======== Isolate 开始 ========');
    debugPrint('[Thumbnail Isolate] Starting for filePath: $filePath, thumbPath: $thumbPath');
    
    try {
      debugPrint('[Thumbnail Isolate] Initializing BackgroundIsolateBinaryMessenger...');
      BackgroundIsolateBinaryMessenger.ensureInitialized(rootIsolateToken);
      debugPrint('[Thumbnail Isolate] BackgroundIsolateBinaryMessenger initialized');
      
      final plugin = FcNativeVideoThumbnail();
      
      final destDir = Directory(p.dirname(thumbPath));
      debugPrint('[Thumbnail Isolate] Destination directory: ${destDir.path}');
      if (!await destDir.exists()) {
        debugPrint('[Thumbnail Isolate] Creating destination directory...');
        await destDir.create(recursive: true);
      }
      debugPrint('[Thumbnail Isolate] Destination directory ready');
      
      debugPrint('[Thumbnail Isolate] Calling FcNativeVideoThumbnail.saveThumbnailToFile with params:');
      debugPrint('[Thumbnail Isolate]   srcFile: $filePath');
      debugPrint('[Thumbnail Isolate]   srcFileUri: $isContentUri');
      debugPrint('[Thumbnail Isolate]   destFile: $thumbPath');
      debugPrint('[Thumbnail Isolate]   width: 320, height: 180, quality: 75');
      
      final stopwatch = Stopwatch()..start();
      final result = await plugin.saveThumbnailToFile(
        srcFile: filePath,
        srcFileUri: isContentUri,
        destFile: thumbPath,
        width: 320,
        height: 180,
        quality: 75,
      );
      stopwatch.stop();
      
      debugPrint('[Thumbnail Isolate] saveThumbnailToFile result: $result, took: ${stopwatch.elapsedMilliseconds}ms');
      
      if (result) {
        debugPrint('[Thumbnail Isolate] Checking generated thumbnail file...');
        final thumbFile = File(thumbPath);
        final exists = await thumbFile.exists();
        final size = exists ? await thumbFile.length() : 0;
        
        debugPrint('[Thumbnail Isolate] Thumbnail file exists: $exists, size: $size bytes');
        
        if (exists && size > 0) {
          debugPrint('[Thumbnail Isolate] ======== Isolate 成功 ========');
          return thumbPath;
        } else {
          debugPrint('[Thumbnail Isolate] ERROR: Thumbnail file is empty or missing');
          if (exists) {
            debugPrint('[Thumbnail Isolate] Deleting invalid thumbnail file...');
            await thumbFile.delete();
          }
          debugPrint('[Thumbnail Isolate] ======== Isolate 失败 ========');
          return null;
        }
      } else {
        debugPrint('[Thumbnail Isolate] ERROR: saveThumbnailToFile returned false');
        debugPrint('[Thumbnail Isolate] ======== Isolate 失败 ========');
        return null;
      }
    } catch (e, stackTrace) {
      debugPrint('[Thumbnail Isolate] ERROR: Isolate 中生成视频缩略图失败: $e');
      debugPrint('[Thumbnail Isolate] Stack trace: $stackTrace');
      debugPrint('[Thumbnail Isolate] ======== Isolate 失败 ========');
      return null;
    }
  }

  Future<String?> _generateImageThumbnail(String filePath, String thumbPath, String cacheKey) async {
    try {
      debugPrint('[ThumbnailService] Generating image thumbnail for: $filePath');
      final file = File(filePath);
      if (await file.exists()) {
        await file.copy(thumbPath);
        _addToMemoryCache(cacheKey, thumbPath);
        return thumbPath;
      }
    } catch (e) {
      debugPrint('[ThumbnailService] Failed to copy image: $e');
    }
    return null;
  }
}
