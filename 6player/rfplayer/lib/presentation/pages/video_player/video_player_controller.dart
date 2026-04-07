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
    if (path.startsWith('content://')) {
      debugPrint('[MyVideoPlayerController] Using networkUrl for URI');
      videoController = VideoPlayerController.networkUrl(Uri.parse(path));
    } else {
      debugPrint('[MyVideoPlayerController] Using file for path');
      videoController = VideoPlayerController.file(File(path));
    }
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

    debugPrint('[MyVideoPlayerController] Calling videoController.play()');
    videoController.play();
    
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
    debugPrint('[MyVideoPlayerController] play() called from PlayerService');
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
      // 延迟一点时间，确保视频完全加载
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (_disposed) return;
      
      debugPrint('Checking for embedded subtitles using FVP MediaInfo...');
      
      // 使用 FVP 的 getMediaInfo() 获取媒体信息
      final mediaInfo = videoController.getMediaInfo();
      
      // 只有在 mediaInfo 和 subtitle 都不为 null 的情况下才继续
      if (mediaInfo == null || mediaInfo.subtitle == null || mediaInfo.subtitle!.isEmpty) {
        debugPrint('No subtitle tracks found in media info, skipping subtitle processing');
        return;
      }
      
      debugPrint('Found ${mediaInfo.subtitle!.length} subtitle tracks');
      
      for (int i = 0; i < mediaInfo.subtitle!.length; i++) {
        final subtitleStream = mediaInfo.subtitle![i];
        final index = subtitleStream.index;
        
        String trackName;
        String? trackLanguage;
        
        // 尝试从 metadata 中获取语言信息
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
          id: index,
          name: trackName,
          language: trackLanguage,
          type: SubtitleTrackType.embedded,
        );
        
        _subtitleTracks.add(track);
        debugPrint('Found subtitle track $index: $trackName');
      }
      
      // 获取当前活跃的字幕轨道
      try {
        final activeTracks = videoController.getActiveSubtitleTracks();
        debugPrint('Initial active subtitle tracks: $activeTracks');
        
        // 如果有活跃轨道，找到对应的 SubtitleTrack
        if (activeTracks != null && activeTracks.isNotEmpty) {
          final activeId = activeTracks.first;
          final activeTrack = _subtitleTracks.firstWhere(
            (t) => t.id == activeId,
            orElse: () => _subtitleTracks.first,
          );
          _activeSubtitleTrack = activeTrack;
          _lastSelectedSubtitleTrack = activeTrack;
          _subtitleEnabled = true;
          debugPrint('Default active subtitle track: ${activeTrack.id} - ${activeTrack.name}');
        } else {
          // 没有活跃轨道，默认选择第一个轨道
          final firstTrack = _subtitleTracks.first;
          _activeSubtitleTrack = firstTrack;
          _lastSelectedSubtitleTrack = firstTrack;
          _subtitleEnabled = true;
          debugPrint('No active tracks found, using first track: ${firstTrack.id} - ${firstTrack.name}');
        }
        
        // 显式设置字幕轨道，确保字幕显示
        if (_activeSubtitleTrack != null) {
          final trackIndex = _subtitleTracks.indexWhere((t) => t.id == _activeSubtitleTrack!.id);
          if (trackIndex >= 0) {
            videoController.setSubtitleTracks([trackIndex]);
            debugPrint('Explicitly set subtitle track: $trackIndex');
          } else {
            videoController.setSubtitleTracks([_activeSubtitleTrack!.id]);
            debugPrint('Explicitly set subtitle track using media info index: ${_activeSubtitleTrack!.id}');
          }
        }
      } catch (e) {
        debugPrint('Error getting initial active subtitle tracks: $e');
        // 出错时也尝试设置第一个轨道
        if (_subtitleTracks.isNotEmpty) {
          final firstTrack = _subtitleTracks.first;
          _activeSubtitleTrack = firstTrack;
          _lastSelectedSubtitleTrack = firstTrack;
          _subtitleEnabled = true;
          try {
            final trackIndex = _subtitleTracks.indexWhere((t) => t.id == firstTrack.id);
            if (trackIndex >= 0) {
              videoController.setSubtitleTracks([trackIndex]);
            } else {
              videoController.setSubtitleTracks([firstTrack.id]);
            }
            debugPrint('Set first subtitle track as fallback');
          } catch (e2) {
            debugPrint('Error setting fallback subtitle track: $e2');
          }
        }
      }
      
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
      // 选择无字幕 - 小心调用 API，避免卡住
      _lastSelectedSubtitleTrack = _activeSubtitleTrack;
      _subtitleEnabled = false;
      // 注意：不设置 _activeSubtitleTrack = null，保持轨道选择
      
      try {
        debugPrint('[CONTROLLER] Calling setSubtitleTracks([])');
        // 尝试调用 setSubtitleTracks([])，但加 try-catch
        videoController.setSubtitleTracks([]);
        debugPrint('[CONTROLLER] setSubtitleTracks([]) completed');
        debugPrint('Subtitle turned off (setSubtitleTracks called)');
      } catch (e) {
        debugPrint('[CONTROLLER] Error in setSubtitleTracks([]): $e');
        debugPrint('Error turning off subtitle (setSubtitleTracks failed): $e');
        // 如果失败，只更新 UI 状态
      }
    } else {
      debugPrint('[CONTROLLER] Track type: ${track.type}');
      if (track.type == SubtitleTrackType.external) {
        debugPrint('[CONTROLLER] External subtitle, path: ${track.path}');
        // 外部字幕文件，支持 content:// URI
        try {
          debugPrint('[CONTROLLER] Calling setExternalSubtitle');
          videoController.setExternalSubtitle(track.path!);
          debugPrint('[CONTROLLER] setExternalSubtitle completed');
          _activeSubtitleTrack = track;
          _lastSelectedSubtitleTrack = track;
          _subtitleEnabled = true;
          _hasActiveExternalSubtitle = true; // 标记在用外挂字幕
          debugPrint('Selected external subtitle: ${track.name}');
        } catch (e) {
          debugPrint('[CONTROLLER] Error in setExternalSubtitle: $e');
          debugPrint('Error setting external subtitle: $e');
          _activeSubtitleTrack = track;
          _lastSelectedSubtitleTrack = track;
          _subtitleEnabled = true;
        }
      } else {
        debugPrint('[CONTROLLER] Embedded subtitle track');
        // 内置字幕轨道
        try {
          // 只有当前在用外挂字幕时才清空
          if (_hasActiveExternalSubtitle) {
            debugPrint('[CONTROLLER] Clearing external subtitle first');
            videoController.setExternalSubtitle('');
            debugPrint('[CONTROLLER] External subtitle cleared');
            _hasActiveExternalSubtitle = false; // 标记不再用外挂字幕
          }
          
          // 关键：使用轨道在列表中的索引（从 0 开始），而不是 MediaInfo 中的索引
          // 因为 FVP 的 setSubtitleTracks 需要的是从 0 开始的索引
          final trackIndex = _subtitleTracks.indexWhere((t) => t.id == track.id);
          
          debugPrint('Setting subtitle track: listIndex=$trackIndex, mediaInfoIndex=${track.id}');
          
          if (trackIndex >= 0) {
            debugPrint('[CONTROLLER] Calling setSubtitleTracks([$trackIndex])');
            videoController.setSubtitleTracks([trackIndex]);
            debugPrint('[CONTROLLER] setSubtitleTracks completed');
            debugPrint('Set subtitle track using list index: $trackIndex');
          } else {
            debugPrint('[CONTROLLER] Calling setSubtitleTracks([${track.id}])');
            // 如果找不到，回退到尝试使用 mediaInfo 索引
            videoController.setSubtitleTracks([track.id]);
            debugPrint('[CONTROLLER] setSubtitleTracks completed');
            debugPrint('Set subtitle track using media info index: ${track.id}');
          }
          
          _activeSubtitleTrack = track;
          _lastSelectedSubtitleTrack = track;
          _subtitleEnabled = true;
          debugPrint('Selected embedded subtitle track: ${track.id} - ${track.name}');
        } catch (e) {
          debugPrint('[CONTROLLER] Error in embedded subtitle selection: $e');
          debugPrint('Error selecting embedded subtitle track: $e');
          // 即使出错，也更新状态
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
      
      // 如果删除的是当前激活的轨道，切换到第一个可用的内置字幕
      if (_activeSubtitleTrack == track) {
        // 清空外挂字幕
        if (_hasActiveExternalSubtitle) {
          try {
            videoController.setExternalSubtitle('');
          } catch (e) {
            debugPrint('Error clearing external subtitle: $e');
          }
          _hasActiveExternalSubtitle = false;
        }
        
        // 找到第一个内置字幕，设为当前激活
        final firstEmbedded = _subtitleTracks.firstWhere(
          (t) => t.type == SubtitleTrackType.embedded,
          orElse: () => _subtitleTracks.first,
        );
        
        if (firstEmbedded != null) {
          _activeSubtitleTrack = firstEmbedded;
          _subtitleEnabled = true;
          // 激活内置字幕
          final trackIndex = _subtitleTracks.indexWhere((t) => t.id == firstEmbedded.id);
          if (trackIndex >= 0) {
            videoController.setSubtitleTracks([trackIndex]);
          } else {
            videoController.setSubtitleTracks([firstEmbedded.id]);
          }
          debugPrint('Switched to embedded subtitle after deletion: ${firstEmbedded.name}');
        } else {
          _activeSubtitleTrack = null;
          _subtitleEnabled = false;
        }
      }
      debugPrint('Removed subtitle track: ${track.name}');
      _notifySubtitleStateChanged();
    }
  }

  void removeAllSubtitleTracks() {
    // 获取所有外挂字幕
    final externalTracks = _subtitleTracks.where((t) => t.type == SubtitleTrackType.external).toList();
    
    if (externalTracks.isEmpty) {
      debugPrint('No external subtitle tracks to remove');
      return;
    }
    
    // 检查当前激活的是否是外挂字幕
    final wasExternalActive = _activeSubtitleTrack?.type == SubtitleTrackType.external;
    
    // 移除所有外挂字幕
    _subtitleTracks.removeWhere((t) => t.type == SubtitleTrackType.external);
    
    // 清空外挂字幕
    if (_hasActiveExternalSubtitle) {
      try {
        videoController.setExternalSubtitle('');
      } catch (e) {
        debugPrint('Error clearing external subtitle: $e');
      }
      _hasActiveExternalSubtitle = false;
    }
    
    // 如果之前激活的是外挂字幕，切换到第一个可用的内置字幕
    if (wasExternalActive) {
      final firstEmbedded = _subtitleTracks.firstWhere(
        (t) => t.type == SubtitleTrackType.embedded,
        orElse: () => _subtitleTracks.first,
      );
      
      if (firstEmbedded != null) {
        _activeSubtitleTrack = firstEmbedded;
        _subtitleEnabled = true;
        // 激活内置字幕
        final trackIndex = _subtitleTracks.indexWhere((t) => t.id == firstEmbedded.id);
        if (trackIndex >= 0) {
          videoController.setSubtitleTracks([trackIndex]);
        } else {
          videoController.setSubtitleTracks([firstEmbedded.id]);
        }
        debugPrint('Switched to embedded subtitle after deleting all externals: ${firstEmbedded.name}');
      } else {
        _activeSubtitleTrack = null;
        _subtitleEnabled = false;
      }
    }
    
    debugPrint('Removed ${externalTracks.length} external subtitle tracks');
    _notifySubtitleStateChanged();
  }

  Future<void> toggleSubtitle() async {
    if (!_subtitleEnabled) {
      // 打开字幕 - 确保使用正确的轨道
      SubtitleTrack? trackToUse;
      
      // 优先用当前激活的轨道，如果是已删除的外挂字幕则跳过
      if (_activeSubtitleTrack != null && _subtitleTracks.contains(_activeSubtitleTrack)) {
        trackToUse = _activeSubtitleTrack;
      } else if (_lastSelectedSubtitleTrack != null && _subtitleTracks.contains(_lastSelectedSubtitleTrack)) {
        trackToUse = _lastSelectedSubtitleTrack;
      } else if (_subtitleTracks.isNotEmpty) {
        trackToUse = _subtitleTracks.first;
      }
      
      if (trackToUse != null) {
        // 直接设置字幕轨道，不通过 selectSubtitleTrack 来避免额外处理
        try {
          if (trackToUse.type == SubtitleTrackType.external) {
            // 外部字幕，支持 content:// URI
            videoController.setExternalSubtitle(trackToUse.path!);
            _hasActiveExternalSubtitle = true;
          } else {
            // 只有当前在用外挂字幕时才清空
            if (_hasActiveExternalSubtitle) {
              videoController.setExternalSubtitle('');
              _hasActiveExternalSubtitle = false;
            }
            final trackIndex = _subtitleTracks.indexWhere((t) => t.id == trackToUse!.id);
            if (trackIndex >= 0) {
              videoController.setSubtitleTracks([trackIndex]);
              debugPrint('Toggled on subtitle using list index: $trackIndex');
            } else {
              videoController.setSubtitleTracks([trackToUse.id]);
              debugPrint('Toggled on subtitle using media info index: ${trackToUse.id}');
            }
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
      // 关闭字幕 - 小心调用 API
      _lastSelectedSubtitleTrack = _activeSubtitleTrack;
      _subtitleEnabled = false;
      
      // 如果当前在用外挂字幕，也要清空
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
    // 清除当前字幕 - 小心调用 API，避免卡住
    _lastSelectedSubtitleTrack = _activeSubtitleTrack;
    _subtitleEnabled = false;
    // 注意：不设置 _activeSubtitleTrack = null，保持轨道选择
    
    try {
      // 尝试调用 setSubtitleTracks([])，但加 try-catch
      videoController.setSubtitleTracks([]);
      debugPrint('Current subtitle cleared (setSubtitleTracks called)');
    } catch (e) {
      debugPrint('Error clearing current subtitle (setSubtitleTracks failed): $e');
      // 如果失败，只更新 UI 状态
    }
    
    // 清除外挂字幕标记
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
    // 只保留内置字幕轨道，移除外部字幕
    _subtitleTracks.removeWhere((t) => t.type == SubtitleTrackType.external);
    _activeSubtitleTrack = null;
    _subtitleEnabled = false;
    
    // 清除外挂字幕标记
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