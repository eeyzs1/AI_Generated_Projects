import 'dart:io';

class PlatformUtils {
  static bool get isAndroid => Platform.isAndroid;
  static bool get isWindows => Platform.isWindows;
  static bool get isIOS => Platform.isIOS;
  static bool get isMacOS => Platform.isMacOS;
  static bool get isLinux => Platform.isLinux;
  static bool get isWeb => false; // Flutter Web 暂时不支持

  static String get platformName {
    if (isAndroid) return 'Android';
    if (isWindows) return 'Windows';
    if (isIOS) return 'iOS';
    if (isMacOS) return 'macOS';
    if (isLinux) return 'Linux';
    return 'Unknown';
  }

  static bool get isMobile => isAndroid || isIOS;
  static bool get isDesktop => isWindows || isMacOS || isLinux;

  static Future<bool> requestStoragePermission() async {
    // 这个方法会在平台特定实现中被调用
    return true;
  }

  static Future<bool> hasStoragePermission() async {
    // 这个方法会在平台特定实现中被调用
    return true;
  }

  static Future<String?> getDefaultStoragePath() async {
    if (isAndroid) {
      return '/storage/emulated/0';
    } else if (isWindows) {
      return 'C:\\';
    }
    return null;
  }
}