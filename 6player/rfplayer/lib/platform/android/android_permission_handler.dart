import 'dart:io';
import '../../domain/services/permission_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

class AndroidPermissionHandler extends PermissionServiceImpl {
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  Future<bool> _isAndroid13OrHigher() async {
    try {
      final androidInfo = await _deviceInfo.androidInfo;
      return androidInfo.version.sdkInt >= 33;
    } catch (e) {
      return true;
    }
  }

  @override
  Future<bool> requestStoragePermission() async {
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
  }

  @override
  Future<bool> hasStoragePermission() async {
    if (await _isAndroid13OrHigher()) {
      final imageStatus = await Permission.photos.status;
      final videoStatus = await Permission.videos.status;
      final audioStatus = await Permission.audio.status;
      return imageStatus.isGranted && videoStatus.isGranted && audioStatus.isGranted;
    } else {
      final status = await Permission.storage.status;
      return status.isGranted;
    }
  }

  @override
  Future<bool> requestMediaLibraryPermission() async {
    if (Platform.isIOS || Platform.isMacOS) {
      final status = await Permission.photos.request();
      return status.isGranted;
    }
    return true;
  }

  @override
  Future<bool> hasMediaLibraryPermission() async {
    if (Platform.isIOS || Platform.isMacOS) {
      final status = await Permission.photos.status;
      return status.isGranted;
    }
    return true;
  }

  Future<bool> requestPermissionForContentUri(String uri) async {
    if (!uri.startsWith('content://')) {
      return true;
    }
    return await requestStoragePermission();
  }

  Future<bool> hasPermissionForContentUri(String uri) async {
    if (!uri.startsWith('content://')) {
      return true;
    }
    return await hasStoragePermission();
  }
}
