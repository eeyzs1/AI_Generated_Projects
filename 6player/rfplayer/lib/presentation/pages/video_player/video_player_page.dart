import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'video_player_controller.dart';
import '../../../data/models/bookmark.dart';
import '../../../presentation/providers/database_provider.dart';
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
  final double _volume = 1.0;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController(widget.path, ref);
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    await _controller.initialize();
    setState(() {
      _isInitialized = true;
    });
    _updatePlayerState();
  }

  Future<void> _updatePlayerState() async {
    while (mounted) {
      final position = await _controller.position;
      final duration = await _controller.duration;
      final isPlaying = await _controller.isPlaying;
      
      setState(() {
        _position = position;
        _duration = duration;
        _isPlaying = isPlaying;
      });
      
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
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
      ),
      body: Center(
        child: _isInitialized
            ? Column(
                children: [
                  Expanded(
                    child: Video(
                      controller: _controller.videoController,
                      // 使用默认控件
                    ),
                  ),
                ],
              )
            : const Center(
                child: CircularProgressIndicator(
                  color: Colors.blue,
                ),
              ),
      ),
    );
  }
}