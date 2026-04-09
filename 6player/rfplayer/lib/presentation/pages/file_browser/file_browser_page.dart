import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fast_file_picker/fast_file_picker.dart';
import 'package:file_selector/file_selector.dart';
import '../../router/app_router.dart';
import '../../providers/history_provider.dart';
import '../../providers/thumbnail_provider.dart';
import '../../providers/permission_provider.dart';
import '../../../data/models/play_history.dart';
import '../../../core/extensions/string_extensions.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/constants/supported_formats.dart';
import '../../../core/utils/real_path_utils.dart';

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
    debugPrint('[FileBrowser] ======== 开始选择文件 ========');
    
    // 检查/请求存储权限
    final permissionState = ref.read(permissionProvider);
    if (!permissionState.hasStoragePermission) {
      debugPrint('[FileBrowser] 没有存储权限，请求权限...');
      final permissionNotifier = ref.read(permissionProvider.notifier);
      final granted = await permissionNotifier.requestStoragePermission();
      if (!granted) {
        debugPrint('[FileBrowser] 权限被拒绝，无法选择文件');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Permission denied: Storage permission'),
              duration: const Duration(seconds: 3),
            ),
          );
        }
        return;
      }
      debugPrint('[FileBrowser] 权限已授予');
    }
    
    final videoTypeGroup = XTypeGroup(
      label: 'Video Files',
      extensions: videoFormats.toList(),
    );
    final imageTypeGroup = XTypeGroup(
      label: 'Image Files',
      extensions: imageFormats.toList(),
    );
    debugPrint('[FileBrowser] 等待用户选择文件...');
    final result = await FastFilePicker.pickFile(
      acceptedTypeGroups: [videoTypeGroup, imageTypeGroup],
    );

    debugPrint('[FileBrowser] pickFile result: $result');
    debugPrint('[FileBrowser] result.uri: ${result?.uri}');
    debugPrint('[FileBrowser] result.path: ${result?.path}');
    debugPrint('[FileBrowser] result.name: ${result?.name}');
    
    if (result != null) {
      String? pathToUse;
      Uint8List? imageBytes;
      
      debugPrint('[FileBrowser] ======== 处理选择的文件 ========');
      
      if (result.path != null) {
        // 普通文件路径
        pathToUse = result.path;
        debugPrint('[FileBrowser] 使用普通文件路径: $pathToUse');
      } else if (result.uri != null) {
        // Content URI，使用 RealPathUtils 转换为安全路径
        final contentUri = result.uri.toString();
        debugPrint('[FileBrowser] 获得 content URI，尝试转换为安全路径: $contentUri');
        
        // 使用 RealPathUtils.getSafePath 转换为安全路径（永远不会是 content URI）
        pathToUse = await RealPathUtils.getSafePath(contentUri);
        
        if (pathToUse == null) {
          debugPrint('[FileBrowser] 无法将 content URI 转换为安全路径，不使用该文件');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('无法访问该文件，请使用文件选择器重新选择'),
                duration: Duration(seconds: 3),
              ),
            );
          }
          return;
        }
        
        debugPrint('[FileBrowser] 成功转换为安全路径: $pathToUse');
      }
      
      debugPrint('[FileBrowser] pathToUse: $pathToUse, name: ${result.name}');
      if (pathToUse != null) {
        if (mounted) {
          // 优先使用文件名判断文件类型，因为 URI 可能不包含扩展名
          final isVideo = result.name.isVideoFile || pathToUse.isVideoFile;
          final isImage = result.name.isImageFile || pathToUse.isImageFile;
          debugPrint('[FileBrowser] isVideo: $isVideo, isImage: $isImage');
          
          if (isVideo) {
            debugPrint('[FileBrowser] 是视频文件，跳转到视频播放器');
            appRouter.push('/video-player', extra: {
              'path': pathToUse,
              'name': result.name,
            });
          } else if (isImage) {
            debugPrint('[FileBrowser] 是图片文件，开始读取字节数据...');
            // 尝试读取图片字节
            try {
              debugPrint('[FileBrowser] 使用安全路径读取图片字节...');
              final file = File(pathToUse);
              if (await file.exists()) {
                debugPrint('[FileBrowser] 文件存在，开始读取...');
                imageBytes = await file.readAsBytes();
                debugPrint('[FileBrowser] 读取成功，字节数: ${imageBytes.length}');
              } else {
                debugPrint('[FileBrowser] 文件不存在!');
              }
            } catch (e, stackTrace) {
              debugPrint('[FileBrowser] Error reading image bytes: $e');
              debugPrint('[FileBrowser] Stack trace: $stackTrace');
            }
            
            debugPrint('[FileBrowser] 准备跳转到图片查看器，字节数据: ${imageBytes != null ? '有' : '无'}');
            appRouter.push('/image-viewer', extra: {
              'path': pathToUse,
              'name': result.name,
              'bytes': imageBytes,
            });
          }
        }
      }
    } else {
      debugPrint('[FileBrowser] 用户取消了选择');
    }
  }

  void _showClearAllDialog() {
    final loc = AppLocalizations.of(context)!;
    final scaffoldMessenger = ScaffoldMessenger.of(context);
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
              Navigator.pop(context);
              await ref.read(historyActionsProvider).clearAllHistory();
              if (!mounted) return;
              scaffoldMessenger.showSnackBar(
                SnackBar(content: Text(loc.historyCleared)),
              );
            },
            child: Text(loc.clearAll),
          ),
        ],
      ),
    );
  }
}

