import 'package:video_player/video_player.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/play_history.dart' as ph;
import '../../../presentation/providers/database_provider.dart';
import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as p;

class MyVideoPlayerController {
  late final VideoPlayerController videoController;
  final String path;
  final WidgetRef ref;
  Timer? _positionTimer;
  bool _disposed = false;

  MyVideoPlayerController(this.path, this.ref) {
    videoController = VideoPlayerController.file(File(path));
  }

  Future<void> initialize() async {
    await videoController.initialize();

    final historyRepo = ref.read(historyRepositoryProvider);
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
      );
      await historyRepo.upsert(updatedHistory);

      if (updatedHistory.lastPosition != null && updatedHistory.lastPosition!.inMilliseconds > 0) {
        await videoController.seekTo(updatedHistory.lastPosition!);
      }
    }

    // 监听视频控制器的value变化，当duration变化时更新历史记录
    videoController.addListener(() {
      final currentDuration = videoController.value.duration;
      if (currentDuration != Duration.zero) {
        _updateTotalDuration(currentDuration);
      }
    });

    videoController.play();

    // 每1秒更新一次播放位置
    _positionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      updatePlaybackPosition();
    });
  }

  Future<void> _updateTotalDuration(Duration duration) async {
    if (_disposed) return;
    final historyRepo = ref.read(historyRepositoryProvider);
    var history = await historyRepo.getByPath(path);
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
      await historyRepo.upsert(updatedHistory);
    }
  }

  Future<void> updatePlaybackPosition() async {
    if (_disposed) return;
    final position = videoController.value.position;
    final historyRepo = ref.read(historyRepositoryProvider);
    await historyRepo.updatePosition(path, position);
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

  void dispose() {
    _disposed = true;
    _positionTimer?.cancel();
    videoController.dispose();
  }
}