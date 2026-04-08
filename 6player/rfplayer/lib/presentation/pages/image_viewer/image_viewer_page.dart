import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../../providers/image_viewer_provider.dart';
import '../../providers/image_bookmark_provider.dart';
import '../../providers/thumbnail_provider.dart';
import '../../providers/database_provider.dart';
import '../../../data/models/play_history.dart' as ph;
import '../../../core/utils/toast_utils.dart';
import '../../../core/utils/real_path_utils.dart';
import '../../../core/localization/app_localizations.dart';

class ImageViewerPage extends ConsumerStatefulWidget {
  final String path;
  final String? fileName;
  final Uint8List? bytes;

  const ImageViewerPage({super.key, required this.path, this.fileName, this.bytes});

  @override
  ConsumerState<ImageViewerPage> createState() => _ImageViewerPageState();
}

class _ImageViewerPageState extends ConsumerState<ImageViewerPage> {
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
  
  @override
  void initState() {
    super.initState();
    debugPrint('[ImageViewerPage] ======== 图片查看器初始化 ========');
    debugPrint('[ImageViewerPage] path: ${widget.path}');
    debugPrint('[ImageViewerPage] fileName: ${widget.fileName}');
    debugPrint('[ImageViewerPage] bytes: ${widget.bytes != null ? '有数据，长度: ${widget.bytes!.length}' : '无数据'}');
    _updateHistory();
  }
  
