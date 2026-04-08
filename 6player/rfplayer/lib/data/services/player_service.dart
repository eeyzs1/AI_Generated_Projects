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
    debugPrint('[PlayerService] initialize called with path: $path, fileName: $fileName');
    debugPrint('[PlayerService] Current path before: $_currentPath, isInitialized: $_isInitialized');
    
    // 强制完全重置，无论路径是否相同
    // 处理旧的控制器
    if (_controller != null) {
      debugPrint('[PlayerService] Disposing old controller');
      // 先暂停再释放，确保旧播放器完全停止
      try {
        _controller!.pause();
        debugPrint('[PlayerService] Old controller paused');
        // 确保视频控制器的 dispose 能够完全停止播放
        await Future.delayed(const Duration(milliseconds: 100));
      } catch (e) {
        debugPrint('[PlayerService] Error pausing old controller: $e');
      }
      _controller!.dispose();
      _controller = null;
      // 再给一点时间确保 dispose 完成
      await Future.delayed(const Duration(milliseconds: 50));
      debugPrint('[PlayerService] Old controller disposed');
    }
    
    _isInitialized = false;
    _currentPath = null;
    _currentFileName = null;
    
    // 使用 RealPathUtils 获取安全的路径（永远不会是 content URI）
    final pathToUse = await RealPathUtils.getSafePath(path);
    
    if (pathToUse == null) {
      debugPrint('[PlayerService] Error: Could not get safe path for: $path');
      // 如果无法获取安全路径，直接返回，不初始化播放器
      return;
    }
    
    debugPrint('[PlayerService] Using safe path: $pathToUse');
    
    // 创建新的控制器
    debugPrint('[PlayerService] Creating new controller for path: $pathToUse');
    _controller = MyVideoPlayerController(pathToUse, ref, fileName: fileName);
    await _controller!.initialize();
    
    _currentPath = pathToUse;
    _currentFileName = fileName;
    _isInitialized = true;
    debugPrint('[PlayerService] initialize completed, currentPath: $_currentPath');
    notifyStateChanged();
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
      debugPrint('[PlayerService] stopAsyncOperations called');
      // 先暂停再释放，确保播放器完全停止
      try {
        _controller!.pause();
        debugPrint('[PlayerService] Controller paused');
      } catch (e) {
        debugPrint('[PlayerService] Error pausing controller: $e');
      }
      // 取消定时器和移除监听器
      // 由于这些操作在MyVideoPlayerController的dispose方法中已经处理，
      // 这里我们直接调用dispose来确保所有资源都被正确释放
      _controller!.dispose();
      _controller = null;
      _isInitialized = false;
      _currentPath = null;
      _currentFileName = null;
      debugPrint('[PlayerService] stopAsyncOperations completed');
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