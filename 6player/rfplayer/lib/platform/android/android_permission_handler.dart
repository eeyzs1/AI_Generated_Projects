import '../../domain/services/permission_service.dart';
import 'package:permission_handler/permission_handler.dart';

class AndroidPermissionHandler extends PermissionServiceImpl {
  @override
  Future<bool> requestStoragePermission() async {
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
  
  /// 专门用于处理 content URI 的权限请求
  /// 如果传入 content URI，会请求必要的访问权限
  /// 返回是否有权限访问该 URI
  Future<bool> requestPermissionForContentUri(String uri) async {
    if (!uri.startsWith('content://')) {
      // 不是 content URI，不需要特殊权限
      return true;
    }
    
    // 对于 content URI，我们需要请求存储权限
    return await requestStoragePermission();
  }
  
  /// 检查是否有权限访问 content URI
  Future<bool> hasPermissionForContentUri(String uri) async {
    if (!uri.startsWith('content://')) {
      // 不是 content URI，默认有权限
      return true;
    }
    
    return await hasStoragePermission();
  }
}