import 'package:permission_handler/permission_handler.dart';
import '../../core/utils/platform_utils.dart';

abstract class PermissionService {
  Future<bool> requestStoragePermission();
  Future<bool> hasStoragePermission();
  Future<bool> requestMediaLibraryPermission();
  Future<bool> hasMediaLibraryPermission();
}

class PermissionServiceImpl implements PermissionService {
  @override
  Future<bool> requestStoragePermission() async {
    if (PlatformUtils.isAndroid) {
      final status = await Permission.storage.request();
      return status.isGranted;
    } else if (PlatformUtils.isWindows) {
      // Windows 不需要存储权限
      return true;
    }
    return true;
  }

  @override
  Future<bool> hasStoragePermission() async {
    if (PlatformUtils.isAndroid) {
      final status = await Permission.storage.status;
      return status.isGranted;
    } else if (PlatformUtils.isWindows) {
      // Windows 不需要存储权限
      return true;
    }
    return true;
  }

  @override
  Future<bool> requestMediaLibraryPermission() async {
    if (PlatformUtils.isAndroid) {
      final status = await Permission.mediaLibrary.request();
      return status.isGranted;
    }
    return true;
  }

  @override
  Future<bool> hasMediaLibraryPermission() async {
    if (PlatformUtils.isAndroid) {
      final status = await Permission.mediaLibrary.status;
      return status.isGranted;
    }
    return true;
  }
}