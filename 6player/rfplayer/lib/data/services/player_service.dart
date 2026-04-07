import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rfplayer/presentation/pages/video_player/video_player_controller.dart';
import 'package:rfplayer/core/utils/real_path_utils.dart';
import 'package:rfplayer/presentation/providers/permission_provider.dart';

class PlayerService extends ChangeNotifier {
  static PlayerService? _instance;
  static PlayerService get instance => _instance ??= PlayerService._();
  
  MyVideoPlayerController? _controller;
  bool _isInitialized = false;
  String? _currentPath;
  String? _currentFileName;
  
  PlayerService._();
  
  Future<void> initialize(String path, WidgetRef ref, {String? fileName}) async {
    if (_currentPath == path && _isInitialized) {
      // 如果已经初始化并且路径相同，直接返回
      return;
    }
    
    // 处理旧的控制器
    if (_controller != null) {
      _controller!.dispose();
    }
    
    // 尝试获取真实路径
    String pathToUse = path;
    if (path.startsWith('content://')) {
      debugPrint('[PlayerService] 原始路径是 content URI，尝试获取真实路径...');
      final permissionState = ref.read(permissionProvider);
      if (permissionState.hasStoragePermission) {
        debugPrint('[PlayerService] 有存储权限，使用原生通道尝试获取真实路径...');
        final realPathFromNative = await RealPathUtils.getRealPath(path);
        if (realPathFromNative != null) {
          final realFile = File(realPathFromNative);
          if (await realFile.exists()) {
            pathToUse = realPathFromNative;
            debugPrint('[PlayerService] 原生通道获取到真实路径并存在: $pathToUse');
          }
        }
      }
    }
    
    // 创建新的控制器
    _controller = MyVideoPlayerController(pathToUse, ref, fileName: fileName);
    await _controller!.initialize();
    
    _currentPath = pathToUse;
    _currentFileName = fileName;
    _isInitialized = true;
  }
  
  void play() {
    debugPrint('[PlayerService] play() called, controller: $_controller, isInitialized: $_isInitialized');
    if (_controller != null && _isInitialized) {
      debugPrint('[PlayerService] calling _controller.play()');
      _controller!.play();
    }
  }
  
  void pause() {
    if (_controller != null && _isInitialized) {
      _controller!.pause();
    }
  }
  
  void setPlaybackSpeed(double speed) {
    if (_controller != null && _isInitialized) {
      _controller!.setPlaybackSpeed(speed);
    }
  }
  
  void seek(Duration position) {
    if (_controller != null && _isInitialized) {
      _controller!.seek(position);
    }
  }
  
  @override
  void dispose() {
    if (_controller != null) {
      _controller!.dispose();
      _controller = null;
    }
    _isInitialized = false;
    _currentPath = null;
    super.dispose();
  }
  
  Future<void> updateLastPlaybackPosition() async {
    if (_controller != null) {
      await _controller!.updatePlaybackPosition();
    }
  }
  
  // 停止所有异步操作
  void stopAsyncOperations() {
    if (_controller != null) {
      // 取消定时器和移除监听器
      // 由于这些操作在MyVideoPlayerController的dispose方法中已经处理，
      // 这里我们直接调用dispose来确保所有资源都被正确释放
      _controller!.dispose();
      _controller = null;
      _isInitialized = false;
      _currentPath = null;
    }
  }
  
  MyVideoPlayerController? get controller => _controller;
  bool get isInitialized => _isInitialized;
  String? get currentPath => _currentPath;

  // 通知监听器状态变化
  void notifyStateChanged() {
    notifyListeners();
  }
}

// 播放器服务提供者
final playerServiceProvider = ChangeNotifierProvider<PlayerService>((ref) {
  return PlayerService.instance;
});