import 'dart:io';
import 'package:flutter/material.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/bookmark.dart';
import '../../../presentation/providers/database_provider.dart';
import '../../../presentation/providers/image_viewer_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as p;

class ImageViewerPage extends ConsumerStatefulWidget {
  final String path;

  const ImageViewerPage({super.key, required this.path});

  @override
  ConsumerState<ImageViewerPage> createState() => _ImageViewerPageState();
}

class _ImageViewerPageState extends ConsumerState<ImageViewerPage> {
  @override
  Widget build(BuildContext context) {
    final imageViewerState = ref.watch(imageViewerProvider(widget.path));
    final imageViewerNotifier = ref.read(imageViewerProvider(widget.path).notifier);
    
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          imageViewerState.currentImageName,
          style: const TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          icon: const Icon(Icons.arrow_back, color: Colors.white),
        ),
        actions: [
          IconButton(
            onPressed: () => _addBookmarkForPath(ref, imageViewerState.currentImagePath),
            icon: const Icon(
              Icons.bookmark_add,
              color: Colors.white,
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          GestureDetector(
            onTap: () {
              Navigator.of(context).pop();
            },
            child: Center(
              child: ExtendedImage.file(
                File(imageViewerState.currentImagePath),
                fit: BoxFit.contain,
                mode: ExtendedImageMode.gesture,
                initGestureConfigHandler: (state) {
                  return GestureConfig(
                    minScale: 0.5,
                    maxScale: 5.0,
                    speed: 1.0,
                    inertialSpeed: 100.0,
                    initialScale: 1.0,
                    inPageView: false,
                  );
                },
                onDoubleTap: (state) {
                  final pointerDownPosition = state.pointerDownPosition;
                  final begin = state.gestureDetails!.totalScale;
                  double end;
                  if (begin == 1.0) {
                    end = 3.0;
                  } else {
                    end = 1.0;
                  }
                  state.handleDoubleTap(
                    scale: end,
                    doubleTapPosition: pointerDownPosition,
                  );
                },
                loadStateChanged: (state) {
                  if (state.extendedImageLoadState == LoadState.loading) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Colors.blue,
                      ),
                    );
                  }
                  return null;
                },
              ),
            ),
          ),
          // 左右切换按钮
          if (imageViewerState.totalImages > 1) ...[
            Positioned(
              left: 16,
              top: MediaQuery.of(context).size.height / 2,
              child: IconButton(
                onPressed: imageViewerState.canGoPrevious
                    ? () => imageViewerNotifier.navigateToImage(imageViewerState.currentIndex - 1)
                    : null,
                icon: const Icon(Icons.chevron_left, color: Colors.white, size: 48),
                disabledColor: Colors.white.withOpacity(0.3),
              ),
            ),
            Positioned(
              right: 16,
              top: MediaQuery.of(context).size.height / 2,
              child: IconButton(
                onPressed: imageViewerState.canGoNext
                    ? () => imageViewerNotifier.navigateToImage(imageViewerState.currentIndex + 1)
                    : null,
                icon: const Icon(Icons.chevron_right, color: Colors.white, size: 48),
                disabledColor: Colors.white.withOpacity(0.3),
              ),
            ),
          ],
          // 图片信息
          if (imageViewerState.totalImages > 1)
            Positioned(
              bottom: 32,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${imageViewerState.currentIndex + 1} / ${imageViewerState.totalImages}',
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _addBookmarkForPath(WidgetRef ref, String path) async {
    final bookmarkRepository = ref.read(bookmarkRepositoryProvider);
    final bookmark = Bookmark(
      id: const Uuid().v4(),
      path: path,
      displayName: p.basename(path),
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
}