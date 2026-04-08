import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class RealPathUtils {
  static const MethodChannel _channel = MethodChannel('com.example.rfplayer/real_path');

  /// 检查路径是否是 content URI
  static bool isContentUri(String path) {
    return path.startsWith('content://');
  }

  /// 将 content URI 转换为真实文件路径
  /// 如果不是 content URI，直接返回原路径
  /// 如果转换失败，返回 null
  static Future<String?> getRealPath(String path) async {
    if (!isContentUri(path)) {
      debugPrint('[RealPathUtils] 不是 content URI，直接返回: $path');
      return path;
    }

    if (!Platform.isAndroid) {
      debugPrint('[RealPathUtils] 非 Android 平台，无法处理 content URI: $path');
      return null;
    }

    debugPrint('[RealPathUtils] 尝试将 content URI 转换为真实路径: $path');
    
    try {
      final String? result = await _channel.invokeMethod(
        'getRealPath',
        {'uri': path},
      );
      
      debugPrint('[RealPathUtils] 原生通道返回真实路径: $result');
      return result;
    } on PlatformException catch (e) {
      debugPrint('[RealPathUtils] 原生通道错误: ${e.code}, ${e.message}');
      return null;
    } catch (e) {
      debugPrint('[RealPathUtils] 其他错误: $e');
      return null;
    }
  }

  /// 获取安全的路径 - 永远不返回 content URI
  /// 如果是 content URI，尝试转换为真实路径
  /// 如果转换失败，返回 null
  static Future<String?> getSafePath(String path) async {
    if (!isContentUri(path)) {
      debugPrint('[RealPathUtils] 路径已经是安全路径: $path');
      return path;
    }

    debugPrint('[RealPathUtils] 检测到 content URI，尝试转换: $path');
    final realPath = await getRealPath(path);
    
    if (realPath == null) {
      debugPrint('[RealPathUtils] 无法将 content URI 转换为真实路径');
      return null;
    }

    // 验证转换后的路径是否存在
    final file = File(realPath);
    if (await file.exists()) {
      debugPrint('[RealPathUtils] 成功转换为安全路径: $realPath');
      return realPath;
    } else {
      debugPrint('[RealPathUtils] 转换后的路径不存在: $realPath');
      return null;
    }
  }

  /// 从路径中提取文件名
  static String getFileName(String path) {
    if (isContentUri(path)) {
      // 对于 content URI，尝试提取最后的部分
      final segments = path.split('/');
      return segments.isNotEmpty ? segments.last : path;
    } else {
      // 对于文件路径，使用标准方式获取文件名
      return path.split(RegExp(r'[/\\]')).last;
    }
  }
}
