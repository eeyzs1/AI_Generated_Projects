import '../../domain/services/permission_service.dart';
import 'package:permission_handler/permission_handler.dart';

class AndroidPermissionHandler extends PermissionServiceImpl {
  @override
  Future<bool> requestStoragePermission() async {
    // Android 13+ 使用不同的权限模型
    final status = await Permission.storage.request();
    return status.isGranted;
  }

  @override
  Future<bool> hasStoragePermission() async {
    final status = await Permission.storage.status;
    return status.isGranted;
  }

  @override
  Future<bool> requestMediaLibraryPermission() async {
    final status = await Permission.mediaLibrary.request();
    return status.isGranted;
  }

  @override
  Future<bool> hasMediaLibraryPermission() async {
    final status = await Permission.mediaLibrary.status;
    return status.isGranted;
  }
}