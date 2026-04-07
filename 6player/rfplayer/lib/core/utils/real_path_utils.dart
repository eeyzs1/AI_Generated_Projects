import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class RealPathUtils {
  static const MethodChannel _channel = MethodChannel('com.example.rfplayer/real_path');

  static Future<String?> getRealPath(String contentUri) async {
    if (!Platform.isAndroid) {
      debugPrint('[RealPathUtils] 非 Android 平台，直接返回: $contentUri');
      return contentUri;
    }

    debugPrint('[RealPathUtils] 尝试获取真实路径，URI: $contentUri');
    
    try {
      final String? result = await _channel.invokeMethod(
        'getRealPath',
        {'uri': contentUri},
      );
      
      debugPrint('[RealPathUtils] 原生通道返回: $result');
      return result;
    } on PlatformException catch (e) {
      debugPrint('[RealPathUtils] 原生通道错误: ${e.code}, ${e.message}');
      return null;
    } catch (e) {
      debugPrint('[RealPathUtils] 其他错误: $e');
      return null;
    }
  }
}
