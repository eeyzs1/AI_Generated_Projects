import 'dart:collection';
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:fast_file_picker/fast_file_picker.dart';
import 'package:file_selector/file_selector.dart';
import '../../../core/utils/toast_utils.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/constants/supported_formats.dart';
import '../../../data/models/subtitle_track.dart';

import 'speed_control.dart';
import '../../../presentation/providers/database_provider.dart';
import '../../../presentation/providers/settings_provider.dart';
import '../../../presentation/providers/play_queue_provider.dart';
import '../../../presentation/providers/video_bookmark_provider.dart';
import '../../../presentation/providers/volume_provider.dart';
import 'widgets/windows_play_list_panel.dart';
import 'widgets/android_play_list_drawer.dart';
import 'package:path/path.dart' as p;
import '../../../data/services/player_service.dart';

// 字幕菜单组件，独立 StatefulWidget
class SubtitleMenu extends ConsumerStatefulWidget {
  final GlobalKey subtitleButtonKey;
  final VoidCallback onClose;
  final VoidCallback onAddSubtitle;
  final Function(SubtitleTrack) onSelectSubtitle;
  final VoidCallback onToggleSubtitle;
  final VoidCallback onClearSubtitle;
  final Function(SubtitleTrack) onRemoveSubtitle;

  const SubtitleMenu({
    super.key,
    required this.subtitleButtonKey,
    required this.onClose,
    required this.onAddSubtitle,
    required this.onSelectSubtitle,
    required this.onToggleSubtitle,
    required this.onClearSubtitle,
    required this.onRemoveSubtitle,
  });

  @override
  ConsumerState<SubtitleMenu> createState() => _SubtitleMenuState();
}

class _SubtitleMenuState extends ConsumerState<SubtitleMenu> {
  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final screenSize = MediaQuery.of(context).size;
    final isLandscape = screenSize.width > screenSize.height;
    final menuMaxHeight = screenSize.height * (Platform.isAndroid 
        ? (isLandscape ? 0.55 : 0.4) 
        : 0.5);
    final menuMaxWidth = (screenSize.width * (Platform.isAndroid 
        ? (isLandscape ? 0.20 : 0.35) 
        : 0.3)).clamp(Platform.isAndroid 
        ? (isLandscape ? 180.0 : 160.0) 
        : 240.0, double.infinity);
    final menuMinWidth = Platform.isAndroid 
        ? (isLandscape ? 180.0 : 160.0) 
        : 240.0;
    
    return Container(
      constraints: BoxConstraints(
        maxHeight: menuMaxHeight,
        maxWidth: menuMaxWidth,
        minWidth: menuMinWidth,
      ),
      decoration: BoxDecoration(
        color: Colors.grey[900]!.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 10,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
              Container(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.grey[800]!)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Text(
                      loc.subtitleSettings,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: Platform.isAndroid ? 14 : 18,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Consumer(
                  builder: (context, ref, child) {
                    final playerService = ref.watch(playerServiceProvider);
                    final controller = playerService.controller;
                    final subtitleTracks = controller?.subtitleTracks ?? [];
                    final activeTrack = controller?.activeSubtitleTrack;
                    final subtitleEnabled = controller?.subtitleEnabled ?? false;
                    final hasSubtitle = subtitleTracks.isNotEmpty;

                    return SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ListTile(
                            leading: const Icon(Icons.add_circle_outline, color: Colors.white, size: 20),
                            title: Text(
                              loc.selectSubtitleFile,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: Platform.isAndroid ? 12 : 16,
                              ),
                            ),
                            onTap: () {
                              widget.onAddSubtitle();
                            },
                          ),
                          Divider(color: Colors.grey[800], height: 1),
                          
                          if (hasSubtitle) ...[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                              child: Text(
                                loc.selectSubtitle,
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: Platform.isAndroid ? 11 : 14,
                                ),
                              ),
                            ),
                            ...subtitleTracks.map((track) {
                              final isActive = activeTrack?.id == track.id && subtitleEnabled;
                              return ListTile(
                                leading: Icon(
                                  isActive ? Icons.check_circle : Icons.radio_button_unchecked,
                                  color: isActive ? Colors.blue : Colors.grey[400],
                                  size: 20,
                                ),
                                title: Text(
                                  track.name,
                                  style: TextStyle(
                                    color: isActive ? Colors.blue : Colors.white,
                                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                                    fontSize: Platform.isAndroid ? 12 : 16,
                                  ),
                                ),
                                subtitle: Text(
                                  track.type == SubtitleTrackType.external 
                                      ? loc.externalSubtitle 
                                      : loc.embeddedSubtitle,
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: Platform.isAndroid ? 10 : 14,
                                  ),
                                ),
                                trailing: track.type == SubtitleTrackType.external
                                    ? IconButton(
                                        icon: const Icon(Icons.delete_outline, color: Colors.grey),
                                        iconSize: 20,
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onPressed: () {
                                          widget.onRemoveSubtitle(track);
                                        },
                                      )
                                    : null,
                                onTap: () {
                                  widget.onSelectSubtitle(track);
                                },
                              );
                            }),
                            Divider(color: Colors.grey[800], height: 1),
                          ],
                          
                          ListTile(
                            leading: Icon(
                              subtitleEnabled ? Icons.visibility : Icons.visibility_off,
                              color: Colors.white,
                              size: 20,
                            ),
                            title: Text(
                              subtitleEnabled ? loc.turnOffSubtitle : loc.turnOnSubtitle,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: Platform.isAndroid ? 12 : 16,
                              ),
                            ),
                            onTap: () {
                              widget.onToggleSubtitle();
                            },
                          ),
                          Divider(color: Colors.grey[800], height: 1),
                          
                          if (hasSubtitle) ...[
                            ListTile(
                              leading: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                              title: Text(
                                // 如果有外挂字幕，显示删除所有字幕文件；否则显示不显示字幕
                                subtitleTracks.any((t) => t.type == SubtitleTrackType.external)
                                    ? loc.deleteAllSubtitleFiles 
                                    : loc.hideSubtitle,
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: Platform.isAndroid ? 12 : 16,
                                ),
                              ),
                              onTap: () {
                                widget.onClearSubtitle();
                              },
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
    );
  }
}

// 音量控制组件
class VolumeControl extends ConsumerStatefulWidget {
  final VoidCallback onClose;

  const VolumeControl({
    super.key,
    required this.onClose,
  });

  @override
  ConsumerState<VolumeControl> createState() => _VolumeControlState();
}