class _HistoryListItem extends ConsumerStatefulWidget {
  final PlayHistory history;

  const _HistoryListItem({required this.history});

  @override
  ConsumerState<_HistoryListItem> createState() => _HistoryListItemState();
}

class _HistoryListItemState extends ConsumerState<_HistoryListItem> {

  Widget _buildThumbnail(BuildContext context, WidgetRef ref) {
    final isVideo = widget.history.type == MediaType.video;
    
    return Consumer(
      builder: (context, ref, child) {
        final thumbnailAsync = ref.watch(thumbnailGeneratorProvider((
          filePath: widget.history.path,
          displayName: widget.history.displayName,
          type: widget.history.type,
        )));
        
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
            }
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
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final isVideo = widget.history.type == MediaType.video;
        bool isFileExists;
        if (RealPathUtils.isContentUri(widget.history.path)) {
          // 对于 content URI，尝试转换为安全路径后检查
          isFileExists = true; // 暂时假设存在，点击时会再次验证
        } else {
          isFileExists = File(widget.history.path).existsSync();
        }

        return ListTile(
          leading: _buildThumbnail(context, ref),
          title: Text(
            widget.history.displayName,
            style: TextStyle(
              decoration: !isFileExists ? TextDecoration.lineThrough : null,
              color: !isFileExists ? Colors.grey : null,
            ),
          ),
          subtitle: Text(
            _formatDateTime(widget.history.lastPlayedAt),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              await ref.read(historyActionsProvider).deleteHistory(widget.history.id);
            },
          ),
          onTap: () async {
            debugPrint('[HistoryListItem] ======== 点击历史记录 ========');
            debugPrint('[HistoryListItem] 原始路径: ${widget.history.path}');
            
            // 使用 RealPathUtils.getSafePath 转换为安全路径（永远不会是 content URI）
            final pathToUse = await RealPathUtils.getSafePath(widget.history.path);
            
            if (pathToUse == null) {
              debugPrint('[HistoryListItem] 无法转换为安全路径');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('无法访问该文件，请重新选择'),
                    duration: Duration(seconds: 3),
                  ),
                );
              }
              return;
            }
            
            debugPrint('[HistoryListItem] 使用安全路径: $pathToUse');
            
            if (isVideo) {
              debugPrint('[HistoryListItem] 是视频文件，跳转到视频播放器');
              appRouter.push('/video-player', extra: {
                'path': pathToUse,
                'name': widget.history.displayName,
              });
            } else {
              debugPrint('[HistoryListItem] 是图片文件，跳转到图片查看器');
              appRouter.push('/image-viewer', extra: {
                'path': pathToUse,
                'name': widget.history.displayName,
              });
            }
          },
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
