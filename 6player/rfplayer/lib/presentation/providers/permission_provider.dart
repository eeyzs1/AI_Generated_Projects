import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

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
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  bool? _isAndroid13Plus;

  PermissionNotifier() : super(PermissionState()) {
    _checkInitialPermissions();
  }

  Future<bool> _isAndroid13OrHigher() async {
    if (_isAndroid13Plus != null) return _isAndroid13Plus!;
    if (!Platform.isAndroid) {
      _isAndroid13Plus = false;
      return false;
    }
    try {
      final androidInfo = await _deviceInfo.androidInfo;
      _isAndroid13Plus = androidInfo.version.sdkInt >= 33;
      return _isAndroid13Plus!;
    } catch (e) {
      debugPrint('[PermissionProvider] Error checking Android version: $e');
      _isAndroid13Plus = true;
      return true;
    }
  }

  Future<void> _checkInitialPermissions() async {
    debugPrint('[PermissionProvider] ======== Checking initial permissions ========');

    PermissionStatus status;

    if (defaultTargetPlatform == TargetPlatform.android) {
      if (await _isAndroid13OrHigher()) {
        debugPrint('[PermissionProvider] Android 13+, checking READ_MEDIA_IMAGES, READ_MEDIA_VIDEO, READ_MEDIA_AUDIO');
        final imageStatus = await Permission.photos.status;
        final videoStatus = await Permission.videos.status;
        final audioStatus = await Permission.audio.status;

        if (imageStatus.isGranted && videoStatus.isGranted && audioStatus.isGranted) {
          status = PermissionStatus.granted;
        } else if (imageStatus.isPermanentlyDenied || videoStatus.isPermanentlyDenied || audioStatus.isPermanentlyDenied) {
          status = PermissionStatus.permanentlyDenied;
        } else if (imageStatus.isDenied || videoStatus.isDenied || audioStatus.isDenied) {
          status = PermissionStatus.denied;
        } else {
          status = PermissionStatus.notDetermined;
        }
      } else {
        debugPrint('[PermissionProvider] Android 12 and below, checking READ_EXTERNAL_STORAGE');
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
      status = PermissionStatus.granted;
    }

    debugPrint('[PermissionProvider] Initial permission status: $status');

    state = state.copyWith(storagePermission: status);
  }

  Future<bool> requestStoragePermission() async {
    debugPrint('[PermissionProvider] ======== Requesting storage permission ========');

    state = state.copyWith(hasRequestedBefore: true);

    bool granted;

    if (defaultTargetPlatform == TargetPlatform.android) {
      if (await _isAndroid13OrHigher()) {
        debugPrint('[PermissionProvider] Android 13+, requesting READ_MEDIA_IMAGES, READ_MEDIA_VIDEO, READ_MEDIA_AUDIO');
        final results = await [
          Permission.photos,
          Permission.videos,
          Permission.audio,
        ].request();

        granted = results[Permission.photos]?.isGranted == true &&
                  results[Permission.videos]?.isGranted == true &&
                  results[Permission.audio]?.isGranted == true;
      } else {
        debugPrint('[PermissionProvider] Android 12 and below, requesting READ_EXTERNAL_STORAGE');
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

    debugPrint('[PermissionProvider] Request result: granted=$granted, status=$newStatus');

    state = state.copyWith(storagePermission: newStatus);
    return granted;
  }

  Future<bool> _isPermanentlyDenied() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      if (await _isAndroid13OrHigher()) {
        final imageStatus = await Permission.photos.status;
        final videoStatus = await Permission.videos.status;
        final audioStatus = await Permission.audio.status;
        return imageStatus.isPermanentlyDenied || videoStatus.isPermanentlyDenied || audioStatus.isPermanentlyDenied;
      } else {
        final storageStatus = await Permission.storage.status;
        return storageStatus.isPermanentlyDenied;
      }
    }
    return false;
  }

  Future<void> openAppSettingsPage() async {
    debugPrint('[PermissionProvider] Opening app settings');
    await openAppSettings();
  }

  Future<void> refreshPermissionStatus() async {
    debugPrint('[PermissionProvider] Refreshing permission status');
    _isAndroid13Plus = null;
    await _checkInitialPermissions();
  }
}

final permissionProvider = StateNotifierProvider<PermissionNotifier, PermissionState>(
  (ref) => PermissionNotifier(),
);
