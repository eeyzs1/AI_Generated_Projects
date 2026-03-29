import 'dart:collection';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

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
  late MyVideoPlayerController _controller;
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

  // 进度条交互状态
  bool _isSliderDragging = false;
  bool _wasPlayingBeforeDrag = false;
  // 播放完成状态
  bool _isCompleted = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(debugLabel: 'VideoPlayerFocusNode');
    _focusAttachment = _focusNode.attach(context, onKey: (node, event) {
      _handleKey(event);
      return KeyEventResult.handled;
    });
    _controller = MyVideoPlayerController(widget.path, ref);
    _initializePlayer();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
        _focusAttachment.reparent();
      }
    });
  }

  Future<void> _initializePlayer() async {
    final settings = ref.read(settingsProvider);
    _playbackSpeed = settings.defaultPlaybackSpeed;

    await _controller.initialize();
    _controller.setPlaybackSpeed(_playbackSpeed);

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
        if (!_isSliderDragging) {
          final position = _controller.position;
          final duration = _controller.duration;
          final isPlaying = _controller.isPlaying;
          final completed = duration.inMilliseconds > 0 &&
              position.inMilliseconds >= duration.inMilliseconds * 0.99 &&
              !isPlaying;

          setState(() {
            _position = position;
            _duration = duration;
            _isPlaying = isPlaying;
            _isCompleted = completed;
          });
        }
      } catch (e) {
        debugPrint('Error updating player state: $e');
      }

      await Future.delayed(const Duration(milliseconds: 300));
    }
  }

  @override
  void dispose() {
    _focusAttachment.detach();
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  // 操作队列处理
  Future<void> _processQueue() async {
    if (!mounted || _isProcessing || _operationQueue.isEmpty) return;

    _isProcessing = true;
    final operation = _operationQueue.removeFirst();
    try {
      if (mounted) await operation();
    } catch (e) {
      debugPrint('Error processing operation: $e');
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
    if (!mounted) return;
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

      final isCompleted = _duration.inMilliseconds > 0 &&
          _position.inMilliseconds >= _duration.inMilliseconds * 0.99;

      if (isCompleted) {
        _controller.seek(Duration.zero);
        if (mounted) _controller.play();
      } else if (_isPlaying) {
        if (mounted) _controller.pause();
      } else {
        if (mounted) _controller.play();
      }
    });
  }

  // ── 进度条回调 ────────────────────────────────────────────────

  void _onSliderChangeStart(double value) {
    _wasPlayingBeforeDrag = _isPlaying;
    _isSliderDragging = true;
    if (_isPlaying) {
      _controller.pause();
      setState(() { _isPlaying = false; });
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

    _isSliderDragging = false;
    setState(() {
      _position = targetPosition;
      _isPlaying = _wasPlayingBeforeDrag;
    });

    _controller.seek(targetPosition);
    if (_wasPlayingBeforeDrag) {
      _controller.play();
    }
  }

  // ── 倍速回调 ─────────────────────────────────────────────────

  /// 点击档位或键盘快捷键触发，属于明确的最终值，直接持久化
  void _handleSpeedChangeFinal(double speed) {
    if (!mounted) return;
    _controller.setPlaybackSpeed(speed);
    setState(() {
      _playbackSpeed = speed;
    });
    _saveSpeedSetting(speed);
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
    _controller.setVolume(clampedVolume);
    if (mounted) {
      setState(() {
        _volume = clampedVolume;
      });
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

  // ── 键盘快捷键 ────────────────────────────────────────────────

  void _handleKey(RawKeyEvent event) {
    if (event is! RawKeyDownEvent) return;

    if (event.logicalKey == LogicalKeyboardKey.space) {
      _togglePlayPause();
    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      if (_duration.inMilliseconds > 0) {
        int seekMs = (_duration.inMilliseconds * 0.05).round().clamp(1000, 30000);
        final newMs = (_position.inMilliseconds - seekMs).clamp(0, _duration.inMilliseconds);
        final newPosition = Duration(milliseconds: newMs);
        _queueOperation(() async {
          if (mounted) _controller.seek(newPosition);
        });
      }
    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      if (_duration.inMilliseconds > 0) {
        int seekMs = (_duration.inMilliseconds * 0.05).round().clamp(1000, 30000);
        final newMs = (_position.inMilliseconds + seekMs).clamp(0, _duration.inMilliseconds);
        final newPosition = Duration(milliseconds: newMs);
        _queueOperation(() async {
          if (mounted) _controller.seek(newPosition);
        });
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
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _isAppBarVisible
          ? AppBar(
              backgroundColor: Colors.black,
              iconTheme: const IconThemeData(color: Colors.white),
              title: Text(
                p.basename(widget.path),
                style: const TextStyle(color: Colors.white),
              ),
              leading: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back),
              ),
            )
          : null,
      body: Stack(
        children: [
          // 视频画面
          GestureDetector(
            onTap: () {
              if (!_isAppBarVisible) {
                setState(() {
                  _isAppBarVisible = true;
                });
              }
            },
            child: SizedBox.expand(
              child: _isInitialized
                  ? VideoPlayer(_controller.controller)
                  : const Center(
                      child: CircularProgressIndicator(color: Colors.blue),
                    ),
            ),
          ),

          // 底部控制栏
          if (_isAppBarVisible)
            Positioned(
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
                          onPressed: () => _focusNode.requestFocus(),
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
                          onPressed: () => _focusNode.requestFocus(),
                        ),
                        // 音量控制
                        Row(
                          children: [
                            IconButton(
                              icon: Icon(
                                _volume == 0
                                    ? Icons.volume_mute
                                    : _volume < 0.5
                                        ? Icons.volume_down
                                        : Icons.volume_up,
                                color: Colors.white,
                              ),
                              onPressed: () {
                                _focusNode.requestFocus();
                                _toggleVolumeControl();
                              },
                            ),
                            Text(
                              '${(_volume * 100).round()}%',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ],
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
                      SpeedControl(
                        currentSpeed: _playbackSpeed,
                        controller: _controller,
                        onSpeedChanged: (speed) {
                          if (mounted) {
                            setState(() {
                              _playbackSpeed = speed;
                            });
                          }
                        },
                        onSpeedChangeFinal: _handleSpeedChangeFinal,
                      ),
                  ],
                ),
              ),
            ),

          // 音量调节条
          if (_showVolumeControl)
            Stack(
              children: [
                // 背景遮罩，点击关闭
                GestureDetector(
                  onTap: () => setState(() => _showVolumeControl = false),
                  child: Container(
                    color: Colors.black.withOpacity(0.01),
                    width: MediaQuery.of(context).size.width,
                    height: MediaQuery.of(context).size.height,
                  ),
                ),
                // 垂直音量滑块
                Positioned(
                  top: MediaQuery.of(context).orientation ==
                          Orientation.landscape
                      ? MediaQuery.of(context).size.height * 0.001
                      : MediaQuery.of(context).size.height * 0.3,
                  left: 10,
                  child: GestureDetector(
                    onTap: () {}, // 点击滑块本身不关闭
                    child: Material(
                      color: Colors.transparent,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 8.0, horizontal: 4.0),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(4.0),
                        ),
                        child: RotatedBox(
                          quarterTurns: 3,
                          child: SizedBox(
                            width: 200,
                            child: Slider(
                              value: _volume,
                              min: 0.0,
                              max: 1.0,
                              divisions: 100,
                              onChanged: _handleVolumeChange,
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
        ],
      ),
    );
  }
}
