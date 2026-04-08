import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/video_bookmark_provider.dart';
import '../../providers/image_bookmark_provider.dart';
import '../../providers/thumbnail_provider.dart';
import '../../../data/models/video_bookmark.dart';
import '../../../core/utils/toast_utils.dart';
import '../../../core/localization/app_localizations.dart';

class BookmarkPage extends ConsumerStatefulWidget {
  const BookmarkPage({super.key});

  @override
  ConsumerState<BookmarkPage> createState() => _BookmarkPageState();
}

class _BookmarkPageState extends ConsumerState<BookmarkPage> {
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final videoBookmarks = ref.watch(videoBookmarkProvider);
    final imageBookmarks = ref.watch(imageBookmarkProvider);

    return ScaffoldMessenger(
      key: _scaffoldMessengerKey,
      child: Scaffold(
        appBar: AppBar(
          title: Text(loc.bookmarks),
          actions: [
            if (videoBookmarks.isNotEmpty || imageBookmarks.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.delete_sweep),
                onPressed: () {
                  _showClearAllDialog();
                },
              ),
          ],
        ),
        body: videoBookmarks.isEmpty && imageBookmarks.isEmpty
            ? Center(child: Text(loc.noBookmarks))
            : ListView(
                children: [
                  if (imageBookmarks.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text(
                        loc.imageBookmarks,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    ...imageBookmarks.map((bookmark) {
                      return ListTile(
                        leading: _buildImageThumbnail(bookmark.imagePath),
                        title: Text(bookmark.imageName),
                        subtitle: Text(
                          _formatDateTime(bookmark.createdAt),
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () {
                            ref.read(imageBookmarkProvider.notifier).deleteBookmark(bookmark.id);
                            ToastUtils.showToast(
                              context,
                              '${loc.bookmarkDeleted}: ${bookmark.imageName}',
                            );
                          },
                        ),
                        onTap: () {
                          _openImage(bookmark.imagePath);
                        },
                      );
                    }),
                  ],
                  if (videoBookmarks.isNotEmpty) ...[
                    if (imageBookmarks.isNotEmpty) const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Text(
                        loc.videoBookmarks,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    ..._buildVideoBookmarkList(videoBookmarks),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _buildImageThumbnail(String imagePath) {
    return Consumer(
      builder: (context, ref, child) {
        final thumbnailAsync = ref.watch(cachedThumbnailProvider(imagePath));

        return thumbnailAsync.when(
          data: (thumbPath) {
            if (thumbPath != null && File(thumbPath).existsSync()) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.file(
                  File(thumbPath),
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                ),
              );
            } else {
              return _buildPlaceholderIcon(Icons.image, Colors.green);
            }
          },
          loading: () => _buildPlaceholderLoading(),
          error: (_, _) => _buildPlaceholderIcon(Icons.image, Colors.green),
        );
      },
    );
  }

  Widget _buildVideoThumbnail(String videoPath) {
    return Consumer(
      builder: (context, ref, child) {
        final thumbnailAsync = ref.watch(cachedThumbnailProvider(videoPath));

        return thumbnailAsync.when(
          data: (thumbPath) {
            if (thumbPath != null && File(thumbPath).existsSync()) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.file(
                  File(thumbPath),
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                ),
              );
            } else {
              return _buildPlaceholderIcon(Icons.video_file, Colors.blue);
            }
          },
          loading: () => _buildPlaceholderLoading(),
          error: (_, _) => _buildPlaceholderIcon(Icons.video_file, Colors.blue),
        );
      },
    );
  }

  Widget _buildPlaceholderIcon(IconData icon, Color color) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(4),
      ),
      child: Icon(icon, size: 28, color: color),
    );
  }

  Widget _buildPlaceholderLoading() {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }

  List<Widget> _buildVideoBookmarkList(List<VideoBookmark> videoBookmarks) {
    final loc = AppLocalizations.of(context)!;
    final groupedBookmarks = <String, List<VideoBookmark>>{};
    for (final bookmark in videoBookmarks) {
      if (!groupedBookmarks.containsKey(bookmark.videoPath)) {
        groupedBookmarks[bookmark.videoPath] = [];
      }
      groupedBookmarks[bookmark.videoPath]!.add(bookmark);
    }

    return groupedBookmarks.entries.map((entry) {
      final bookmarks = entry.value;
      final videoName = bookmarks.first.videoName;
      final videoPath = entry.key;

      return ExpansionTile(
        leading: _buildVideoThumbnail(videoPath),
        title: Text(videoName),
        subtitle: Text('${bookmarks.length} ${loc.bookmarksCount}'),
        children: bookmarks.map((bookmark) {
          return ListTile(
            leading: const Icon(Icons.bookmark, color: Colors.amber),
            title: Text(_formatDuration(bookmark.position)),
            subtitle: bookmark.note != null
                ? Text(bookmark.note!)
                : null,
            trailing: IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () {
                ref.read(videoBookmarkProvider.notifier).deleteBookmark(bookmark.id);
                ToastUtils.showToast(
                  context,
                  '${loc.bookmarkDeleted}: ${_formatDuration(bookmark.position)}',
                );
              },
            ),
            onTap: () {
              _openVideoAtPosition(bookmark.videoPath, bookmark.position);
            },
          );
        }).toList(),
      );
    }).toList();
  }

  void _showClearAllDialog() {
    final loc = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(loc.clearAllBookmarks),
        content: Text(loc.sureToClearAllBookmarks),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(loc.cancel),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final videoBookmarks = ref.read(videoBookmarkProvider);
              for (final bookmark in videoBookmarks) {
                await ref.read(videoBookmarkProvider.notifier).deleteBookmark(bookmark.id);
              }
              final imageBookmarks = ref.read(imageBookmarkProvider);
              for (final bookmark in imageBookmarks) {
                await ref.read(imageBookmarkProvider.notifier).deleteBookmark(bookmark.id);
              }
              if (mounted) {
                // ignore: use_build_context_synchronously
                ToastUtils.showToast(context, loc.allBookmarksCleared);
              }
            },
            child: Text(loc.clearAll),
          ),
        ],
      ),
    );
  }

  Future<void> _openVideoAtPosition(String videoPath, Duration position) async {
    if (mounted) {
      context.push('/video-player', extra: {
        'path': videoPath,
        'position': position,
      });
    }
  }

  Future<void> _openImage(String imagePath) async {
    if (mounted) {
      context.push('/image-viewer', extra: imagePath);
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

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