  Future<void> _updateHistory() async {
    if (!mounted) return;
    
    try {
      // 先确保使用安全路径，避免同一个文件被保存多次
      final safePath = await RealPathUtils.getSafePath(widget.path);
      final pathToUse = safePath ?? widget.path;
      
      debugPrint('[ImageViewerPage] 原路径: ${widget.path}');
      debugPrint('[ImageViewerPage] 安全路径: $pathToUse');
      
      final historyRepo = ref.read(historyRepositoryProvider);
      var history = await historyRepo.getByPath(pathToUse);
      
      String extension;
      if (widget.fileName != null) {
        // 从 fileName 中提取扩展名
        final ext = p.extension(widget.fileName!).toLowerCase();
        extension = ext.length > 1 ? ext.substring(1) : ext;
      } else {
        // 从 path 中提取扩展名
        final ext = p.extension(pathToUse).toLowerCase();
        extension = ext.length > 1 ? ext.substring(1) : ext;
      }
      
      if (history == null) {
        history = ph.PlayHistory(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          path: pathToUse,
          displayName: widget.fileName ?? p.basename(pathToUse),
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
      debugPrint('[ImageViewerPage] 更新历史记录失败: $e');
    }
  }
  
  Future<void> _generateThumbnailAsync() async {
    if (!mounted) return;
    
    try {
      // 先确保使用安全路径
      final safePath = await RealPathUtils.getSafePath(widget.path);
      final pathToUse = safePath ?? widget.path;
      
      final thumbnailService = ref.read(thumbnailServiceProvider);
      final historyRepo = ref.read(historyRepositoryProvider);
      
      final thumbPath = await thumbnailService.generateThumbnail(pathToUse);
      
      if (thumbPath != null && mounted) {
        var history = await historyRepo.getByPath(pathToUse);
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
      debugPrint('[ImageViewerPage] 生成缩略图失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final params = ImageViewerParams(
      path: widget.path,
      customFileName: widget.fileName,
      initialBytes: widget.bytes,
    );
    final state = ref.watch(imageViewerProvider(params));
    final notifier = ref.read(imageViewerProvider(params).notifier);

    return ScaffoldMessenger(
      key: _scaffoldMessengerKey,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Column(
          children: [
            // 顶部工具栏
            if (state.isUIVisible)
              Container(
                color: Colors.black.withValues(alpha: 0.7),
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
                              if (mounted) {
                                if (isBookmarked) {
                                  // ignore: use_build_context_synchronously
                                  ToastUtils.showToast(context, '${loc.bookmarkRemoved}: ${state.currentFileName}');
                                } else {
                                  // ignore: use_build_context_synchronously
                                  ToastUtils.showToast(context, '${loc.bookmarkAdded}: ${state.currentFileName}');
                                }
                              }
                            },
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.info_outline, color: Colors.white),
                        onPressed: () => _showImageInfo(context, state),
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
                            // ignore: deprecated_member_use
                            ..scale(state.currentScale, state.currentScale, 1.0)
                            ..rotateZ(state.rotation * 3.14159 / 180),
                          alignment: Alignment.center,
                          child: Transform.flip(
                            flipX: state.isFlippedHorizontal,
                            flipY: state.isFlippedVertical,
                            child: _buildImageWidget(state),
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
                color: Colors.black.withValues(alpha: 0.7),
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

  String? _tryExtractRealPathFromContentUri(String contentUri) {
    debugPrint('[ImageViewerPage] 尝试从 content URI 提取真实路径: $contentUri');
    
    // 处理格式: content://com.android.providers.downloads.documents/document/raw%3A%2Fstorage%2Femulated%2F0%2FDownload%2Fimage_test.png
    // 或者格式: content://com.android.providers.downloads.documents/document/msf%3A1000000051
    if (contentUri.contains('/document/')) {
      final parts = contentUri.split('/document/');
      if (parts.length == 2) {
        final encodedPath = parts[1];
        debugPrint('[ImageViewerPage] 找到编码部分: $encodedPath');
        
        // 检查常见的前缀并移除
        String pathToDecode = encodedPath;
        if (pathToDecode.startsWith('raw%3A')) {
          pathToDecode = pathToDecode.substring(6);
          debugPrint('[ImageViewerPage] 移除 raw: 前缀');
        } else if (pathToDecode.startsWith('msf%3A')) {
          debugPrint('[ImageViewerPage] 检测到 msf: 前缀（MediaStore ID），无法直接提取真实路径');
          // msf: 后面是 MediaStore ID，不是文件路径，返回 null
          return null;
        }
        
        // URL 解码
        try {
          final decodedPath = Uri.decodeComponent(pathToDecode);
          debugPrint('[ImageViewerPage] URL 解码后: $decodedPath');
          
          // 检查是否是一个绝对路径
          if (decodedPath.startsWith('/')) {
            debugPrint('[ImageViewerPage] 提取到真实路径: $decodedPath');
            return decodedPath;
          }
        } catch (e) {
          debugPrint('[ImageViewerPage] URL 解码失败: $e');
        }
      }
    }
    
    debugPrint('[ImageViewerPage] 无法从 content URI 提取真实路径');
    return null;
  }

  Widget _buildImageWidget(ImageViewerState state) {
    debugPrint('[ImageViewerPage] ======== 构建图片组件 ========');
    debugPrint('[ImageViewerPage] state.currentPath: ${state.currentPath}');
    debugPrint('[ImageViewerPage] widget.bytes: ${widget.bytes != null ? '有数据' : '无数据'}');
    debugPrint('[ImageViewerPage] state.imageInfo: ${state.imageInfo != null ? '存在' : '不存在'}');
    debugPrint('[ImageViewerPage] state.imageInfo.bytes: ${state.imageInfo?.bytes != null ? '有数据' : '无数据'}');
    debugPrint('[ImageViewerPage] state.isLoading: ${state.isLoading}');
    
    // 优先使用通过 widget 传递过来的字节数据
    if (widget.bytes != null) {
      debugPrint('[ImageViewerPage] 使用 widget.bytes 显示图片，字节长度: ${widget.bytes!.length}');
      return Image.memory(
        widget.bytes!,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      );
    }
    
    // 然后尝试使用 state.imageInfo.bytes
    if (state.imageInfo != null && state.imageInfo!.bytes != null) {
      debugPrint('[ImageViewerPage] 使用 state.imageInfo.bytes 显示图片，字节长度: ${state.imageInfo!.bytes!.length}');
      return Image.memory(
        state.imageInfo!.bytes!,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      );
    }
    
    // 如果是加载中状态，显示加载指示器
    if (state.isLoading) {
      debugPrint('[ImageViewerPage] 正在加载，显示加载指示器');
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }
    
    // 最后使用 Image.file 显示普通文件
    debugPrint('[ImageViewerPage] 使用 Image.file 显示普通文件，路径: ${state.currentPath}');
    return Image.file(
      File(state.currentPath),
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    );
  }
}
