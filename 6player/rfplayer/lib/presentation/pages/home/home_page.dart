import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/database_provider.dart';
import '../../providers/thumbnail_provider.dart';
import '../../providers/play_queue_provider.dart';
import '../../../data/models/play_history.dart';
import '../../../data/models/bookmark.dart';
import 'package:go_router/go_router.dart';
import '../../../core/localization/app_localizations.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizations = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.appName),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              localizations.recentPlays,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildRecentPlays(context, ref),
            const SizedBox(height: 32),
            Text(
              localizations.bookmarks,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildBookmarks(context, ref),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentPlays(BuildContext context, WidgetRef ref) {
    final historyRepository = ref.watch(historyRepositoryProvider);
    return StreamBuilder<List<PlayHistory>>(
      stream: historyRepository.watchHistory(limit: 5),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          final localizations = AppLocalizations.of(context)!;
          return Center(child: Text(localizations.loadingFailed));
        }
        final history = snapshot.data ?? [];
        if (history.isEmpty) {
          final localizations = AppLocalizations.of(context)!;
          return Center(child: Text(localizations.noRecentPlays));
        }
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: history.length,
          itemBuilder: (context, index) {
            final item = history[index];
            return Consumer(
              builder: (context, ref, child) {
                final thumbnail = ref.watch(thumbnailGeneratorProvider(item.path));
                return ListTile(
                  leading: thumbnail.when(
                    data: (path) {
                      if (path != null) {
                        return Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                          ),
                          child: Image.file(
                            File(path),
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(
                                item.type == MediaType.video ? Icons.video_library : Icons.image,
                                size: 40,
                              );
                            },
                          ),
                        );
                      } else {
                        return Icon(
                          item.type == MediaType.video ? Icons.video_library : Icons.image,
                          size: 40,
                        );
                      }
                    },
                    loading: () => const CircularProgressIndicator(),
                    error: (error, stackTrace) {
                      return Icon(
                        item.type == MediaType.video ? Icons.video_library : Icons.image,
                        size: 40,
                      );
                    },
                  ),
                  title: Text(item.displayName),
                  subtitle: Text(item.progressString),
                  onTap: () async {
                    if (item.type == MediaType.video) {
                      // 将视频添加到播放队列
                      final playQueueNotifier = ref.read(playQueueProvider.notifier);
                      await playQueueNotifier.addToQueue(item.path, item.displayName);
                      
                      // 使用 push 导航到视频播放器页面
                      // 这样当用户点击返回按钮时，会返回到之前的页面
                      GoRouter.of(context).push('/video-player', extra: item.path);
                    } else {
                      GoRouter.of(context).push('/image-viewer', extra: item.path);
                    }
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildBookmarks(BuildContext context, WidgetRef ref) {
    final bookmarkRepository = ref.watch(bookmarkRepositoryProvider);
    return StreamBuilder<List<Bookmark>>(
      stream: bookmarkRepository.watchAll(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          final localizations = AppLocalizations.of(context)!;
          return Center(child: Text(localizations.loadingFailed));
        }
        final bookmarks = snapshot.data ?? [];
        if (bookmarks.isEmpty) {
          final localizations = AppLocalizations.of(context)!;
          return Center(child: Text(localizations.noBookmarks));
        }
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: bookmarks.length,
          itemBuilder: (context, index) {
            final bookmark = bookmarks[index];
            return ListTile(
              leading: const Icon(Icons.bookmark, size: 40),
              title: Text(bookmark.displayName),
              onTap: () async {
                // 这里需要根据文件类型决定打开方式
                // 暂时默认作为视频打开
                final playQueueNotifier = ref.read(playQueueProvider.notifier);
                await playQueueNotifier.addToQueue(bookmark.path, bookmark.displayName);
                
                // 使用 push 导航到视频播放器页面
                // 这样当用户点击返回按钮时，会返回到之前的页面
                GoRouter.of(context).push('/video-player', extra: bookmark.path);
              },
              trailing: IconButton(
                onPressed: () {
                  final localizations = AppLocalizations.of(context)!;
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text(localizations.confirmDelete),
                      content: Text(localizations.sureToDelete),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(localizations.cancel),
                        ),
                        TextButton(
                          onPressed: () async {
                            final bookmarkRepository = ref.read(bookmarkRepositoryProvider);
                            await bookmarkRepository.deleteById(bookmark.id);
                            Navigator.of(context).pop();
                          },
                          child: Text(localizations.confirm),
                        ),
                      ],
                    ),
                  );
                },
                icon: const Icon(Icons.delete),
              ),
            );
          },
        );
      },
    );
  }
}