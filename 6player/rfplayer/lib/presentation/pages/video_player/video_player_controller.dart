import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/play_history.dart' as ph;
import '../../../presentation/providers/database_provider.dart';
import 'dart:async';
import 'package:path/path.dart' as p;

class VideoPlayerController {
  final Player player;
  late final VideoController videoController;
  final String path;
  final WidgetRef ref;
  Timer? _positionTimer;

  VideoPlayerController(this.path, this.ref)
      : player = Player() {
    videoController = VideoController(player);
  }

  Future<void> initialize() async {
    await player.open(Media(path));
    
    // 尝试从历史记录恢复播放位置
    final historyRepo = ref.read(historyRepositoryProvider);
    var history = await historyRepo.getByPath(path);
    
    // 如果历史记录不存在，创建新的历史记录
    if (history == null) {
      final extension = p.extension(path).substring(1).toLowerCase();
      history = ph.PlayHistory(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        path: path,
        displayName: p.basename(path),
        extension: extension,
        type: ph.MediaType.video,
        lastPosition: Duration.zero,
        totalDuration: Duration.zero,
        lastPlayedAt: DateTime.now(),
        playCount: 1,
      );
      await historyRepo.upsert(history);
    } else {
      // 创建新的历史记录对象，更新最后播放时间和播放次数
      final extension = p.extension(path).substring(1).toLowerCase();
      final updatedHistory = ph.PlayHistory(
        id: history.id,
        path: history.path,
        displayName: history.displayName,
        extension: history.extension,
        type: history.type,
        lastPosition: history.lastPosition,
        totalDuration: history.totalDuration,
        lastPlayedAt: DateTime.now(),
        playCount: history.playCount + 1,
      );
      await historyRepo.upsert(updatedHistory);
      
      // 恢复播放位置
      if (updatedHistory.lastPosition != null) {
        await player.seek(updatedHistory.lastPosition!);
      }
    }

    // 每1秒更新一次播放位置
    _positionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      updatePlaybackPosition();
    });
  }

  Future<void> updatePlaybackPosition() async {
    final position = player.state.position;
    final historyRepo = ref.read(historyRepositoryProvider);
    await historyRepo.updatePosition(path, position);
    }

  Future<void> play() async {
    await player.play();
  }

  Future<void> pause() async {
    await player.pause();
  }

  Future<void> seek(Duration position) async {
    await player.seek(position);
  }

  Future<void> setVolume(double volume) async {
    await player.setVolume(volume);
  }

  Future<Duration> get duration async {
    return player.state.duration ?? Duration.zero;
  }

  Future<Duration> get position async {
    return player.state.position;
  }

  Future<bool> get isPlaying async {
    return player.state.playing;
  }

  void dispose() {
    _positionTimer?.cancel();
    player.dispose();
  }
}