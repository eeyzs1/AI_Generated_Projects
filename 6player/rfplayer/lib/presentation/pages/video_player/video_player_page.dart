import 'dart:collection';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'video_player_controller.dart';
import 'speed_control.dart';
import '../../../data/models/bookmark.dart';
import '../../../presentation/providers/database_provider.dart';
import '../../../presentation/providers/settings_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as p;

class VideoPlayerPage extends ConsumerStatefulWidget {
  final String path;

  const VideoPlayerPage({super.key, required this.path});

  @override
  ConsumerState<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends ConsumerState<VideoPlayerPage> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isPlaying = false;
  double _volume = 1.0;
  double _playbackSpeed = 1.0;
  bool _showSpeedControl = false;
  bool _showVolumeControl = false;
  bool _isAppBarVisible = true;
  late FocusNode _focusNode;
  late FocusAttachment _focusAttachment;
  
  // 操作队列，确保一次只执行一个播放器操作
  bool _isProcessing = false;
  final Queue<Future<void> Function()> _operationQueue = Queue();

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(debugLabel: 'VideoPlayerFocusNode');
    _focusAttachment = _focusNode.attach(context, onKey: (node, event) {
      // 处理键盘事件，确保所有键盘事件都被当前页面捕获
      _handleKey(event);
      return KeyEventResult.handled;
    });
    _controller = VideoPlayerController(widget.path, ref);
    _initializePlayer();
    
