import 'package:video_player/video_player.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import '../../../data/models/play_history.dart' as ph;
import '../../../presentation/providers/database_provider.dart';
import '../../../presentation/providers/play_queue_provider.dart';
import '../../../presentation/providers/thumbnail_provider.dart';
import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as p;

class MyVideoPlayerController {
  late final VideoPlayerController videoController;
  final String path;
  WidgetRef? _ref;
  Timer? _positionTimer;
  VoidCallback? _videoControllerListener;
  bool _disposed = false;

  MyVideoPlayerController(this.path, WidgetRef ref) {
    videoController = VideoPlayerController.file(File(path));
    _ref = ref;
  }

  Future<void> initialize() async {
    if (_disposed || _ref == null) return;
    
    await videoController.initialize();
    
    if (_disposed || _ref == null) return;
    
    final historyRepo = _ref!.read(historyRepositoryProvider);
    var history = await historyRepo.getByPath(path);

    final duration = videoController.value.duration;
    
    if (history == null) {
      final extension = p.extension(path).substring(1).toLowerCase();
      history = ph.PlayHistory(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        path: path,
        displayName: p.basename(path),
        extension: extension,
        type: ph.MediaType.video,
        lastPosition: Duration.zero,
        totalDuration: duration != Duration.zero ? duration : null,
        lastPlayedAt: DateTime.now(),
        playCount: 1,
      );
      await historyRepo.upsert(history);
      
      // 异步生成缩略图
      if (_ref != null) {
        _generateThumbnailAsync();
      }
    } else {
      final extension = p.extension(path).substring(1).toLowerCase();
      final updatedHistory = ph.PlayHistory(
        id: history.id,
        path: history.path,
        displayName: history.displayName,
        extension: history.extension,
        type: history.type,
        lastPosition: history.lastPosition,
        totalDuration: duration != Duration.zero ? duration : history.totalDuration,
        lastPlayedAt: DateTime.now(),
        playCount: history.playCount + 1,
        thumbnailPath: history.thumbnailPath,
      );
      await historyRepo.upsert(updatedHistory);
      
      // 如果没有缩略图，异步生成
      if (_ref != null && history.thumbnailPath == null) {
        _generateThumbnailAsync();
      }

      if (updatedHistory.lastPosition != null && updatedHistory.lastPosition!.inMilliseconds > 0) {
        await videoController.seekTo(updatedHistory.lastPosition!);
      }
    }

    // 监听视频控制器的value变化，当duration变化时更新历史记录
    _videoControllerListener = () {
      if (_disposed || _ref == null) return;
      
      final currentDuration = videoController.value.duration;
      if (currentDuration != Duration.zero) {
        // 使用Future.microtask确保在当前帧之后执行，以便有时间检查disposed状态
        Future.microtask(() async {
          if (!_disposed && _ref != null) {
            await _updateCurrentDuration(currentDuration);
          }
        });
      }
      
      // 监听视频播放完成事件
      if (videoController.value.position >= videoController.value.duration && 
          videoController.value.duration != Duration.zero &&
          videoController.value.isPlaying) {
        // 使用Future.microtask确保在当前帧之后执行，以便有时间检查disposed状态
        Future.microtask(() async {
          if (!_disposed && _ref != null) {
            await _handleVideoComplete();
          }
        });
      }
    };
    videoController.addListener(_videoControllerListener!);

    videoController.play();

    // 每1秒更新一次播放位置
    _positionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_disposed) {
        timer.cancel();
        return;
      }
      // 使用Future.microtask确保在当前帧之后执行，以便有时间检查disposed状态
      Future.microtask(() async {
        if (!_disposed && _ref != null) {
          await updatePlaybackPosition();
        }
      });
    });
  }

  Future<void> _updateCurrentDuration(Duration duration) async {
    if (_disposed || _ref == null) return;
    
    try {
      // 再次检查，因为在异步操作过程中 widget 可能被销毁
      if (_disposed || _ref == null) return;
      
      final historyRepo = _ref!.read(historyRepositoryProvider);
      
      // 再次检查，因为在获取 historyRepo 后 widget 可能被销毁
      if (_disposed || _ref == null) return;
      
      var history = await historyRepo.getByPath(path);
      
      // 再次检查，因为在异步操作过程中 widget 可能被销毁
      if (_disposed || _ref == null) return;
      
      if (history != null) {
        // 无论 totalDuration 是 null 还是 Duration.zero，都更新为实际时长
        final updatedHistory = ph.PlayHistory(
          id: history.id,
          path: history.path,
          displayName: history.displayName,
          extension: history.extension,
          type: history.type,
          lastPosition: history.lastPosition,
          totalDuration: duration,
          lastPlayedAt: history.lastPlayedAt,
          playCount: history.playCount,
        );
        
        // 再次检查，因为在创建 updatedHistory 后 widget 可能被销毁
        if (_disposed || _ref == null) return;
        
        await historyRepo.upsert(updatedHistory);
      }
    } catch (e) {
      print('Error updating current duration: $e');
    }
  }

  Future<void> updatePlaybackPosition() async {
    if (_disposed || _ref == null) return;
    
    try {
      final position = videoController.value.position;
      final duration = videoController.value.duration;
      
      // 更新历史记录
      if (!_disposed && _ref != null) {
        try {
          // 再次检查，因为在异步操作过程中 widget 可能被销毁
          if (_disposed || _ref == null) return;
          
          final historyRepo = _ref!.read(historyRepositoryProvider);
          
          // 再次检查，因为在获取 historyRepo 后 widget 可能被销毁
          if (_disposed || _ref == null) return;
          
          await historyRepo.updatePosition(path, position);
        } catch (e) {
          print('Error updating history position: $e');
        }
      }
      
      // 更新播放队列中的播放进度
      if (duration != Duration.zero && !_disposed && _ref != null) {
        try {
          // 再次检查，因为在异步操作过程中 widget 可能被销毁
          if (_disposed || _ref == null) return;
          
          final progress = position.inMilliseconds / duration.inMilliseconds;
          final playQueueService = _ref!.read(playQueueServiceProvider);
          
          // 再次检查，因为在获取 playQueueService 后 widget 可能被销毁
          if (_disposed || _ref == null) return;
          
          final currentPlaying = await playQueueService.getCurrentPlaying();
          
          // 再次检查，因为在异步操作过程中 widget 可能被销毁
          if (_disposed || _ref == null) return;
          
          if (currentPlaying != null && currentPlaying.path == path) {
            await playQueueService.updatePlayProgress(currentPlaying.id, progress);
          }
        } catch (e) {
          print('Error updating play queue progress: $e');
        }
      }
    } catch (e) {
      print('Error updating playback position: $e');
    }
  }

  void play() {
    videoController.play();
  }

  void pause() {
    videoController.pause();
  }

  void seek(Duration position) {
    videoController.seekTo(position);
  }

  void setVolume(double volume) {
    videoController.setVolume(volume);
  }

  double get volume {
    return videoController.value.volume;
  }

  void setPlaybackSpeed(double speed) {
    videoController.setPlaybackSpeed(speed);
  }

  double get playbackSpeed {
    return videoController.value.playbackSpeed;
  }

  Duration get duration {
    return videoController.value.duration;
  }

  Duration get position {
    return videoController.value.position;
  }

  bool get isPlaying {
    return videoController.value.isPlaying;
  }

  VideoPlayerController get controller {
    return videoController;
  }

  // 加载字幕
  Future<void> loadSubtitle(String subtitlePath) async {
    try {
      // 由于FVP是通过VideoPlayerPlatform实现的，我们需要使用其扩展方法
      // 这里需要根据FVP的实际API来实现
      // 目前暂时打印日志
      print('Loading subtitle: $subtitlePath');
    } catch (e) {
      print('Error loading subtitle: $e');
    }
  }

  // 异步生成缩略图
  Future<void> _generateThumbnailAsync() async {
    if (_disposed || _ref == null) return;
    
    try {
      final thumbnailService = _ref!.read(thumbnailServiceProvider);
      final historyRepo = _ref!.read(historyRepositoryProvider);
      
      final thumbPath = await thumbnailService.generateThumbnail(path);
      
      if (thumbPath != null && !_disposed && _ref != null) {
        var history = await historyRepo.getByPath(path);
        if (history != null) {
          final updatedHistory = ph.PlayHistory(
            id: history.id,
            path: history.path,
            displayName: history.displayName,
            extension: history.extension,
            type: history.type,
            lastPosition: history.lastPosition,
            totalDuration: history.totalDuration,
            lastPlayedAt: history.lastPlayedAt,
            playCount: history.playCount,
            thumbnailPath: thumbPath,
          );
          await historyRepo.upsert(updatedHistory);
        }
      }
    } catch (e) {
      debugPrint('生成缩略图失败: $e');
    }
  }

  // 处理视频播放完成事件
  Future<void> _handleVideoComplete() async {
    if (_disposed || _ref == null) return;
    final playQueueNotifier = _ref!.read(playQueueProvider.notifier);
    await playQueueNotifier.playNext();
  }

  void dispose() {
    _disposed = true;
    _ref = null;
    _positionTimer?.cancel();
    // 移除监听器
    if (_videoControllerListener != null) {
      videoController.removeListener(_videoControllerListener!);
    }
    videoController.dispose();
  }
}