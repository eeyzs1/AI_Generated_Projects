import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../data/models/play_history.dart';
import '../../../providers/history_provider.dart';
import '../../../providers/thumbnail_provider.dart';
import '../../../router/app_router.dart';
import '../../../../core/utils/toast_utils.dart';
import '../../../../core/localization/app_localizations.dart';

class HistoryListItem extends ConsumerWidget {
  final PlayHistory history;

  const HistoryListItem({super.key, required this.history});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isVideo = history.type == MediaType.video;
    bool isFileExists;
    if (history.path.startsWith('content://')) {
      isFileExists = true;
    } else {
      isFileExists = File(history.path).existsSync();
    }

    return ListTile(
      leading: _buildThumbnail(context, ref),
      title: Text(
        history.displayName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          decoration: !isFileExists ? TextDecoration.lineThrough : null,
          color: !isFileExists ? Colors.grey : null,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_formatDateTime(history.lastPlayedAt)} • ${history.playCount}次',
            style: Theme.of(context).textTheme.labelSmall,
          ),
          if (isVideo && history.totalDuration != null)
            SizedBox(
              height: 4,
              child: LinearProgressIndicator(
                value: history.progress,
                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
            ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isVideo && history.totalDuration != null)
            Text(history.progressString),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            onPressed: () async {
              await ref.read(historyActionsProvider).deleteHistory(history.id);
              if (context.mounted) {
                final loc = AppLocalizations.of(context)!;
                ToastUtils.showToast(context, '${loc.deleted}: ${history.displayName}');
              }
            },
          ),
        ],
      ),
      onTap: () {
        if (isFileExists) {
          if (isVideo) {
            appRouter.push('/video-player', extra: {
              'path': history.path,
              'name': history.displayName,
            });
          } else {
            appRouter.push('/image-viewer', extra: {
              'path': history.path,
              'name': history.displayName,
            });
          }
        }
      },
    );
  }

  Widget _buildThumbnail(BuildContext context, WidgetRef ref) {
    final isVideo = history.type == MediaType.video;
    
    return Consumer(
      builder: (context, ref, child) {
        final thumbnailAsync = ref.watch(thumbnailGeneratorProvider((
          filePath: history.path,
          displayName: history.displayName,
          type: history.type,
        )));
        
        return thumbnailAsync.when(
          data: (thumbPath) {
            if (thumbPath != null && File(thumbPath).existsSync()) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.file(
                  File(thumbPath),
                  width: 72,
                  height: 72,
                  fit: BoxFit.cover,
                ),
              );
            } else {
              return Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(
                  isVideo ? Icons.video_file : Icons.image,
                  size: 32,
                  color: Colors.grey[400],
                ),
              );
            }
          },
          loading: () => Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
          error: (error, stackTrace) => Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(
              isVideo ? Icons.video_file : Icons.image,
              size: 32,
              color: Colors.grey[400],
            ),
          ),
        );
      },
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      return '今天 ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return '昨天 ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}天前';
    } else {
      return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}';
    }
  }
}