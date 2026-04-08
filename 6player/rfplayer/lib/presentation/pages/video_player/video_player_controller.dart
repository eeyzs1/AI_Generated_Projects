import 'package:video_player/video_player.dart';
import 'package:fvp/fvp.dart' as fvp;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import '../../../data/models/play_history.dart' as ph;
import '../../../data/models/subtitle_track.dart';
import '../../../presentation/providers/database_provider.dart';
import '../../../presentation/providers/play_queue_provider.dart';
import '../../../presentation/providers/thumbnail_provider.dart';
import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as p;

import '../../../data/services/player_service.dart';

class MyVideoPlayerController {
  late final VideoPlayerController videoController;
  final String path;
  final String? fileName;
  WidgetRef? _ref;
  Timer? _positionTimer;
  VoidCallback? _videoControllerListener;
  bool _disposed = false;
  PlayerService? _playerService; // 引用 PlayerService

  // 字幕相关
  final List<SubtitleTrack> _subtitleTracks = [];
  SubtitleTrack? _activeSubtitleTrack;
  SubtitleTrack? _lastSelectedSubtitleTrack; // 记住用户最后选择的字幕
  bool _subtitleEnabled = true;
  bool _hasActiveExternalSubtitle = false; // 标记当前是否在用外挂字幕
  int _nextExternalSubtitleId = 1000; // 外挂字幕 id 计数器，从 1000 开始

  MyVideoPlayerController(this.path, WidgetRef ref, {this.fileName}) {
    debugPrint('[MyVideoPlayerController] Initializing with path: $path, fileName: $fileName');
    // 现在路径应该已经是安全路径了（不是 content URI）
    // 所以直接使用 File 方式初始化
    debugPrint('[MyVideoPlayerController] Using file for path');
    videoController = VideoPlayerController.file(File(path));
    _ref = ref;
    _playerService = PlayerService.instance;
  }

  // 通知字幕状态变化
  void _notifySubtitleStateChanged() {
    if (_playerService != null && !_disposed) {
      _playerService!.notifyStateChanged();
    }
  }

