import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:rfplayer/presentation/pages/video_player/video_player_controller.dart';
import 'package:rfplayer/data/repositories/play_queue_repository.dart';

class PlayerService {
  static PlayerService? _instance;
  static PlayerService get instance => _instance ??= PlayerService._();
  
  MyVideoPlayerController? _controller;
  bool _isInitialized = false;
  String? _currentPath;
  WidgetRef? _ref;
  
  PlayerService._();
  
  Future<void> initialize(String path, WidgetRef ref) async {
    _ref = ref;
    
    if (_currentPath == path && _isInitialized) {
      // 如果已经初始化并且路径相同，直接返回
      return;
    }
    
    // 处理旧的控制器
    if (_controller != null) {
      _controller!.dispose();
    }
    
    // 创建新的控制器
    _controller = MyVideoPlayerController(path, ref);
    await _controller!.initialize();
    
    _currentPath = path;
    _isInitialized = true;
  }
  
  void play() {
    if (_controller != null && _isInitialized) {
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
  
  void dispose() {
    if (_controller != null) {
      _controller!.dispose();
      _controller = null;
    }
    _isInitialized = false;
    _currentPath = null;
    _ref = null;
  }
  
  Future<void> updateLastPlaybackPosition() async {
    if (_controller != null) {
      await _controller!.updatePlaybackPosition();
    }
  }
  
  // 清空ref引用
  void clearRef() {
    _ref = null;
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
      _ref = null;
    }
  }
  
  MyVideoPlayerController? get controller => _controller;
  bool get isInitialized => _isInitialized;
  String? get currentPath => _currentPath;
}

// 播放器服务提供者
final playerServiceProvider = Provider<PlayerService>((ref) {
  return PlayerService.instance;
});