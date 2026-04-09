import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:fc_native_video_thumbnail/fc_native_video_thumbnail.dart';
import '../../data/models/play_history.dart' show MediaType;

class ThumbnailService {
  static const int _maxMemoryCacheSize = 100;
  final Map<String, String> _memoryCache = {};
  final List<String> _cacheKeyOrder = [];

  void _addToMemoryCache(String key, String path) {
    if (_memoryCache.containsKey(key)) {
      _cacheKeyOrder.remove(key);
      _cacheKeyOrder.add(key);
      return;
    }
    if (_memoryCache.length >= _maxMemoryCacheSize) {
      final oldestKey = _cacheKeyOrder.removeAt(0);
      _memoryCache.remove(oldestKey);
    }
    _memoryCache[key] = path;
    _cacheKeyOrder.add(key);
  }

  String? _getFromMemoryCache(String key) {
    return _memoryCache[key];
  }

  Future<String> get cacheDirectory async {
    final dir = await getTemporaryDirectory();
    final thumbDir = Directory(p.join(dir.path, 'thumbnails'));
    if (!await thumbDir.exists()) {
      await thumbDir.create(recursive: true);
    }
    return thumbDir.path;
  }

  String _getCacheKey(String filePath) {
    return filePath.hashCode.toString();
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
    final mediaType = type ?? getMediaType(filePath);

    final cacheKey = _getCacheKey(filePath);

    final cached = _getFromMemoryCache(cacheKey);
    if (cached != null) {
      return cached;
    }

    final cacheDir = await cacheDirectory;
    final thumbPath = p.join(cacheDir, '$cacheKey.jpg');

    if (File(thumbPath).existsSync()) {
      _addToMemoryCache(cacheKey, thumbPath);
      return thumbPath;
    }

    String? result;
    if (mediaType == MediaType.video) {
      result = await _generateVideoThumbnail(filePath, thumbPath, cacheKey);
    } else if (mediaType == MediaType.image) {
      result = await _generateImageThumbnail(filePath, thumbPath, cacheKey);
    }

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
      _cacheKeyOrder.clear();
    } catch (e) {
      debugPrint('[ThumbnailService] Failed to clear cache: $e');
    }
  }

  Future<void> clearThumbnail(String filePath) async {
    try {
      final cacheKey = _getCacheKey(filePath);
      _memoryCache.remove(cacheKey);
      _cacheKeyOrder.remove(cacheKey);

      final cacheDir = await cacheDirectory;
      final thumbPath = p.join(cacheDir, '$cacheKey.jpg');
      final file = File(thumbPath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('[ThumbnailService] Failed to clear thumbnail: $e');
    }
  }

  Future<String?> _generateVideoThumbnail(String filePath, String thumbPath, String cacheKey) async {
    try {
      final isContentUri = filePath.startsWith('content://');

      if (!isContentUri) {
        final videoFile = File(filePath);
        if (!await videoFile.exists()) {
          return null;
        }
        final fileSize = await videoFile.length();
        if (fileSize == 0) {
          return null;
        }
      }

      final thumbnail = await compute(_generateVideoThumbnailInIsolate, {
        'filePath': filePath,
        'thumbPath': thumbPath,
        'isContentUri': isContentUri,
        'rootIsolateToken': RootIsolateToken.instance!,
      });

      if (thumbnail != null) {
        final thumbFile = File(thumbnail);
        final exists = await thumbFile.exists();
        final size = exists ? await thumbFile.length() : 0;

        if (exists && size > 100) {
          _addToMemoryCache(cacheKey, thumbnail);
          return thumbnail;
        } else {
          if (exists) {
            await thumbFile.delete();
          }
        }
      }
    } catch (e, stackTrace) {
      debugPrint('[Thumbnail] ERROR generating video thumbnail: $e');
      debugPrint('[Thumbnail] Stack trace: $stackTrace');
    }
    return null;
  }

  static Future<String?> _generateVideoThumbnailInIsolate(Map<String, dynamic> params) async {
    final filePath = params['filePath'] as String;
    final thumbPath = params['thumbPath'] as String;
    final isContentUri = params['isContentUri'] as bool;
    final rootIsolateToken = params['rootIsolateToken'] as RootIsolateToken;

    try {
      BackgroundIsolateBinaryMessenger.ensureInitialized(rootIsolateToken);

      final plugin = FcNativeVideoThumbnail();

      final destDir = Directory(p.dirname(thumbPath));
      if (!await destDir.exists()) {
        await destDir.create(recursive: true);
      }

      final result = await plugin.saveThumbnailToFile(
        srcFile: filePath,
        srcFileUri: isContentUri,
        destFile: thumbPath,
        width: 320,
        height: 180,
        quality: 75,
      );

      if (result) {
        final thumbFile = File(thumbPath);
        final exists = await thumbFile.exists();
        final size = exists ? await thumbFile.length() : 0;

        if (exists && size > 0) {
          return thumbPath;
        } else {
          if (exists) {
            await thumbFile.delete();
          }
          return null;
        }
      } else {
        return null;
      }
    } catch (e, stackTrace) {
      debugPrint('[Thumbnail Isolate] ERROR: $e');
      debugPrint('[Thumbnail Isolate] Stack trace: $stackTrace');
      return null;
    }
  }

  Future<String?> _generateImageThumbnail(String filePath, String thumbPath, String cacheKey) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return null;

      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) return null;

      final codec = await instantiateImageCodec(
        bytes,
        targetWidth: 320,
      );
      final frame = await codec.getNextFrame();
      final resizedBytes = await frame.image.toByteData(format: ImageByteFormat.png);

      if (resizedBytes == null) return null;

      await File(thumbPath).writeAsBytes(resizedBytes.buffer.asUint8List());
      codec.dispose();
      _addToMemoryCache(cacheKey, thumbPath);
      return thumbPath;
    } catch (e) {
      debugPrint('[ThumbnailService] Failed to generate image thumbnail: $e');
      try {
        final file = File(filePath);
        if (await file.exists()) {
          await file.copy(thumbPath);
          _addToMemoryCache(cacheKey, thumbPath);
          return thumbPath;
        }
      } catch (e2) {
        debugPrint('[ThumbnailService] Fallback copy also failed: $e2');
      }
    }
    return null;
  }
}