  Future<void> initialize() async {
    if (_disposed || _ref == null) return;
    debugPrint('[MyVideoPlayerController] Starting initialize...');
    
    try {
      await videoController.initialize();
      debugPrint('[MyVideoPlayerController] videoController.initialize() completed');
      
      // 关键：启用字幕渲染和 CC（隐藏字幕）
      try {
        // 使用 FVP 的 setProperty 来启用字幕渲染
        // 这是 libmdk 的属性，确保字幕能够显示
        videoController.setProperty('subtitle', '1');
        videoController.setProperty('cc', '1');
        debugPrint('[MyVideoPlayerController] Enabled subtitle and cc rendering');
      } catch (e) {
        debugPrint('[MyVideoPlayerController] Error setting subtitle properties: $e');
      }
    } catch (e) {
      debugPrint('[MyVideoPlayerController] Error initializing videoController: $e');
      rethrow;
    }
    
    if (_disposed || _ref == null) return;
    debugPrint('[MyVideoPlayerController] Proceeding with history...');
    
    final historyRepo = _ref!.read(historyRepositoryProvider);
    // 先尝试用完整路径查找
    var history = await historyRepo.getByPath(path);
    
    // 如果没找到，尝试用 displayName 查找（处理 URI 和文件路径混用的情况）
    if (history == null) {
      final currentDisplayName = path.startsWith('content://') 
          ? p.basename(path) 
          : p.basename(path);
      final allHistory = await historyRepo.getHistory(limit: 1000, offset: 0);
      for (final h in allHistory) {
        if (h.displayName == currentDisplayName) {
          history = h;
          break;
        }
      }
    }

    final duration = videoController.value.duration;
    
    if (history == null) {
      String extension;
      if (fileName != null) {
        // 从 fileName 中提取扩展名
        final ext = p.extension(fileName!).toLowerCase();
        extension = ext.length > 1 ? ext.substring(1) : ext;
      } else {
        // 从 path 中提取扩展名
        final ext = p.extension(path).toLowerCase();
        extension = ext.length > 1 ? ext.substring(1) : ext;
      }
      debugPrint('[MyVideoPlayerController] Using extension: $extension from fileName: $fileName');
      history = ph.PlayHistory(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        path: path,
        displayName: fileName ?? p.basename(path),
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

    // 不再自动播放，由外部控制播放时机
    debugPrint('[MyVideoPlayerController] initialize completed, waiting for external play command');
    
    // 加载内置字幕（异步执行，不阻塞播放）
    loadEmbeddedSubtitles();

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
      debugPrint('Error updating current duration: $e');
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
          debugPrint('Error updating history position: $e');
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
          debugPrint('Error updating play queue progress: $e');
        }
      }
    } catch (e) {
      debugPrint('Error updating playback position: $e');
    }
  }

  void play() {
    debugPrint('[MyVideoPlayerController] ======== play() CALLED ========');
    debugPrint('[MyVideoPlayerController] _disposed=$_disposed, videoController initialized=${videoController.value.isInitialized}');
    debugPrint('[MyVideoPlayerController] Current isPlaying: ${videoController.value.isPlaying}');
    if (!_disposed) {
      debugPrint('[MyVideoPlayerController] Calling videoController.play()');
      videoController.play();
      debugPrint('[MyVideoPlayerController] videoController.play() called, new isPlaying: ${videoController.value.isPlaying}');
    } else {
      debugPrint('[MyVideoPlayerController] SKIPPING - already disposed');
    }
  }

  void pause() {
    debugPrint('[MyVideoPlayerController] ======== pause() CALLED ========');
    debugPrint('[MyVideoPlayerController] _disposed=$_disposed, isPlaying=${videoController.value.isPlaying}');
    if (!_disposed) {
      debugPrint('[MyVideoPlayerController] Calling videoController.pause()');
      videoController.pause();
      debugPrint('[MyVideoPlayerController] videoController.pause() called, new isPlaying: ${videoController.value.isPlaying}');
    } else {
      debugPrint('[MyVideoPlayerController] SKIPPING - already disposed');
    }
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

  // 字幕相关方法
  List<SubtitleTrack> get subtitleTracks => _subtitleTracks;
  SubtitleTrack? get activeSubtitleTrack => _activeSubtitleTrack;
  bool get subtitleEnabled => _subtitleEnabled;

  Future<void> loadSubtitle(String subtitlePath) async {
    try {
      debugPrint('Loading subtitle: $subtitlePath');
      
      // 创建字幕轨道对象
      final id = _nextExternalSubtitleId++;
      
      final name = p.basename(subtitlePath);
      final track = SubtitleTrack(
        id: id,
        name: name,
        type: SubtitleTrackType.external,
        path: subtitlePath,
      );
      
      _subtitleTracks.add(track);
      
      // 使用 selectSubtitleTrack 来正确设置字幕轨道并确保它显示
      await selectSubtitleTrack(track);
      
      debugPrint('Subtitle loaded successfully as track $id: $name');
    } catch (e) {
      debugPrint('Error loading subtitle: $e');
      rethrow;
    }
  }

  Future<void> loadEmbeddedSubtitles() async {
    try {
      try {
        videoController.setProperty('subtitle', '1');
        videoController.setProperty('cc', '1');
        debugPrint('loadEmbeddedSubtitles: Ensured subtitle and cc rendering are enabled');
      } catch (e) {
        debugPrint('loadEmbeddedSubtitles: Error setting subtitle properties: $e');
      }

      await Future.delayed(const Duration(milliseconds: 500));

      if (_disposed) return;

      debugPrint('Checking for embedded subtitles using FVP MediaInfo...');

      final mediaInfo = videoController.getMediaInfo();

      if (mediaInfo == null || mediaInfo.subtitle == null || mediaInfo.subtitle!.isEmpty) {
        debugPrint('No subtitle tracks found in media info, skipping subtitle processing');
        return;
      }

      debugPrint('Found ${mediaInfo.subtitle!.length} subtitle tracks');

      for (int i = 0; i < mediaInfo.subtitle!.length; i++) {
        final subtitleStream = mediaInfo.subtitle![i];

        String trackName;
        String? trackLanguage;

        final metadata = subtitleStream.metadata;
        if (metadata['language'] != null) {
          final langCode = metadata['language']!;
          trackLanguage = langCode;
          trackName = _getLanguageNameFromCode(langCode);
        } else if (metadata['title'] != null) {
          trackName = metadata['title']!;
        } else {
          trackName = '字幕 ${i + 1}';
        }

        final track = SubtitleTrack(
          id: i,
          name: trackName,
          language: trackLanguage,
          type: SubtitleTrackType.embedded,
        );

        _subtitleTracks.add(track);
        debugPrint('Found subtitle track $i: $trackName (stream index: ${subtitleStream.index})');
      }

      _activeSubtitleTrack = _subtitleTracks.first;
      _lastSelectedSubtitleTrack = _subtitleTracks.first;
      _subtitleEnabled = true;

      videoController.setSubtitleTracks([0]);
      debugPrint('Set default active subtitle track: ${_subtitleTracks.first.name}');

      debugPrint('Loaded ${_subtitleTracks.length} embedded subtitle tracks');
      _notifySubtitleStateChanged();
    } catch (e) {
      debugPrint('Error loading embedded subtitles: $e');
    }
  }

  String _getLanguageNameFromCode(String langCode) {
    final langMap = {
      'zh': '中文',
      'chi': '中文',
      'zho': '中文',
      'cn': '中文',
      'en': 'English',
      'eng': 'English',
      'ja': '日本語',
      'jpn': '日本語',
      'ko': '한국어',
      'kor': '한국어',
      'es': 'Español',
      'spa': 'Español',
      'fr': 'Français',
      'fre': 'Français',
      'de': 'Deutsch',
      'ger': 'Deutsch',
      'ru': 'Русский',
      'rus': 'Русский',
      'ar': 'العربية',
      'ara': 'العربية',
      'pt': 'Português',
      'por': 'Português',
      'it': 'Italiano',
      'ita': 'Italiano',
    };
    
    return langMap[langCode.toLowerCase()] ?? '字幕';
  }

  Future<void> selectSubtitleTrack(SubtitleTrack? track) async {
    debugPrint('[CONTROLLER] selectSubtitleTrack called, track: ${track?.name}');
    if (track == null) {
      debugPrint('[CONTROLLER] Track is null, turning off subtitle');
      _lastSelectedSubtitleTrack = _activeSubtitleTrack;
      _subtitleEnabled = false;

      try {
        videoController.setSubtitleTracks([]);
        debugPrint('[CONTROLLER] setSubtitleTracks([]) completed');
      } catch (e) {
        debugPrint('[CONTROLLER] Error in setSubtitleTracks([]): $e');
      }
    } else {
      debugPrint('[CONTROLLER] Track type: ${track.type}');
      if (track.type == SubtitleTrackType.external) {
        debugPrint('[CONTROLLER] External subtitle, path: ${track.path}');
        try {
          videoController.setExternalSubtitle(track.path!);
          debugPrint('[CONTROLLER] setExternalSubtitle completed');
          _hasActiveExternalSubtitle = true;

          await Future.delayed(const Duration(milliseconds: 300));

          final embeddedCount = _subtitleTracks.where((t) => t.type == SubtitleTrackType.embedded).length;
          debugPrint('[CONTROLLER] Activating external subtitle track at index $embeddedCount');
          videoController.setSubtitleTracks([embeddedCount]);

          _activeSubtitleTrack = track;
          _lastSelectedSubtitleTrack = track;
          _subtitleEnabled = true;
          debugPrint('Selected external subtitle: ${track.name}');
        } catch (e) {
          debugPrint('[CONTROLLER] Error in setExternalSubtitle: $e');
          _activeSubtitleTrack = track;
          _lastSelectedSubtitleTrack = track;
          _subtitleEnabled = true;
        }
      } else {
        debugPrint('[CONTROLLER] Embedded subtitle track, id: ${track.id}');
        try {
          if (_hasActiveExternalSubtitle) {
            debugPrint('[CONTROLLER] Clearing external subtitle first');
            videoController.setExternalSubtitle('');
            debugPrint('[CONTROLLER] External subtitle cleared');
            _hasActiveExternalSubtitle = false;
          }

          videoController.setSubtitleTracks([track.id]);
          debugPrint('[CONTROLLER] setSubtitleTracks([${track.id}]) completed');

          _activeSubtitleTrack = track;
          _lastSelectedSubtitleTrack = track;
          _subtitleEnabled = true;
          debugPrint('Selected embedded subtitle track: ${track.id} - ${track.name}');
        } catch (e) {
          debugPrint('[CONTROLLER] Error in embedded subtitle selection: $e');
          _activeSubtitleTrack = track;
          _lastSelectedSubtitleTrack = track;
          _subtitleEnabled = true;
        }
      }
    }
    debugPrint('[CONTROLLER] selectSubtitleTrack completed');
    _notifySubtitleStateChanged();
  }
  
  Future<void> _executeWithTimeout(Future<void> Function() operation, Duration timeout) async {
    await Future.any([
      operation(),
      Future.delayed(timeout, () {
        throw TimeoutException('Operation timed out after ${timeout.inSeconds} seconds');
      }),
    ]);
  }

  void removeSubtitleTrack(SubtitleTrack track) {
    if (track.type == SubtitleTrackType.external) {
      _subtitleTracks.remove(track);

      if (_activeSubtitleTrack == track) {
        if (_hasActiveExternalSubtitle) {
          try {
            videoController.setExternalSubtitle('');
          } catch (e) {
            debugPrint('Error clearing external subtitle: $e');
          }
          _hasActiveExternalSubtitle = false;
        }

        final firstEmbedded = _subtitleTracks.firstWhere(
          (t) => t.type == SubtitleTrackType.embedded,
          orElse: () => _subtitleTracks.first,
        );

        _activeSubtitleTrack = firstEmbedded;
        _subtitleEnabled = true;
        videoController.setSubtitleTracks([firstEmbedded.id]);
        debugPrint('Switched to embedded subtitle after deletion: ${firstEmbedded.name}');
      }
      debugPrint('Removed subtitle track: ${track.name}');
      _notifySubtitleStateChanged();
    }
  }

  void removeAllSubtitleTracks() {
    final externalTracks = _subtitleTracks.where((t) => t.type == SubtitleTrackType.external).toList();

    if (externalTracks.isEmpty) {
      debugPrint('No external subtitle tracks to remove');
      return;
    }

    final wasExternalActive = _activeSubtitleTrack?.type == SubtitleTrackType.external;

    _subtitleTracks.removeWhere((t) => t.type == SubtitleTrackType.external);

    if (_hasActiveExternalSubtitle) {
      try {
        videoController.setExternalSubtitle('');
      } catch (e) {
        debugPrint('Error clearing external subtitle: $e');
      }
      _hasActiveExternalSubtitle = false;
    }

    if (wasExternalActive) {
      final firstEmbedded = _subtitleTracks.firstWhere(
        (t) => t.type == SubtitleTrackType.embedded,
        orElse: () => _subtitleTracks.first,
      );

      _activeSubtitleTrack = firstEmbedded;
      _subtitleEnabled = true;
      videoController.setSubtitleTracks([firstEmbedded.id]);
      debugPrint('Switched to embedded subtitle after deleting all externals: ${firstEmbedded.name}');
    }

    debugPrint('Removed ${externalTracks.length} external subtitle tracks');
    _notifySubtitleStateChanged();
  }

  Future<void> toggleSubtitle() async {
    if (!_subtitleEnabled) {
      SubtitleTrack? trackToUse;

      if (_activeSubtitleTrack != null && _subtitleTracks.contains(_activeSubtitleTrack)) {
        trackToUse = _activeSubtitleTrack;
      } else if (_lastSelectedSubtitleTrack != null && _subtitleTracks.contains(_lastSelectedSubtitleTrack)) {
        trackToUse = _lastSelectedSubtitleTrack;
      } else if (_subtitleTracks.isNotEmpty) {
        trackToUse = _subtitleTracks.first;
      }

      if (trackToUse != null) {
        try {
          if (trackToUse.type == SubtitleTrackType.external) {
            videoController.setExternalSubtitle(trackToUse.path!);
            _hasActiveExternalSubtitle = true;

            await Future.delayed(const Duration(milliseconds: 300));

            final embeddedCount = _subtitleTracks.where((t) => t.type == SubtitleTrackType.embedded).length;
            videoController.setSubtitleTracks([embeddedCount]);
          } else {
            if (_hasActiveExternalSubtitle) {
              videoController.setExternalSubtitle('');
              _hasActiveExternalSubtitle = false;
            }
            videoController.setSubtitleTracks([trackToUse.id]);
            debugPrint('Toggled on subtitle using track index: ${trackToUse.id}');
          }
          _subtitleEnabled = true;
          _activeSubtitleTrack = trackToUse;
          debugPrint('Toggled on subtitle: ${trackToUse.name}');
        } catch (e) {
          debugPrint('Error toggling on subtitle: $e');
          _subtitleEnabled = true;
          _activeSubtitleTrack = trackToUse;
        }
      }
    } else {
      _lastSelectedSubtitleTrack = _activeSubtitleTrack;
      _subtitleEnabled = false;

      if (_hasActiveExternalSubtitle) {
        try {
          videoController.setExternalSubtitle('');
        } catch (e) {
          debugPrint('Error clearing external subtitle: $e');
        }
        _hasActiveExternalSubtitle = false;
      }

      try {
        videoController.setSubtitleTracks([]);
        debugPrint('Toggled off subtitle (setSubtitleTracks called)');
      } catch (e) {
        debugPrint('Error toggling off subtitle: $e');
      }
    }
    _notifySubtitleStateChanged();
  }

  Future<void> clearCurrentSubtitle() async {
    _lastSelectedSubtitleTrack = _activeSubtitleTrack;
    _subtitleEnabled = false;

    try {
      videoController.setSubtitleTracks([]);
      debugPrint('Current subtitle cleared (setSubtitleTracks called)');
    } catch (e) {
      debugPrint('Error clearing current subtitle (setSubtitleTracks failed): $e');
    }

    if (_hasActiveExternalSubtitle) {
      try {
        videoController.setExternalSubtitle('');
      } catch (e) {
        debugPrint('Error clearing external subtitle: $e');
      }
      _hasActiveExternalSubtitle = false;
    }
    _notifySubtitleStateChanged();
  }

  void clearSubtitle() {
    _subtitleTracks.removeWhere((t) => t.type == SubtitleTrackType.external);
    _activeSubtitleTrack = null;
    _subtitleEnabled = false;

    if (_hasActiveExternalSubtitle) {
      try {
        videoController.setExternalSubtitle('');
      } catch (e) {
        debugPrint('Error clearing external subtitle: $e');
      }
      _hasActiveExternalSubtitle = false;
    }

    try {
      videoController.setSubtitleTracks([]);
    } catch (e) {
      debugPrint('Error clearing subtitles: $e');
    }
    _notifySubtitleStateChanged();
  }

  // 异步生成缩略图
  Future<void> _generateThumbnailAsync() async {
    if (_disposed || _ref == null) return;
    
    try {
      final thumbnailService = _ref!.read(thumbnailServiceProvider);
      final historyRepo = _ref!.read(historyRepositoryProvider);
      
      // 传递 type 给缩略图服务
      final thumbPath = await thumbnailService.generateThumbnail(
        path, 
        type: ph.MediaType.video,
      );
      
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
    debugPrint('[MyVideoPlayerController] ======== dispose() CALLED ========');
    _disposed = true;
    _ref = null;
    _positionTimer?.cancel();
    
    // 先暂停再释放，确保播放器完全停止
    debugPrint('[MyVideoPlayerController] Pausing before dispose');
    try {
      videoController.pause();
      debugPrint('[MyVideoPlayerController] Paused successfully');
    } catch (e) {
      debugPrint('[MyVideoPlayerController] Error pausing before dispose: $e');
    }
    
    // 移除监听器
    if (_videoControllerListener != null) {
      videoController.removeListener(_videoControllerListener!);
    }
    
    debugPrint('[MyVideoPlayerController] Disposing videoController');
    videoController.dispose();
    debugPrint('[MyVideoPlayerController] ======== dispose() COMPLETED ========');
  }
}