class _VolumeControlState extends ConsumerState<VolumeControl> {
  @override
  Widget build(BuildContext context) {
    final volume = ref.watch(volumeProvider);
    final sliderHeight = Platform.isAndroid ? 160.0 : 240.0;

    // 音量滑块 - 终于搞清楚了！
    return SizedBox(
      height: sliderHeight, // 旋转前宽度 → 旋转后高度（纵向，滑块长度）
      width: 50, // 旋转前高度 → 旋转后宽度（横向，黑色背景宽度）
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 2.0),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(4.0),
        ),
        child: RotatedBox(
          quarterTurns: 3,
          child: Slider(
            value: volume,
            min: 0.0,
            max: 1.0,
            divisions: 100,
            onChanged: (newVolume) {
              ref.read(volumeProvider.notifier).state = newVolume;
              final clampedVolume = newVolume.clamp(0.0, 1.0);
              final playerService = ref.read(playerServiceProvider);
              if (playerService.isInitialized && playerService.controller != null) {
                playerService.controller!.setVolume(clampedVolume);
              }
            },
            activeColor: Colors.blue,
            inactiveColor: Colors.grey[700],
          ),
        ),
      ),
    );
  }
}

class VideoPlayerPage extends ConsumerStatefulWidget {
  final String path;
  final Duration? initialPosition;
  final String? fileName;

  const VideoPlayerPage({super.key, required this.path, this.initialPosition, this.fileName});

