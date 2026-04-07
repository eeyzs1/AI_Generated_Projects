import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

enum PermissionStatus {
  notDetermined,
  granted,
  denied,
  permanentlyDenied,
}

class PermissionState {
  final PermissionStatus storagePermission;
  final bool hasRequestedBefore;

  PermissionState({
    this.storagePermission = PermissionStatus.notDetermined,
    this.hasRequestedBefore = false,
  });

  bool get hasStoragePermission => storagePermission == PermissionStatus.granted;

  PermissionState copyWith({
    PermissionStatus? storagePermission,
    bool? hasRequestedBefore,
  }) {
    return PermissionState(
      storagePermission: storagePermission ?? this.storagePermission,
      hasRequestedBefore: hasRequestedBefore ?? this.hasRequestedBefore,
    );
  }
}

class PermissionNotifier extends StateNotifier<PermissionState> {
  PermissionNotifier() : super(PermissionState()) {
    _checkInitialPermissions();
  }

  Future<void> _checkInitialPermissions() async {
    debugPrint('[PermissionProvider] ======== 检查初始权限 ========');
    
    PermissionStatus status;
    
    // 检查 Android 版本对应的权限
    if (defaultTargetPlatform == TargetPlatform.android) {
      // Android 13+ (API 33+) 使用分区权限
      if (await _isAndroid13OrHigher()) {
        debugPrint('[PermissionProvider] Android 13+，检查 READ_MEDIA_IMAGES 和 READ_MEDIA_VIDEO');
        final imageStatus = await Permission.photos.status;
        final videoStatus = await Permission.videos.status;
        
        if (imageStatus.isGranted && videoStatus.isGranted) {
          status = PermissionStatus.granted;
        } else if (imageStatus.isPermanentlyDenied || videoStatus.isPermanentlyDenied) {
          status = PermissionStatus.permanentlyDenied;
        } else if (imageStatus.isDenied || videoStatus.isDenied) {
          status = PermissionStatus.denied;
        } else {
          status = PermissionStatus.notDetermined;
        }
      } else {
        // Android 12 及以下使用 READ_EXTERNAL_STORAGE
        debugPrint('[PermissionProvider] Android 12 及以下，检查 READ_EXTERNAL_STORAGE');
        final storageStatus = await Permission.storage.status;
        
        if (storageStatus.isGranted) {
          status = PermissionStatus.granted;
        } else if (storageStatus.isPermanentlyDenied) {
          status = PermissionStatus.permanentlyDenied;
        } else if (storageStatus.isDenied) {
          status = PermissionStatus.denied;
        } else {
          status = PermissionStatus.notDetermined;
        }
      }
    } else {
      // 非 Android 平台默认授予
      status = PermissionStatus.granted;
    }
    
    debugPrint('[PermissionProvider] 初始权限状态: $status');
    
    state = state.copyWith(storagePermission: status);
  }

  Future<bool> _isAndroid13OrHigher() async {
    // 简化处理，我们根据 permission_handler 的行为判断
    // 如果 photos 和 videos 权限存在，就是 Android 13+
    try {
      await Permission.photos.status;
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> requestStoragePermission() async {
    debugPrint('[PermissionProvider] ======== 请求存储权限 ========');
    
    state = state.copyWith(hasRequestedBefore: true);
    
    bool granted;
    
    if (defaultTargetPlatform == TargetPlatform.android) {
      if (await _isAndroid13OrHigher()) {
        debugPrint('[PermissionProvider] Android 13+，请求 READ_MEDIA_IMAGES 和 READ_MEDIA_VIDEO');
        final results = await [
          Permission.photos,
          Permission.videos,
        ].request();
        
        granted = results[Permission.photos]?.isGranted == true && 
                  results[Permission.videos]?.isGranted == true;
      } else {
        debugPrint('[PermissionProvider] Android 12 及以下，请求 READ_EXTERNAL_STORAGE');
        final result = await Permission.storage.request();
        granted = result.isGranted;
      }
    } else {
      granted = true;
    }
    
    final newStatus = granted 
        ? PermissionStatus.granted 
        : (await _isPermanentlyDenied() 
            ? PermissionStatus.permanentlyDenied 
            : PermissionStatus.denied);
    
    debugPrint('[PermissionProvider] 请求结果: granted=$granted, status=$newStatus');
    
    state = state.copyWith(storagePermission: newStatus);
    return granted;
  }

  Future<bool> _isPermanentlyDenied() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      if (await _isAndroid13OrHigher()) {
        final imageStatus = await Permission.photos.status;
        final videoStatus = await Permission.videos.status;
        return imageStatus.isPermanentlyDenied || videoStatus.isPermanentlyDenied;
      } else {
        final storageStatus = await Permission.storage.status;
        return storageStatus.isPermanentlyDenied;
      }
    }
    return false;
  }

  Future<void> openAppSettingsPage() async {
    debugPrint('[PermissionProvider] 打开应用设置页面');
    await openAppSettings();
  }

  Future<void> refreshPermissionStatus() async {
    debugPrint('[PermissionProvider] 刷新权限状态');
    await _checkInitialPermissions();
  }
}

final permissionProvider = StateNotifierProvider<PermissionNotifier, PermissionState>(
  (ref) => PermissionNotifier(),
);