    // 确保页面获得焦点
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
        _focusAttachment.reparent();
      }
    });
  }

  Future<void> _initializePlayer() async {
    // 从应用设置中加载默认播放速率
    final settings = ref.read(settingsProvider);
    _playbackSpeed = settings.defaultPlaybackSpeed;
    
    await _controller.initialize();
    // 设置初始播放速率
    await _controller.setPlaybackSpeed(_playbackSpeed);
    
    if (mounted) {
      setState(() {
        _isInitialized = true;
      });
    }
    _updatePlayerState();
  }

  Future<void> _updatePlayerState() async {
    while (mounted) {
      try {
        final position = await _controller.position;
        final duration = await _controller.duration;
        final isPlaying = await _controller.isPlaying;
        final playbackSpeed = await _controller.playbackSpeed;
        
        setState(() {
          _position = position;
          _duration = duration;
          _isPlaying = isPlaying;
          _playbackSpeed = playbackSpeed;
          // 不更新音量，避免与手动调节冲突
        });
      } catch (e) {
        // 忽略错误，避免因为播放器状态问题导致崩溃
        print('Error updating player state: $e');
      }
      
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  @override
  void dispose() {
    _focusAttachment.detach();
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }
  
  // 处理操作队列
  Future<void> _processQueue() async {
    if (!mounted || _isProcessing || _operationQueue.isEmpty) return;
    
    _isProcessing = true;
    
    final operation = _operationQueue.removeFirst();
    try {
      if (mounted) {
        await operation();
      }
    } catch (e) {
      print('Error processing operation: $e');
    } finally {
      if (mounted) {
        _isProcessing = false;
        // 处理下一个操作
        _processQueue();
      }
    }
  }
  
  // 添加操作到队列
  void _queueOperation(Future<void> Function() operation) {
    if (!mounted) return;
    _operationQueue.add(operation);
    _processQueue();
  }

  Future<void> _addBookmark() async {
    final bookmarkRepository = ref.read(bookmarkRepositoryProvider);
    final bookmark = Bookmark(
      id: const Uuid().v4(),
      path: widget.path,
      displayName: p.basename(widget.path),
      createdAt: DateTime.now(),
      sortOrder: 0,
    );
    await bookmarkRepository.insert(bookmark);
    // 显示提示消息
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('成功'),
        content: const Text('书签已添加'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _togglePlayPause() {
    _queueOperation(() async {
      if (!mounted) return;
      
      // 检查是否播放完成（位置接近或等于总时长）
      bool isCompleted = _duration.inMilliseconds > 0 && 
                        _position.inMilliseconds >= _duration.inMilliseconds * 0.99;
      
      // 无论当前状态如何，只要视频已完成，按播放键就从头开始
      if (isCompleted) {
        // 重置到开始位置并播放
        await _controller.seek(Duration.zero);
        if (mounted) {
          await _controller.play();
        }
      } else if (_isPlaying) {
        // 正在播放且未完成，执行暂停
        if (mounted) {
          await _controller.pause();
        }
      } else {
        // 暂停状态且未完成，执行播放
        if (mounted) {
          await _controller.play();
        }
      }
    });
  }

  void _handleSpeedChange(double speed) {
    _queueOperation(() async {
      if (!mounted) return;
      
      await _controller.setPlaybackSpeed(speed);
      if (mounted) {
        setState(() {
          _playbackSpeed = speed;
        });
      }
      
      // 更新应用设置中的默认播放速率，实现全局记忆
      if (mounted) {
        final settings = ref.read(settingsProvider);
        await ref.read(settingsProvider.notifier).update(
          settings.copyWith(defaultPlaybackSpeed: speed)
        );
      }
    });
  }

  void _handleVolumeChange(double volume) {
    _queueOperation(() async {
      if (!mounted) return;
      
      // 确保音量值在0-100范围内
      final clampedVolume = volume.clamp(0.0, 100.0);
      if (mounted) {
        await _controller.setVolume(clampedVolume);
        if (mounted) {
          setState(() {
            _volume = clampedVolume / 100.0; // 存储为0-1范围
          });
        }
      }
    });
  }

  void _toggleAppBar() {
    if (!mounted) return;
    
    setState(() {
      _isAppBarVisible = !_isAppBarVisible;
    });
  }

  // 显示/隐藏音量调节条
  void _toggleVolumeControl() {
    if (mounted) {
      setState(() {
        _showVolumeControl = !_showVolumeControl;
      });
    }
  }

  // 处理键盘快捷键
  void _handleKey(RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.space) {
        // Space: 播放/暂停
        _togglePlayPause();
      } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        // 左方向键：快退，使用视频总时长的5%
        if (_duration.inMilliseconds > 0) {
          // 计算快退时间：总时长的5%，最小1秒，最大30秒
          int seekMs = (_duration.inMilliseconds * 0.05).round();
          seekMs = seekMs.clamp(1000, 30000); // 限制在1-30秒之间
          var newPosition = _position - Duration(milliseconds: seekMs);
          if (newPosition < Duration.zero) {
            newPosition = Duration.zero;
          }
          _queueOperation(() async {
            if (mounted) {
              await _controller.seek(newPosition);
            }
          });
        }
      } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        // 右方向键：快进，使用视频总时长的5%
        if (_duration.inMilliseconds > 0) {
          // 计算快进时间：总时长的5%，最小1秒，最大30秒
          int seekMs = (_duration.inMilliseconds * 0.05).round();
          seekMs = seekMs.clamp(1000, 30000); // 限制在1-30秒之间
          var newPosition = _position + Duration(milliseconds: seekMs);
          if (newPosition >= _duration) {
            // 如果快进后到达或超过视频末尾，停在视频终止处
            newPosition = _duration;
          }
          _queueOperation(() async {
            if (mounted) {
              await _controller.seek(newPosition);
            }
          });
        }
      } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        // 上方向键：音量+10%
        final newVolume = (_volume * 100 + 10).clamp(0.0, 100.0);
        _handleVolumeChange(newVolume);
      } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        // 下方向键：音量-10%
        final newVolume = (_volume * 100 - 10).clamp(0.0, 100.0);
        _handleVolumeChange(newVolume);
      } else if (event.logicalKey == LogicalKeyboardKey.equal) {
        // +：增加播放速率0.1x
        final newSpeed = (_playbackSpeed + 0.1).clamp(0.25, 4.0);
        _handleSpeedChange(newSpeed);
      } else if (event.logicalKey == LogicalKeyboardKey.minus) {
        // -：减少播放速率0.1x
        final newSpeed = (_playbackSpeed - 0.1).clamp(0.25, 4.0);
        _handleSpeedChange(newSpeed);
      } else if (event.logicalKey == LogicalKeyboardKey.digit0) {
        // 0：重置播放速率为1.0x
        _handleSpeedChange(1.0);
      } else if (event.logicalKey == LogicalKeyboardKey.escape) {
        // Esc：显示AppBar
        if (!_isAppBarVisible) {
          setState(() {
            _isAppBarVisible = true;
          });
        }
      }
      
      // 确保焦点保持在当前页面
      if (mounted) {
        _focusNode.requestFocus();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _isAppBarVisible ? AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          p.basename(widget.path),
          style: const TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          icon: const Icon(Icons.arrow_back),
        ),
      ) : null,
      body: Stack(
        children: [
          // 视频组件，在全屏模式下填满整个屏幕
          GestureDetector(
            onTap: () {
              // 当AppBar隐藏时，点击屏幕显示AppBar
              if (!_isAppBarVisible) {
                setState(() {
                  _isAppBarVisible = true;
                });
              }
            },
            child: SizedBox.expand(
              child: _isInitialized
                  ? Video(
                      controller: _controller.videoController,
                      controls: NoVideoControls,
                    )
                  : const Center(
                      child: CircularProgressIndicator(
                        color: Colors.blue,
                      ),
                    ),
            ),
          ),
          
          // 控制栏，与AppBar的显示状态同步
          if (_isAppBarVisible) Positioned(
            bottom: 0,
            left: 0,
            right: 0,
              child: Container(
                color: Colors.black,
                padding: const EdgeInsets.all(16.0),
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
                                ? (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0)
                                : 0,
                            onChanged: (value) {
                              final newPosition = Duration(
                                milliseconds: (value * _duration.inMilliseconds).toInt(),
                              );
                              _controller.seek(newPosition);
                              if (mounted) {
                                setState(() {
                                  _position = newPosition;
                                });
                              }
                            },
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
                    // 控制按钮
                    Stack(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.skip_previous, color: Colors.white),
                              onPressed: () {
                                _focusNode.requestFocus();
                              },
                            ),
                            IconButton(
                              icon: Icon(
                                _isPlaying ? Icons.pause : Icons.play_arrow,
                                color: Colors.white,
                                size: 32,
                              ),
                              onPressed: () {
                                _focusNode.requestFocus();
                                _togglePlayPause();
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.skip_next, color: Colors.white),
                              onPressed: () {
                                _focusNode.requestFocus();
                              },
                            ),
                            // 音量控制
                            Row(
                              children: [
                                IconButton(
                                  icon: Icon(
                                    _volume == 0 ? Icons.volume_mute : 
                                    _volume < 0.5 ? Icons.volume_down : 
                                    Icons.volume_up,
                                    color: Colors.white,
                                  ),
                                  onPressed: () {
                                    _focusNode.requestFocus();
                                    _toggleVolumeControl();
                                  },
                                ),
                                // 显示当前音量值
                                Text(
                                  '${(_volume * 100).round()}%',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ],
                            ),
                            // 播放速率控制按钮
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
                            // 隐藏/显示AppBar
                            IconButton(
                              icon: Icon(
                                _isAppBarVisible ? Icons.visibility_off : Icons.visibility,
                                color: Colors.white,
                              ),
                              onPressed: () {
                                _focusNode.requestFocus();
                                _toggleAppBar();
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                    // 播放速率控制组件
                    if (_showSpeedControl)
                      SpeedControl(
                        currentSpeed: _playbackSpeed,
                        onSpeedChanged: _handleSpeedChange,
                      ),
                  ],
                ),
              ),
            ),
          
          // 音量调节条
          Visibility(
            visible: _showVolumeControl,
            child: Stack(
              children: [
                // 全屏半透明遮罩，用于捕获点击事件
                GestureDetector(
                  onTap: () {
                    // 点击其他位置关闭音量调节条
                    setState(() {
                      _showVolumeControl = false;
                    });
                  },
                  child: Container(
                    color: Colors.black.withOpacity(0.01), // 使用半透明颜色，确保能捕获点击事件
                    width: MediaQuery.of(context).size.width,
                    height: MediaQuery.of(context).size.height,
                  ),
                ),
                // 音量调节条
                Positioned(
                  top: MediaQuery.of(context).orientation == Orientation.landscape
                      ? MediaQuery.of(context).size.height * 0.001 // 横屏时显示在左侧上方位置
                      : MediaQuery.of(context).size.height * 0.3, // 竖屏时显示在屏幕上方
                  left: 10, // 移到画面最左侧
                  child: GestureDetector(
                    onTap: () {
                      // 点击音量调节条本身不关闭
                    },
                    child: Material(
                      color: Colors.transparent,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8.0,
                          horizontal: 4.0,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(4.0),
                        ),
                        child: RotatedBox(
                          quarterTurns: 3, // 旋转90度，变成垂直
                          child: SizedBox(
                            width: 200, // 高度变为原来的两倍
                            child: Slider(
                              value: _volume * 100, // 转换为0-100范围
                              min: 0.0,
                              max: 100.0,
                              divisions: 100,
                              onChanged: (value) {
                                _handleVolumeChange(value);
                              },
                              activeColor: Colors.blue,
                              inactiveColor: Colors.grey[700],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}