  @override
  ConsumerState<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends ConsumerState<VideoPlayerPage> {
  bool _isInitialized = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isPlaying = false;
  double _volume = 1.0;
  double _playbackSpeed = 1.0;
  bool _showSpeedControl = false;
  bool _showVolumeControl = false;
  bool _isAppBarVisible = true;
  bool _showPlayListDrawer = false;
  bool _showPlayListPanel = true; // Windows端播放列表面板显示状态
  bool _showSubtitleMenu = false; // 字幕菜单显示状态
  String? _currentFileName;
  final GlobalKey _subtitleButtonKey = GlobalKey(); // 字幕按钮位置跟踪
  final GlobalKey _subtitleMenuKey = GlobalKey(); // 字幕菜单组件 Key
  final LayerLink _subtitleLayerLink = LayerLink(); // 字幕菜单层连接
  SubtitleMenu? _cachedSubtitleMenu; // 缓存的字幕菜单组件
  
  // 音量控制相关
  final GlobalKey _volumeButtonKey = GlobalKey(); // 音量按钮位置跟踪
  final GlobalKey _volumeControlKey = GlobalKey(); // 音量控制组件 Key
  final LayerLink _volumeLayerLink = LayerLink(); // 音量控制层连接
  VolumeControl? _cachedVolumeControl; // 缓存的音量控制组件
  
  // 播放列表相关
  final GlobalKey _playListPanelKey = GlobalKey(); // Windows播放列表面板 Key
  final GlobalKey _playListDrawerKey = GlobalKey(); // Android播放列表抽屉 Key
  WindowsPlayListPanel? _cachedWindowsPlayListPanel; // 缓存的Windows播放列表面板
  AndroidPlayListDrawer? _cachedAndroidPlayListDrawer; // 缓存的Android播放列表抽屉
  late FocusNode _focusNode;
  late FocusAttachment _focusAttachment;
  bool _isUpdateLoopRunning = false;
  bool _isDisposing = false;
  
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  // 操作队列，确保一次只执行一个播放器操作
  bool _isProcessing = false;
  final Queue<Future<void> Function()> _operationQueue = Queue();

  // 进度条交互状态
  bool _isSliderDragging = false;
  bool _wasPlayingBeforeDrag = false;
  // 字幕防重复：是否有字幕操作正在队列中
  bool _hasPendingSubtitleOperation = false;
  // 播放完成状态
  bool _isCompleted = false;
  
  // 防抖和节流相关
  Timer? _debounceTimer;
  Timer? _subtitleDebounceTimer;
  DateTime? _lastSeekTime;
  static const Duration _debounceDuration = Duration(milliseconds: 200);
  static const Duration _throttleDuration = Duration(milliseconds: 300);
  static const Duration _subtitleDebounceDuration = Duration(milliseconds: 200);
  static const Duration _subtitleDebounceReduction = Duration(milliseconds: 100);
  static const Duration _subtitleWaitDuration = Duration(milliseconds: 100);

  @override
  void initState() {
    super.initState();
    
    // 初始化当前文件名
    _currentFileName = widget.fileName;
    
    _focusNode = FocusNode(debugLabel: 'VideoPlayerFocusNode');
    _focusAttachment = _focusNode.attach(context, onKeyEvent: (node, event) {
      _handleKey(event);
      return KeyEventResult.handled;
    });

    // 延迟初始化播放器，确保页面已经完全构建
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
        _focusAttachment.reparent();
        _initializePlayer();
      }
    });
  }

  // 获取缓存的字幕菜单，只创建一次
  SubtitleMenu _getSubtitleMenu() {
    if (_cachedSubtitleMenu == null) {
      _cachedSubtitleMenu = SubtitleMenu(
        key: _subtitleMenuKey,
        subtitleButtonKey: _subtitleButtonKey,
        onClose: _onSubtitleMenuClose,
        onAddSubtitle: _onAddSubtitle,
        onSelectSubtitle: _onSelectSubtitle,
        onToggleSubtitle: _onToggleSubtitle,
        onClearSubtitle: _onClearSubtitle,
        onRemoveSubtitle: _onRemoveSubtitle,
      );
    }
    return _cachedSubtitleMenu!;
  }

  // 获取缓存的音量控制，只创建一次
  VolumeControl _getVolumeControl() {
    if (_cachedVolumeControl == null) {
      _cachedVolumeControl = VolumeControl(
        key: _volumeControlKey,
        onClose: () => setState(() => _showVolumeControl = false),
      );
    }
    return _cachedVolumeControl!;
  }

  // 获取缓存的Windows播放列表面板，只创建一次
  WindowsPlayListPanel _getWindowsPlayListPanel() {
    if (_cachedWindowsPlayListPanel == null) {
      _cachedWindowsPlayListPanel = WindowsPlayListPanel(
        key: _playListPanelKey,
        onNavigateBack: _handleBackPress,
      );
    }
    return _cachedWindowsPlayListPanel!;
  }

  // 获取缓存的Android播放列表抽屉，只创建一次
  AndroidPlayListDrawer _getAndroidPlayListDrawer() {
    if (_cachedAndroidPlayListDrawer == null) {
      _cachedAndroidPlayListDrawer = AndroidPlayListDrawer(
        key: _playListDrawerKey,
        onClose: () {
          setState(() {
            _showPlayListDrawer = false;
          });
        },
        onNavigateBack: _handleBackPress,
      );
    }
    return _cachedAndroidPlayListDrawer!;
  }

  @override
  void dispose() {
    _focusAttachment.detach();
    _focusNode.dispose();
    _debounceTimer?.cancel();
    _subtitleDebounceTimer?.cancel();
    
    // 不要在这里调用 _controller.dispose()，因为播放器服务会处理
    super.dispose();
  }
  
  // 处理返回按钮点击
  Future<void> _handleBackPress() async {
    // 设置正在销毁标志，防止继续访问播放器
    setState(() {
      _isDisposing = true;
    });
    
    // 1. 停止播放器
    final playerService = ref.read(playerServiceProvider);
    if (playerService.isInitialized) {
      playerService.pause();
    }
    
    // 2. 直接更新 history 和 play queue
    if (playerService.isInitialized && playerService.controller != null) {
      try {
        final position = playerService.controller!.position;
        final duration = playerService.controller!.duration;
        
        // 更新历史记录
        final historyRepo = ref.read(historyRepositoryProvider);
        await historyRepo.updatePosition(widget.path, position);
        
        // 更新播放队列中的播放进度
        if (duration != Duration.zero) {
          final progress = position.inMilliseconds / duration.inMilliseconds;
          final playQueueService = ref.read(playQueueServiceProvider);
          final currentPlaying = await playQueueService.getCurrentPlaying();
          if (currentPlaying != null && currentPlaying.path == widget.path) {
            await playQueueService.updatePlayProgress(currentPlaying.id, progress);
          }
        }
      } catch (e) {
        debugPrint('Error updating data on back press: $e');
      }
    }
    
    // 3. 停止所有异步操作，确保不会在widget销毁后继续执行
    playerService.stopAsyncOperations();
    
    // 4. 执行返回操作
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  // 处理播放队列变化
  Future<void> _handlePlayQueueChange() async {
    if (!mounted) return;
    
    try {
      final playQueueService = ref.read(playQueueServiceProvider);
      final currentPlaying = await playQueueService.getCurrentPlaying();
      final queue = await playQueueService.getQueue();
      
      if (!mounted) return;
      
      if (queue.isEmpty) {
        // 如果队列清空，暂停播放
        final playerService = ref.read(playerServiceProvider);
        if (playerService.isInitialized && playerService.controller!.isPlaying) {
          playerService.pause();
        }
        if (mounted) {
          setState(() {
            _isInitialized = false;
          });
        }
        return;
      }
      
      if (currentPlaying != null) {
        // 如果当前播放项发生变化，重新初始化播放器
        setState(() {
          _isInitialized = false;
        });
        
        // 使用播放器服务初始化播放器
        final playerService = ref.read(playerServiceProvider);
        final newFileName = currentPlaying.displayName;
        debugPrint('[VideoPlayerPage] _handlePlayQueueChange: initializing with fileName: $newFileName');
        await playerService.initialize(currentPlaying.path, ref, fileName: newFileName);
        playerService.setPlaybackSpeed(_playbackSpeed);
        debugPrint('[VideoPlayerPage] _handlePlayQueueChange: calling play()');
        playerService.play();
        
        // 更新当前文件名
        if (mounted) {
          setState(() {
            _currentFileName = newFileName;
            _isInitialized = true;
          });
          _updatePlayerState();
        }
      }
    } catch (e, stackTrace) {
      debugPrint('Error handling play queue change: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  Future<void> _initializePlayer() async {
    if (!mounted) return;
    
    try {
      final settings = ref.read(settingsProvider);
      _playbackSpeed = settings.defaultPlaybackSpeed;

      final playQueueNotifier = ref.read(playQueueProvider.notifier);
      final playQueueService = ref.read(playQueueServiceProvider);
      
      // 先检查播放队列中是否已有该视频
      final queue = await playQueueService.getQueue();
      final bool videoExists = queue.any((item) => item.path == widget.path);
      
      if (videoExists) {
        // 如果队列中已有该视频，直接使用它
        final existingItem = queue.firstWhere((item) => item.path == widget.path);
        await playQueueNotifier.playItem(existingItem.id);
      } else {
        // 如果队列中没有该视频，则添加到队列
        try {
          await playQueueNotifier.addToQueue(widget.path, widget.fileName ?? p.basename(widget.path));
          // 设置当前播放项为新添加的视频
          final updatedQueue = await playQueueService.getQueue();
          // 安全地查找刚添加的项目
          final newlyAddedItem = updatedQueue.firstWhere(
            (item) => item.path == widget.path,
            orElse: () => updatedQueue.isNotEmpty ? updatedQueue[0] : (() { throw StateError("Queue is empty after adding item"); })(),
          );
          await playQueueNotifier.playItem(newlyAddedItem.id);
        } catch (e) {
          debugPrint('Error adding video to queue: $e');
        }
      }
      
      if (!mounted) return;
      
      // 获取当前播放项
      final currentPlaying = await playQueueService.getCurrentPlaying();
      if (currentPlaying == null) {
        if (mounted) {
          setState(() {
            _isInitialized = false;
          });
        }
        return;
      }
      
      if (!mounted) return;
      
      // 设置当前文件名 - 先保存到本地变量，然后使用
      final newFileName = currentPlaying.displayName;
      
      // 使用播放器服务初始化播放器
      final playerService = ref.read(playerServiceProvider);
      debugPrint('[VideoPlayerPage] _initializePlayer: initializing with fileName: $newFileName');
      await playerService.initialize(currentPlaying.path, ref, fileName: newFileName);
      
      // 更新 state 中的文件名
      if (mounted) {
        setState(() {
          _currentFileName = newFileName;
        });
      }
      playerService.setPlaybackSpeed(_playbackSpeed);

      // 如果有初始位置，跳转到该位置
      if (widget.initialPosition != null) {
        playerService.seek(widget.initialPosition!);
      }
      
      // 开始播放
      debugPrint('[VideoPlayerPage] _initializePlayer: calling play()');
      playerService.play();

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
      _updatePlayerState();
    } catch (e, stackTrace) {
      debugPrint('Error initializing player: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _isInitialized = false;
        });
      }
    }
  }

  Future<void> _updatePlayerState() async {
    if (_isUpdateLoopRunning) return;
    _isUpdateLoopRunning = true;
    
    while (mounted && !_isDisposing) {
      try {
        if (!_isSliderDragging && mounted && !_isDisposing) {
          final playerService = ref.read(playerServiceProvider);
          if (playerService.isInitialized && playerService.controller != null && !_isDisposing) {
            try {
              final position = playerService.controller!.position;
              final duration = playerService.controller!.duration;
              final isPlaying = playerService.controller!.isPlaying;
              final completed = duration.inMilliseconds > 0 &&
                  position.inMilliseconds >= duration.inMilliseconds * 0.99 &&
                  !isPlaying;

              if (mounted && !_isDisposing) {
                setState(() {
                  _position = position;
                  _duration = duration;
                  _isPlaying = isPlaying;
                  _isCompleted = completed;
                });
              }
            } catch (e) {
              debugPrint('Error getting player state: $e');
            }
          }
        }
      } catch (e) {
        debugPrint('Error updating player state: $e');
      }

      if (!mounted || _isDisposing) break;
      await Future.delayed(const Duration(milliseconds: 300));
    }
    
    _isUpdateLoopRunning = false;
  }

  // 操作队列处理
  Future<void> _processQueue() async {
    if (!mounted) return;
    if (_isProcessing) return;
    if (_operationQueue.isEmpty) return;

    _isProcessing = true;
    final operation = _operationQueue.removeFirst();
    try {
      if (mounted) await operation();
    } catch (e) {
      // 静默处理错误
    } finally {
      if (mounted) {
        _isProcessing = false;
        _processQueue();
      }
    }
  }

  void _queueOperation(Future<void> Function() operation) {
    if (!mounted) return;
    _operationQueue.add(operation);
    _processQueue();
  }

  // Seek 插队到队列最前面
  void _queueSeekOperation(Future<void> Function() operation) {
    if (!mounted) return;
    _operationQueue.addFirst(operation);
    _processQueue();
  }

  // 字幕操作：防抖 + 检查 seek 状态 + 防重复，进入队列执行
  void _queueSubtitleOperation(Future<void> Function() operation) {
    if (!mounted) return;
    
    // 防重复：如果已有待处理的字幕操作，直接返回
    if (_hasPendingSubtitleOperation) return;
    
    // 取消之前的字幕 timer
    _subtitleDebounceTimer?.cancel();
    
    _executeSubtitleOperation(operation, _subtitleDebounceDuration);
  }
  
  void _executeSubtitleOperation(Future<void> Function() operation, Duration duration) {
    if (!mounted) return;
    
    _subtitleDebounceTimer = Timer(duration, () async {
      if (!mounted) return;
      
      if (_isSliderDragging) {
        // seek 还在进行中，重新计时，使用缩短的时间
        _executeSubtitleOperation(operation, _subtitleDebounceReduction);
      } else {
        // seek 已完成，检查防重复
        if (_hasPendingSubtitleOperation) return;
        
        // 标记有待处理的字幕操作
        _hasPendingSubtitleOperation = true;
        
        // 包裹操作，执行完后重置防重复标记
        final wrappedOperation = () async {
          try {
            await operation();
          } catch (e) {
            // 静默处理错误
          } finally {
            if (mounted) {
              _hasPendingSubtitleOperation = false;
            }
          }
        };
        
        // 插队到队列最前面执行
        _operationQueue.addFirst(wrappedOperation);
        _processQueue();
      }
    });
  }

  void _togglePlayPause() {
    _queueOperation(() async {
      if (!mounted) return;

      final playerService = ref.read(playerServiceProvider);
      if (!playerService.isInitialized || playerService.controller == null) return;

      final isCompleted = _duration.inMilliseconds > 0 &&
          _position.inMilliseconds >= _duration.inMilliseconds * 0.99;

      if (isCompleted) {
        playerService.controller!.seek(Duration.zero);
        if (mounted) playerService.play();
      } else if (_isPlaying) {
        if (mounted) playerService.pause();
      } else {
        if (mounted) playerService.play();
      }
    });
  }

  // ── 进度条回调 ────────────────────────────────────────────────

  void _onSliderChangeStart(double value) {
    _wasPlayingBeforeDrag = _isPlaying;
    _isSliderDragging = true;

    // 暂停视频（如果正在播放）
    if (_isPlaying) {
      _queueOperation(() async {
        if (!mounted) return;
        final playerService = ref.read(playerServiceProvider);
        if (playerService.isInitialized && playerService.controller != null) {
          playerService.pause();
          if (mounted) {
            setState(() { _isPlaying = false; });
          }
        }
      });
    }
  }

  void _onSliderChanged(double value) {
    if (!mounted || !_isSliderDragging) return;
    final newPosition = Duration(
      milliseconds: (value * _duration.inMilliseconds).toInt(),
    );
    setState(() { _position = newPosition; });
  }

  Future<void> _onSliderChangeEnd(double value) async {
    if (!mounted) return;
    final targetPosition = Duration(
      milliseconds: (value * _duration.inMilliseconds).toInt(),
    );

    // 不立即设置 _isSliderDragging = false，保持 true，防止位置更新循环抢在 seek 之前
    setState(() {
      _position = targetPosition;
      _isPlaying = _wasPlayingBeforeDrag;
    });

    // 防抖：取消之前的定时器
    _debounceTimer?.cancel();
    
    // 防抖+节流：延迟执行，确保是最后一次操作，并避免太频繁
    _debounceTimer = Timer(_debounceDuration, () {
      if (!mounted) return;
      
      // 节流：检查是否太频繁
      final now = DateTime.now();
      if (_lastSeekTime != null && now.difference(_lastSeekTime!) < _throttleDuration) {
        return;
      }
      _lastSeekTime = now;
      
      // Seek 插队到队列最前面
      _queueSeekOperation(() async {
        if (!mounted) return;
        final playerService = ref.read(playerServiceProvider);
        if (playerService.isInitialized && playerService.controller != null) {
          playerService.controller!.seek(targetPosition);
          if (_wasPlayingBeforeDrag) {
            playerService.play();
          }
        }
        // Seek 完成后，把 _isSliderDragging 设为 false
        if (mounted) {
          setState(() {
            _isSliderDragging = false;
          });
        }
      });
    });
  }

  // ── 倍速回调 ─────────────────────────────────────────────────

  /// 点击档位或键盘快捷键触发，属于明确的最终值，直接持久化
  void _handleSpeedChangeFinal(double speed) {
    if (!mounted) return;
    // 倍速调整优先级高，直接执行，不通过队列
    final playerService = ref.read(playerServiceProvider);
    if (playerService.isInitialized && playerService.controller != null) {
      playerService.controller!.setPlaybackSpeed(speed);
      setState(() {
        _playbackSpeed = speed;
      });
      _saveSpeedSetting(speed);
    }
  }

  Future<void> _saveSpeedSetting(double speed) async {
    if (!mounted) return;
    try {
      final settings = ref.read(settingsProvider);
      await ref.read(settingsProvider.notifier).update(
            settings.copyWith(defaultPlaybackSpeed: speed),
          );
    } catch (e) {
      debugPrint('Error saving playback speed: $e');
    }
  }

  // ── 音量回调 ─────────────────────────────────────────────────

  void _handleVolumeChange(double volume) {
    final clampedVolume = volume.clamp(0.0, 1.0);
    final playerService = ref.read(playerServiceProvider);
    if (playerService.isInitialized && playerService.controller != null) {
      playerService.controller!.setVolume(clampedVolume);
      ref.read(volumeProvider.notifier).state = clampedVolume;
    }
  }

  void _toggleAppBar() {
    if (!mounted) return;
    setState(() {
      _isAppBarVisible = !_isAppBarVisible;
    });
  }

  void _toggleVolumeControl() {
    if (mounted) {
      setState(() {
        _showVolumeControl = !_showVolumeControl;
      });
    }
  }

  void _toggleSubtitleMenu() {
    if (mounted) {
      setState(() {
        _showSubtitleMenu = !_showSubtitleMenu;
      });
    }
  }

  // ── 字幕功能 ──────────────────────────────────────────────────

  Future<void> _addSubtitle() async {
    final loc = AppLocalizations.of(context)!;
    final playerService = ref.read(playerServiceProvider);
    if (!playerService.isInitialized || playerService.controller == null) return;
    
    // 暂停视频
    final wasPlaying = _isPlaying;
    if (_isPlaying) {
      playerService.pause();
      setState(() { _isPlaying = false; });
    }

    try {
      // 打开文件选择器
      final typeGroup = XTypeGroup(
        label: 'Subtitle Files',
        extensions: subtitleFormats,
      );
      final result = await FastFilePicker.pickFile(
        acceptedTypeGroups: [typeGroup],
      );

      if (result != null) {
        String? subtitlePath;
        if (result.path != null) {
          subtitlePath = result.path;
        } else if (result.uri != null) {
          subtitlePath = result.uri.toString();
        }
        
        if (subtitlePath != null) {
          // 加载字幕
          await playerService.controller!.loadSubtitle(subtitlePath);
          if (mounted) {
            ToastUtils.showToast(context, loc.subtitleAdded);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ToastUtils.showToast(context, loc.addSubtitleFailed);
      }
    } finally {
      // 如果之前是播放状态，恢复播放
      if (wasPlaying && mounted) {
        playerService.play();
        setState(() { _isPlaying = true; });
      }
    }
  }

  // 字幕菜单回调方法
  void _onSubtitleMenuClose() {
    setState(() {
      _showSubtitleMenu = false;
    });
  }

  void _onAddSubtitle() {
    setState(() {
      _showSubtitleMenu = false;
    });
    _addSubtitle();
  }

  void _onSelectSubtitle(SubtitleTrack track) {
    setState(() {
      _showSubtitleMenu = false;
    });
    final playerService = ref.read(playerServiceProvider);
    final controller = playerService.controller;
    _queueSubtitleOperation(() async {
      await controller?.selectSubtitleTrack(track);
    });
  }

  void _onToggleSubtitle() {
    setState(() {
      _showSubtitleMenu = false;
    });
    final playerService = ref.read(playerServiceProvider);
    final controller = playerService.controller;
    _queueSubtitleOperation(() async {
      controller?.toggleSubtitle();
    });
  }

  void _onClearSubtitle() {
    setState(() {
      _showSubtitleMenu = false;
    });
    final playerService = ref.read(playerServiceProvider);
    final controller = playerService.controller;
    final subtitleTracks = controller?.subtitleTracks ?? [];
    _queueSubtitleOperation(() async {
      // 检查是否有外挂字幕
      if (subtitleTracks.any((t) => t.type == SubtitleTrackType.external)) {
        // 删除所有外挂字幕
        controller?.removeAllSubtitleTracks();
      } else {
        // 对于内置字幕，只是不显示
        controller?.clearCurrentSubtitle();
      }
    });
  }

  void _onRemoveSubtitle(SubtitleTrack track) {
    final playerService = ref.read(playerServiceProvider);
    final controller = playerService.controller;
    final activeTrack = controller?.activeSubtitleTrack;
    final subtitleEnabled = controller?.subtitleEnabled ?? false;
    final isActive = activeTrack?.id == track.id && subtitleEnabled;
    
    if (isActive) {
      setState(() {
        _showSubtitleMenu = false;
      });
    }
    
    _queueOperation(() async {
      controller?.removeSubtitleTrack(track);
    });
  }

  // ── 视频书签功能 ───────────────────────────────────────────────

  Future<void> _addVideoBookmark() async {
    final playerService = ref.read(playerServiceProvider);
    if (!playerService.isInitialized || playerService.controller == null) return;
    
    final currentPosition = playerService.controller!.position;
    final videoPath = widget.path;
    final videoName = p.basename(videoPath);
    
    // 显示添加书签对话框
    if (mounted) {
      String? note;
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('添加书签'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('当前位置: ${_formatDuration(currentPosition)}'),
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(
                  labelText: '备注（可选）',
                  hintText: '输入书签备注',
                ),
                onChanged: (value) => note = value,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await ref.read(videoBookmarkProvider.notifier).addBookmark(
                  videoPath,
                  videoName,
                  currentPosition,
                  note: note?.isNotEmpty == true ? note : null,
                );
                if (mounted) {
                  // ignore: use_build_context_synchronously
                  ToastUtils.showToast(context, '书签已添加: ${_formatDuration(currentPosition)}');
                }
              },
              child: const Text('添加'),
            ),
          ],
        ),
      );
    }
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  // 键盘 seek（复用 slider 的防抖节流逻辑，但不暂停视频）
  Future<void> _keyboardSeek(Duration targetPosition) async {
    if (!mounted) return;
    
    // 设置 _isSliderDragging = true，防止位置更新循环抢在 seek 之前
    setState(() {
      _isSliderDragging = true;
      _position = targetPosition;
    });

    // 防抖：取消之前的定时器
    _debounceTimer?.cancel();
    
    // 防抖+节流：延迟执行，确保是最后一次操作，并避免太频繁
    _debounceTimer = Timer(_debounceDuration, () {
      if (!mounted) return;
      
      // 节流：检查是否太频繁
      final now = DateTime.now();
      if (_lastSeekTime != null && now.difference(_lastSeekTime!) < _throttleDuration) {
        // 太频繁了，但还是要把 _isSliderDragging 设为 false
        if (mounted) {
          setState(() {
            _isSliderDragging = false;
          });
        }
        return;
      }
      _lastSeekTime = now;
      
      // Seek 插队到队列最前面
      _queueSeekOperation(() async {
        if (!mounted) return;
        final playerService = ref.read(playerServiceProvider);
        if (playerService.isInitialized && playerService.controller != null) {
          playerService.controller!.seek(targetPosition);
        }
        // Seek 完成后，把 _isSliderDragging 设为 false
        if (mounted) {
          setState(() {
            _isSliderDragging = false;
          });
        }
      });
    });
  }

  // ── 键盘快捷键 ────────────────────────────────────────────────

  void _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    if (event.logicalKey == LogicalKeyboardKey.space) {
      _togglePlayPause();
    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      if (_duration.inMilliseconds > 0) {
        final newMs = (_position.inMilliseconds - (_duration.inMilliseconds * 0.05).round()).clamp(0, _duration.inMilliseconds);
        final newPosition = Duration(milliseconds: newMs);
        // 键盘 seek，不暂停视频
        _keyboardSeek(newPosition);
      }
    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      if (_duration.inMilliseconds > 0) {
        final newMs = (_position.inMilliseconds + (_duration.inMilliseconds * 0.05).round()).clamp(0, _duration.inMilliseconds);
        final newPosition = Duration(milliseconds: newMs);
        // 键盘 seek，不暂停视频
        _keyboardSeek(newPosition);
      }
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _handleVolumeChange(_volume + 0.1);
    } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _handleVolumeChange(_volume - 0.1);
    } else if (event.logicalKey == LogicalKeyboardKey.equal) {
      _handleSpeedChangeFinal((_playbackSpeed + 0.1).clamp(0.25, 4.0));
    } else if (event.logicalKey == LogicalKeyboardKey.minus) {
      _handleSpeedChangeFinal((_playbackSpeed - 0.1).clamp(0.25, 4.0));
    } else if (event.logicalKey == LogicalKeyboardKey.digit0) {
      _handleSpeedChangeFinal(1.0);
    } else if (event.logicalKey == LogicalKeyboardKey.escape) {
      if (!_isAppBarVisible) {
        setState(() {
          _isAppBarVisible = true;
        });
      }
    }

    if (mounted) _focusNode.requestFocus();
  }

  // ── Build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // 监听播放队列变化
    ref.listen(playQueueProvider, (previous, next) {
      if (mounted) {
        _handlePlayQueueChange();
      }
    });

    return ScaffoldMessenger(
      key: _scaffoldMessengerKey,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: _isAppBarVisible
          ? AppBar(
              backgroundColor: Colors.black,
              iconTheme: const IconThemeData(color: Colors.white),
              title: Text(
                _currentFileName ?? p.basename(widget.path),
                style: const TextStyle(color: Colors.white),
              ),
              leading: IconButton(
                onPressed: _handleBackPress,
                icon: const Icon(Icons.arrow_back),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.info_outline, color: Colors.white),
                  onPressed: () => _showVideoInfo(context),
                ),
                // Android端添加播放列表按钮
            if (Platform.isAndroid)
              IconButton(
                icon: const Icon(Icons.playlist_play, color: Colors.white),
                onPressed: () {
                  _focusNode.requestFocus();
                  setState(() {
                    _showPlayListDrawer = !_showPlayListDrawer;
                  });
                },
              ),
          ],
        )
          : null,
        body: Stack(
          children: [
            // 主要内容区域
            Platform.isWindows
                ? Row(
                children: [
                  // 视频播放区域
                  Expanded(
                    child: Stack(
                      children: [
                        // 视频和控制栏区域
                        Column(
                          children: [
                            // 视频画面
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  if (!_isAppBarVisible) {
                                    setState(() {
                                      _isAppBarVisible = true;
                                    });
                                  }
                                },
                                child: SizedBox.expand(
                                  child: Consumer(
                                    builder: (context, ref, child) {
                                      final playerService = ref.watch(playerServiceProvider);
                                      if (_isInitialized && 
                                          playerService.isInitialized && 
                                          playerService.controller != null &&
                                          playerService.controller!.videoController != null) {
                                        return VideoPlayer(playerService.controller!.videoController!);
                                      } else {
                                        return const Center(
                                          child: CircularProgressIndicator(color: Colors.blue),
                                        );
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ),

                            // 底部控制栏
                            if (_isAppBarVisible)
                              Container(
                                color: Colors.black,
                                padding: EdgeInsets.fromLTRB(
                                  16.0,
                                  16.0,
                                  16.0,
                                  16.0 + MediaQuery.of(context).padding.bottom,
                                ),
                                child: Column(
                                  children: [
                                    // 进度条
                                    Row(
                                      children: [
                                        Text(
                                          '${_position.inMinutes}:${(_position.inSeconds % 60).toString().padLeft(2, '0')}',
                                          style: const TextStyle(color: Colors.white),
                                        ),
                                        Expanded(
                                          child: Slider(
                                            value: _duration.inMilliseconds > 0
                                                ? (_position.inMilliseconds /
                                                        _duration.inMilliseconds)
                                                    .clamp(0.0, 1.0)
                                                : 0.0,
                                            onChangeStart: _onSliderChangeStart,
                                            onChanged: _onSliderChanged,
                                            onChangeEnd: _onSliderChangeEnd,
                                            activeColor: Colors.blue,
                                            inactiveColor: Colors.grey[700],
                                          ),
                                        ),
                                        Text(
                                          '${_duration.inMinutes}:${(_duration.inSeconds % 60).toString().padLeft(2, '0')}',
                                          style: const TextStyle(color: Colors.white),
                                        ),
                                      ],
                                    ),
                                    // 控制按钮行
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.skip_previous,
                                              color: Colors.white),
                                          onPressed: () async {
                                            _focusNode.requestFocus();
                                            final playQueueNotifier = ref.read(playQueueProvider.notifier);
                                            await playQueueNotifier.playPrevious();
                                          },
                                        ),
                                        IconButton(
                                          icon: Icon(
                                            _isCompleted
                                                ? Icons.replay
                                                : (_isPlaying ? Icons.pause : Icons.play_arrow),
                                            color: Colors.white,
                                            size: 32,
                                          ),
                                          onPressed: () {
                                            _focusNode.requestFocus();
                                            _togglePlayPause();
                                          },
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.skip_next,
                                              color: Colors.white),
                                          onPressed: () async {
                                            _focusNode.requestFocus();
                                            final playQueueNotifier = ref.read(playQueueProvider.notifier);
                                            await playQueueNotifier.playNext();
                                          },
                                        ),
                                        // 音量控制
                                        Consumer(
                                          builder: (context, ref, child) {
                                            final volume = ref.watch(volumeProvider);
                                            return Row(
                                              children: [
                                                CompositedTransformTarget(
                                                  link: _volumeLayerLink,
                                                  child: IconButton(
                                                    key: _volumeButtonKey,
                                                    icon: Icon(
                                                      volume == 0
                                                          ? Icons.volume_mute
                                                          : volume < 0.5
                                                              ? Icons.volume_down
                                                              : Icons.volume_up,
                                                      color: Colors.white,
                                                    ),
                                                    onPressed: () {
                                                      _focusNode.requestFocus();
                                                      _toggleVolumeControl();
                                                    },
                                                  ),
                                                ),
                                                Text(
                                                  '${(volume * 100).round()}%',
                                                  style: const TextStyle(color: Colors.white),
                                                ),
                                              ],
                                            );
                                          },
                                        ),
                                        // 字幕按钮
                                        Consumer(
                                          builder: (context, ref, child) {
                                            final playerService = ref.watch(playerServiceProvider);
                                            final hasSubtitle = playerService.controller?.subtitleTracks.isNotEmpty ?? false;
                                            final subtitleEnabled = playerService.controller?.subtitleEnabled ?? false;
                                            
                                            // 根据状态决定按钮样式
                                            IconData iconData;
                                            Color iconColor;
                                            
                                            if (hasSubtitle) {
                                              if (subtitleEnabled) {
                                                // 有字幕且正在显示 - 蓝色
                                                iconData = Icons.closed_caption;
                                                iconColor = Colors.blue;
                                              } else {
                                                // 有字幕但未显示 - 白色
                                                iconData = Icons.closed_caption;
                                                iconColor = Colors.white;
                                              }
                                            } else {
                                              // 无字幕 - 白色带斜杠
                                              iconData = Icons.closed_caption_disabled;
                                              iconColor = Colors.white;
                                            }
                                            
                                            return CompositedTransformTarget(
                                              link: _subtitleLayerLink,
                                              child: IconButton(
                                                key: _subtitleButtonKey,
                                                icon: Icon(
                                                  iconData,
                                                  color: iconColor,
                                                ),
                                                onPressed: () {
                                                  _focusNode.requestFocus();
                                                  setState(() {
                                                    _showSubtitleMenu = !_showSubtitleMenu;
                                                  });
                                                },
                                              ),
                                            );
                                          },
                                        ),
                                        // 书签按钮
                                        IconButton(
                                          icon: const Icon(Icons.bookmark, color: Colors.white),
                                          onPressed: () {
                                            _focusNode.requestFocus();
                                            _addVideoBookmark();
                                          },
                                        ),
                                        // 倍速按钮
                                        ElevatedButton(
                                          onPressed: () {
                                            _focusNode.requestFocus();
                                            if (mounted) {
                                              setState(() {
                                                _showSpeedControl = !_showSpeedControl;
                                              });
                                            }
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.grey[800],
                                            foregroundColor: Colors.white,
                                          ),
                                          child: Text('${_playbackSpeed.toStringAsFixed(2)}x'),
                                        ),
                                        // Windows端播放列表切换按钮
                                        if (Platform.isWindows)
                                          IconButton(
                                            icon: Icon(
                                              _showPlayListPanel ? Icons.playlist_add_check : Icons.playlist_play,
                                              color: Colors.white,
                                            ),
                                            onPressed: () {
                                              _focusNode.requestFocus();
                                              setState(() {
                                                _showPlayListPanel = !_showPlayListPanel;
                                              });
                                            },
                                          ),
                                        // 隐藏/显示控制栏
                                        IconButton(
                                          icon: Icon(
                                            _isAppBarVisible
                                                ? Icons.visibility_off
                                                : Icons.visibility,
                                            color: Colors.white,
                                          ),
                                          onPressed: () {
                                            _focusNode.requestFocus();
                                            _toggleAppBar();
                                          },
                                        ),
                                      ],
                                    ),
                                    // 倍速控制面板
                                    if (_showSpeedControl)
                                      Consumer(
                                        builder: (context, ref, child) {
                                          final playerService = ref.watch(playerServiceProvider);
                                          if (playerService.controller == null) return const SizedBox.shrink();
                                          return SpeedControl(
                                            currentSpeed: _playbackSpeed,
                                            controller: playerService.controller!,
                                            onSpeedChanged: (speed) {
                                              if (mounted) {
                                                setState(() {
                                                  _playbackSpeed = speed;
                                                });
                                              }
                                            },
                                            onSpeedChangeFinal: _handleSpeedChangeFinal,
                                          );
                                        },
                                      ),
                                  ],
                                ),
                              ),
                          ],
                        ),

                      ],
                    ),
                  ),
                  // Windows端右侧播放列表面板
                  Offstage(
                    offstage: !_showPlayListPanel,
                    child: _getWindowsPlayListPanel(),
                  ),
                ],
              )
            : Stack(
                children: [
                  // 视频和控制栏区域
                  Column(
                    children: [
                      // 视频画面
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            if (!_isAppBarVisible) {
                              setState(() {
                                _isAppBarVisible = true;
                              });
                            }
                          },
                          child: SizedBox.expand(
                            child: Consumer(
                              builder: (context, ref, child) {
                                final playerService = ref.watch(playerServiceProvider);
                                if (_isInitialized && 
                                    playerService.isInitialized && 
                                    playerService.controller != null &&
                                    playerService.controller!.videoController != null) {
                                  return VideoPlayer(playerService.controller!.videoController!);
                                } else {
                                  return const Center(
                                    child: CircularProgressIndicator(color: Colors.blue),
                                  );
                                }
                              },
                            ),
                          ),
                        ),
                      ),

                      // 底部控制栏
                      if (_isAppBarVisible)
                        Container(
                          color: Colors.black,
                          padding: EdgeInsets.fromLTRB(
                            16.0,
                            16.0,
                            16.0,
                            16.0 + MediaQuery.of(context).padding.bottom,
                          ),
                          child: Column(
                            children: [
                              // 进度条
                              Row(
                                children: [
                                  Text(
                                    '${_position.inMinutes}:${(_position.inSeconds % 60).toString().padLeft(2, '0')}',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  Expanded(
                                    child: Slider(
                                      value: _duration.inMilliseconds > 0
                                          ? (_position.inMilliseconds /
                                                  _duration.inMilliseconds)
                                              .clamp(0.0, 1.0)
                                          : 0.0,
                                      onChangeStart: _onSliderChangeStart,
                                      onChanged: _onSliderChanged,
                                      onChangeEnd: _onSliderChangeEnd,
                                      activeColor: Colors.blue,
                                      inactiveColor: Colors.grey[700],
                                    ),
                                  ),
                                  Text(
                                    '${_duration.inMinutes}:${(_duration.inSeconds % 60).toString().padLeft(2, '0')}',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ],
                              ),
                              // 控制按钮行
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.skip_previous,
                                        color: Colors.white),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    iconSize: 20,
                                    onPressed: () async {
                                      _focusNode.requestFocus();
                                      final playQueueNotifier = ref.read(playQueueProvider.notifier);
                                      await playQueueNotifier.playPrevious();
                                    },
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      _isCompleted
                                          ? Icons.replay
                                          : (_isPlaying ? Icons.pause : Icons.play_arrow),
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () {
                                      _focusNode.requestFocus();
                                      _togglePlayPause();
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.skip_next,
                                        color: Colors.white),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    iconSize: 20,
                                    onPressed: () async {
                                      _focusNode.requestFocus();
                                      final playQueueNotifier = ref.read(playQueueProvider.notifier);
                                      await playQueueNotifier.playNext();
                                    },
                                  ),
                                  // 音量控制
                                  Consumer(
                                    builder: (context, ref, child) {
                                      final volume = ref.watch(volumeProvider);
                                      return CompositedTransformTarget(
                                        link: _volumeLayerLink,
                                        child: IconButton(
                                          key: Platform.isAndroid ? _volumeButtonKey : null,
                                          icon: Icon(
                                            volume == 0
                                                ? Icons.volume_mute
                                                : volume < 0.5
                                                    ? Icons.volume_down
                                                    : Icons.volume_up,
                                            color: Colors.white,
                                            size: 22,
                                          ),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          onPressed: () {
                                            _focusNode.requestFocus();
                                            _toggleVolumeControl();
                                          },
                                        ),
                                      );
                                    },
                                  ),
                                  // 字幕按钮
                                  Consumer(
                                    builder: (context, ref, child) {
                                      final playerService = ref.watch(playerServiceProvider);
                                      final hasSubtitle = playerService.controller?.subtitleTracks.isNotEmpty ?? false;
                                      final subtitleEnabled = playerService.controller?.subtitleEnabled ?? false;
                                      
                                      // 根据状态决定按钮样式
                                      IconData iconData;
                                      Color iconColor;
                                      
                                      if (hasSubtitle) {
                                        if (subtitleEnabled) {
                                          // 有字幕且正在显示 - 蓝色
                                          iconData = Icons.closed_caption;
                                          iconColor = Colors.blue;
                                        } else {
                                          // 有字幕但未显示 - 白色
                                          iconData = Icons.closed_caption;
                                          iconColor = Colors.white;
                                        }
                                      } else {
                                        // 无字幕 - 白色带斜杠
                                        iconData = Icons.closed_caption_disabled;
                                        iconColor = Colors.white;
                                      }
                                      
                                      return CompositedTransformTarget(
                                        link: _subtitleLayerLink,
                                        child: IconButton(
                                          key: Platform.isAndroid ? _subtitleButtonKey : null,
                                          icon: Icon(
                                            iconData,
                                            color: iconColor,
                                            size: 20,
                                          ),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          onPressed: () {
                                            _focusNode.requestFocus();
                                            setState(() {
                                              _showSubtitleMenu = !_showSubtitleMenu;
                                            });
                                          },
                                        ),
                                      );
                                    },
                                  ),
                                  // 书签按钮
                                  IconButton(
                                    icon: const Icon(Icons.bookmark, color: Colors.white),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    iconSize: 20,
                                    onPressed: () {
                                      _focusNode.requestFocus();
                                      _addVideoBookmark();
                                    },
                                  ),
                                  // 倍速按钮
                                  ElevatedButton(
                                    onPressed: () {
                                      _focusNode.requestFocus();
                                      if (mounted) {
                                        setState(() {
                                          _showSpeedControl = !_showSpeedControl;
                                        });
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.grey[800],
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: Text(
                                      Platform.isAndroid
                                          ? '${_playbackSpeed.toStringAsFixed(2)}x'
                                          : '${_playbackSpeed.toStringAsFixed(1)}x',
                                      style: TextStyle(fontSize: 11),
                                    ),
                                  ),
                                  // 隐藏/显示控制栏
                                  IconButton(
                                    icon: Icon(
                                      _isAppBarVisible
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () {
                                      _focusNode.requestFocus();
                                      _toggleAppBar();
                                    },
                                  ),
                                ],
                              ),
                              // 倍速控制面板
                              if (_showSpeedControl)
                                Consumer(
                                  builder: (context, ref, child) {
                                    final playerService = ref.watch(playerServiceProvider);
                                    if (playerService.controller == null) return const SizedBox.shrink();
                                    return SpeedControl(
                                      currentSpeed: _playbackSpeed,
                                      controller: playerService.controller!,
                                      onSpeedChanged: (speed) {
                                        if (mounted) {
                                          setState(() {
                                            _playbackSpeed = speed;
                                          });
                                        }
                                      },
                                      onSpeedChangeFinal: _handleSpeedChangeFinal,
                                    );
                                  },
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),

            // 音量调节条 - 全屏遮罩
            if (_showVolumeControl)
              GestureDetector(
                onTap: () {
                  _toggleVolumeControl();
                },
                child: Container(
                  color: Colors.black.withValues(alpha: 0.01),
                  width: double.infinity,
                  height: double.infinity,
                  child: Stack(
                    children: [
                      CompositedTransformFollower(
                        link: _volumeLayerLink,
                        showWhenUnlinked: false,
                        targetAnchor: Alignment.topCenter,
                        followerAnchor: Alignment.bottomCenter,
                        offset: const Offset(0, 8), // 音量条往下移
                        child: GestureDetector(
                          onTap: () {}, // 阻止事件冒泡
                          child: _getVolumeControl(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // 字幕菜单 - 全屏遮罩
            if (_showSubtitleMenu)
              GestureDetector(
                onTap: () {
                  _toggleSubtitleMenu();
                },
                child: Container(
                  color: Colors.black.withValues(alpha: 0.01),
                  width: double.infinity,
                  height: double.infinity,
                  child: Stack(
                    children: [
                      CompositedTransformFollower(
                        link: _subtitleLayerLink,
                        showWhenUnlinked: false,
                        targetAnchor: Alignment.topCenter,
                        followerAnchor: Alignment.bottomCenter,
                        offset: const Offset(0, -24), // 字幕菜单往上移
                        child: GestureDetector(
                          onTap: () {}, // 阻止事件冒泡
                          child: _getSubtitleMenu(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Android端底部播放列表抽屉
            if (Platform.isAndroid)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Offstage(
                  offstage: !_showPlayListDrawer,
                  child: _getAndroidPlayListDrawer(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showVideoInfo(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final playerService = ref.read(playerServiceProvider);
    if (!playerService.isInitialized || playerService.controller == null) return;
    
    // 使用 playerService 中的真实路径
    final displayPath = playerService.currentPath ?? widget.path;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black87,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${loc.fileName}: ${_currentFileName ?? p.basename(displayPath)}', style: const TextStyle(color: Colors.white)),
              const SizedBox(height: 8),
              Text('${loc.filePath}: $displayPath', style: const TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 8),
              Text('Duration: ${_formatDuration(_duration)}', style: const TextStyle(color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
