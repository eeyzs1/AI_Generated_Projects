import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../../core/utils/platform_utils.dart';

abstract class PermissionService {
  Future<bool> requestStoragePermission();
  Future<bool> hasStoragePermission();
  Future<bool> requestMediaLibraryPermission();
  Future<bool> hasMediaLibraryPermission();
}

class PermissionServiceImpl implements PermissionService {
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  Future<bool> _isAndroid13OrHigher() async {
    if (!Platform.isAndroid) return false;
    try {
      final androidInfo = await _deviceInfo.androidInfo;
      return androidInfo.version.sdkInt >= 33;
    } catch (e) {
      return true;
    }
  }

  @override
  Future<bool> requestStoragePermission() async {
    if (PlatformUtils.isAndroid) {
      if (await _isAndroid13OrHigher()) {
        final results = await [
          Permission.photos,
          Permission.videos,
          Permission.audio,
        ].request();
        return results[Permission.photos]?.isGranted == true &&
               results[Permission.videos]?.isGranted == true &&
               results[Permission.audio]?.isGranted == true;
      } else {
        final status = await Permission.storage.request();
        return status.isGranted;
      }
    } else if (PlatformUtils.isWindows) {
      return true;
    }
    return true;
  }

  @override
  Future<bool> hasStoragePermission() async {
    if (PlatformUtils.isAndroid) {
      if (await _isAndroid13OrHigher()) {
        final imageStatus = await Permission.photos.status;
        final videoStatus = await Permission.videos.status;
        final audioStatus = await Permission.audio.status;
        return imageStatus.isGranted && videoStatus.isGranted && audioStatus.isGranted;
      } else {
        final status = await Permission.storage.status;
        return status.isGranted;
      }
    } else if (PlatformUtils.isWindows) {
      return true;
    }
    return true;
  }

  @override
  Future<bool> requestMediaLibraryPermission() async {
    if (PlatformUtils.isIOS || PlatformUtils.isMacOS) {
      final status = await Permission.photos.request();
      return status.isGranted;
    }
    return true;
  }

  @override
  Future<bool> hasMediaLibraryPermission() async {
    if (PlatformUtils.isIOS || PlatformUtils.isMacOS) {
      final status = await Permission.photos.status;
      return status.isGranted;
    }
    return true;
  }
}
