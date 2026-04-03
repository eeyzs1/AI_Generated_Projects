import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:extended_image/extended_image.dart';
import 'package:path/path.dart' as p;
import '../../providers/image_viewer_provider.dart';
import '../../providers/image_bookmark_provider.dart';
import '../../providers/history_provider.dart';
import '../../providers/thumbnail_provider.dart';
import '../../providers/database_provider.dart';
import '../../../data/models/play_history.dart' as ph;
import '../../../core/utils/toast_utils.dart';
import '../../../core/localization/app_localizations.dart';

class ImageViewerPage extends ConsumerStatefulWidget {
  final String path;

  const ImageViewerPage({super.key, required this.path});

  @override
  ConsumerState<ImageViewerPage> createState() => _ImageViewerPageState();
}

class _ImageViewerPageState extends ConsumerState<ImageViewerPage> {
  final GlobalKey<ExtendedImageGestureState> _gestureKey = GlobalKey<ExtendedImageGestureState>();
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
  
  @override
  void initState() {
    super.initState();
    _updateHistory();
  }
  
  Future<void> _updateHistory() async {
    if (!mounted) return;
    
    try {
      final historyRepo = ref.read(historyRepositoryProvider);
      var history = await historyRepo.getByPath(widget.path);
      
      final extension = p.extension(widget.path).substring(1).toLowerCase();
      
      if (history == null) {
        history = ph.PlayHistory(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          path: widget.path,
          displayName: p.basename(widget.path),
          extension: extension,
          type: ph.MediaType.image,
          lastPosition: Duration.zero,
          totalDuration: null,
          lastPlayedAt: DateTime.now(),
          playCount: 1,
        );
        await historyRepo.upsert(history);
        
        // 异步生成缩略图
        _generateThumbnailAsync();
      } else {
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
          thumbnailPath: history.thumbnailPath,
        );
        await historyRepo.upsert(updatedHistory);
        
        // 如果没有缩略图，异步生成
        if (history.thumbnailPath == null) {
          _generateThumbnailAsync();
        }
      }
    } catch (e) {
      print('更新历史记录失败: $e');
    }
  }
  
  Future<void> _generateThumbnailAsync() async {
    if (!mounted) return;
    
    try {
      final thumbnailService = ref.read(thumbnailServiceProvider);
      final historyRepo = ref.read(historyRepositoryProvider);
      
      final thumbPath = await thumbnailService.generateThumbnail(widget.path);
      
      if (thumbPath != null && mounted) {
        var history = await historyRepo.getByPath(widget.path);
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
      print('生成缩略图失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final state = ref.watch(imageViewerProvider(widget.path));
    final notifier = ref.read(imageViewerProvider(widget.path).notifier);

    return ScaffoldMessenger(
      key: _scaffoldMessengerKey,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Column(
          children: [
            // 顶部工具栏
            if (state.isUIVisible)
              Container(
                color: Colors.black.withOpacity(0.7),
                child: SafeArea(
                  child: AppBar(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    leading: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    title: Text(
                      '${state.currentIndex + 1} / ${state.totalCount} - ${state.currentFileName}',
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    actions: [
                      Consumer(
                        builder: (context, ref, child) {
                          final bookmarks = ref.watch(imageBookmarkProvider);
                          final isBookmarked = bookmarks.any((b) => b.imagePath == state.currentPath);
                          return IconButton(
                            icon: Icon(
                              isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                              color: Colors.white,
                            ),
                            onPressed: () async {
                              await ref.read(imageBookmarkProvider.notifier).toggleBookmark(
                                state.currentPath,
                                state.currentFileName,
                              );
                              if (isBookmarked) {
                                ToastUtils.showToast(context, '${loc.bookmarkRemoved}: ${state.currentFileName}');
                              } else {
                                ToastUtils.showToast(context, '${loc.bookmarkAdded}: ${state.currentFileName}');
                              }
                            },
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.info_outline, color: Colors.white),
                        onPressed: () => _showImageInfo(context, state),
                      ),
                      IconButton(
                        icon: const Icon(Icons.more_vert, color: Colors.white),
                        onPressed: () => _showMoreMenu(context, state, notifier),
                      ),
                    ],
                  ),
                ),
              ),
            // 图片显示区域
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 背景和图片
                  ColoredBox(
                    color: Colors.black,
                    child: Center(
                      child: GestureDetector(
                        onTap: () => notifier.toggleUIVisibility(),
                        child: Transform(
                          transform: Matrix4.identity()
                            ..scale(state.currentScale)
                            ..rotateZ(state.rotation * 3.14159 / 180),
                          alignment: Alignment.center,
                          child: Transform.flip(
                            flipX: state.isFlippedHorizontal,
                            flipY: state.isFlippedVertical,
                            child: Image.file(
                              File(state.currentPath),
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.high,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // 左侧切换按钮
                  if (state.isUIVisible && state.canGoPrevious)
                    Positioned(
                      left: 8,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: IconButton(
                          icon: const Icon(Icons.chevron_left, color: Colors.white, size: 40),
                          onPressed: () => notifier.goToPrevious(),
                        ),
                      ),
                    ),
                  // 右侧切换按钮
                  if (state.isUIVisible && state.canGoNext)
                    Positioned(
                      right: 8,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: IconButton(
                          icon: const Icon(Icons.chevron_right, color: Colors.white, size: 40),
                          onPressed: () => notifier.goToNext(),
                        ),
                      ),
                    ),
                  // 加载指示器
                  if (state.isLoading)
                    const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                ],
              ),
            ),
            // 底部工具栏
            if (state.isUIVisible)
              Container(
                color: Colors.black.withOpacity(0.7),
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: SafeArea(
                  top: false,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.rotate_left, color: Colors.white),
                        onPressed: () => notifier.rotateLeft(),
                      ),
                      IconButton(
                        icon: const Icon(Icons.rotate_right, color: Colors.white),
                        onPressed: () => notifier.rotateRight(),
                      ),
                      IconButton(
                        icon: const Icon(Icons.flip, color: Colors.white),
                        onPressed: () => notifier.flipHorizontal(),
                      ),
                      IconButton(
                        icon: const Icon(Icons.flip_to_back, color: Colors.white),
                        onPressed: () => notifier.flipVertical(),
                      ),
                      IconButton(
                        icon: const Icon(Icons.zoom_in, color: Colors.white),
                        onPressed: () => notifier.zoomIn(),
                      ),
                      IconButton(
                        icon: const Icon(Icons.zoom_out, color: Colors.white),
                        onPressed: () => notifier.zoomOut(),
                      ),
                      IconButton(
                        icon: const Icon(Icons.fit_screen, color: Colors.white),
                        onPressed: () => notifier.resetTransform(),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showFlipMenu(BuildContext context, ImageViewerNotifier notifier) {
    final loc = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black87,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.flip, color: Colors.white),
              title: Text(loc.flipHorizontal, style: const TextStyle(color: Colors.white)),
              onTap: () {
                notifier.flipHorizontal();
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.flip_to_back, color: Colors.white),
              title: Text(loc.flipVertical, style: const TextStyle(color: Colors.white)),
              onTap: () {
                notifier.flipVertical();
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showImageInfo(BuildContext context, ImageViewerState state) {
    final loc = AppLocalizations.of(context)!;
    final info = state.imageInfo;
    if (info == null) return;

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
              Text('${loc.fileName}: ${info.fileName}', style: const TextStyle(color: Colors.white)),
              const SizedBox(height: 8),
              Text('${loc.filePath}: ${info.filePath}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 8),
              Text('${loc.dimensions}: ${info.width} × ${info.height} ${loc.pixels}', style: const TextStyle(color: Colors.white)),
              const SizedBox(height: 8),
              Text('${loc.fileSize}: ${_formatFileSize(info.fileSize)}', style: const TextStyle(color: Colors.white)),
              const SizedBox(height: 8),
              Text('${loc.format}: ${info.format}', style: const TextStyle(color: Colors.white)),
              const SizedBox(height: 8),
              Text('${loc.modifiedTime}: ${_formatDateTime(info.modifiedAt)}', style: const TextStyle(color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }

  void _showMoreMenu(BuildContext context, ImageViewerState state, ImageViewerNotifier notifier) {
    final loc = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black87,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Consumer(
              builder: (context, ref, child) {
                final bookmarks = ref.watch(imageBookmarkProvider);
                final isBookmarked = bookmarks.any((b) => b.imagePath == state.currentPath);
                return ListTile(
                  leading: Icon(
                    isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                    color: Colors.white,
                  ),
                  title: Text(
                    isBookmarked ? loc.removeBookmark : loc.addBookmark,
                    style: const TextStyle(color: Colors.white),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    await ref.read(imageBookmarkProvider.notifier).toggleBookmark(
                      state.currentPath,
                      state.currentFileName,
                    );
                    if (isBookmarked) {
                      ToastUtils.showToast(context, '${loc.bookmarkRemoved}: ${state.currentFileName}');
                    } else {
                      ToastUtils.showToast(context, '${loc.bookmarkAdded}: ${state.currentFileName}');
                    }
                  },
                );
              },
            )
          ],
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

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
