import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import '../../providers/history_provider.dart';
import '../../providers/thumbnail_provider.dart';
import '../../providers/database_provider.dart';
import '../../../data/models/play_history.dart';
import '../../../core/extensions/string_extensions.dart';
import '../../../core/localization/app_localizations.dart';

class FileBrowserPage extends ConsumerStatefulWidget {
  const FileBrowserPage({super.key});

  @override
  ConsumerState<FileBrowserPage> createState() => _FileBrowserPageState();
}

class _FileBrowserPageState extends ConsumerState<FileBrowserPage> {
  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final historyListAsync = ref.watch(historyProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.fileBrowser),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: () {
              _showClearAllDialog();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 打开文件按钮
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              onPressed: () => _pickFile(),
              icon: const Icon(Icons.folder_open, size: 48),
              label: Text(loc.openFile, style: const TextStyle(fontSize: 32)),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 96),
                padding: const EdgeInsets.symmetric(vertical: 24),
              ),
            ),
          ),
          const Divider(),
          // 最近打开的文件列表
          Expanded(
            child: historyListAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(child: Text('${loc.loadingFailed}: $error')),
              data: (historyList) {
                if (historyList.isEmpty) {
                  return Center(child: Text(loc.noRecentFiles));
                }
                return ListView.builder(
                  itemCount: historyList.length,
                  itemBuilder: (context, index) {
                    final history = historyList[index];
                    return _HistoryListItem(history: history);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );

    if (result != null && result.files.isNotEmpty) {
      final path = result.files.first.path;
      if (path != null) {
        if (mounted) {
          if (path.isVideoFile) {
            context.push('/video-player', extra: path);
          } else if (path.isImageFile) {
            context.push('/image-viewer', extra: path);
          }
        }
      }
    }
  }

  void _showClearAllDialog() {
    final loc = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(loc.clearHistory),
        content: Text(loc.sureToClearHistory),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(loc.cancel),
          ),
          TextButton(
            onPressed: () async {
              await ref.read(historyActionsProvider).clearAllHistory();
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(loc.historyCleared)),
                );
              }
            },
            child: Text(loc.clearAll),
          ),
        ],
      ),
    );
  }
}

class _HistoryListItem extends ConsumerWidget {
  final PlayHistory history;

  const _HistoryListItem({required this.history});

  Widget _buildThumbnail(BuildContext context, WidgetRef ref) {
    final isVideo = history.type == MediaType.video;
    final isFileExists = File(history.path).existsSync();
    
    return Consumer(
      builder: (context, ref, child) {
        final thumbnailAsync = ref.watch(thumbnailGeneratorProvider(history.path));
        
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
              return Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(
                  isVideo ? Icons.video_file : Icons.image,
                  size: 24,
                  color: isVideo ? Colors.blue : Colors.green,
                ),
              );
            }
          },
          loading: () => Container(
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
          ),
          error: (error, stackTrace) => Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(
              isVideo ? Icons.video_file : Icons.image,
              size: 24,
              color: isVideo ? Colors.blue : Colors.green,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isVideo = history.type == MediaType.video;
    final isFileExists = File(history.path).existsSync();

    return ListTile(
      leading: _buildThumbnail(context, ref),
      title: Text(
        history.displayName,
        style: TextStyle(
          decoration: !isFileExists ? TextDecoration.lineThrough : null,
          color: !isFileExists ? Colors.grey : null,
        ),
      ),
      subtitle: Text(
        _formatDateTime(history.lastPlayedAt),
        style: Theme.of(context).textTheme.bodySmall,
      ),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline),
        onPressed: () async {
          await ref.read(historyActionsProvider).deleteHistory(history.id);
        },
      ),
      onTap: () {
        if (isVideo) {
          context.push('/video-player', extra: history.path);
        } else {
          context.push('/image-viewer', extra: history.path);
        }
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