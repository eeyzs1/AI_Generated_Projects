import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fast_file_picker/fast_file_picker.dart';
import 'package:file_selector/file_selector.dart';
import 'package:saf_stream/saf_stream.dart';
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
  final SafStream _safStream = SafStream();
  
  String? _tryExtractRealPathFromContentUri(String contentUri) {
    debugPrint('[FileBrowser] 尝试从 content URI 提取真实路径: $contentUri');
    
    // 处理格式: content://com.android.providers.downloads.documents/document/raw%3A%2Fstorage%2Femulated%2F0%2FDownload%2Fimage_test.png
    // 或者格式: content://com.android.providers.downloads.documents/document/msf%3A1000000051
    if (contentUri.contains('/document/')) {
      final parts = contentUri.split('/document/');
      if (parts.length == 2) {
        final encodedPath = parts[1];
        debugPrint('[FileBrowser] 找到编码部分: $encodedPath');
        
        // 检查常见的前缀并移除
        String pathToDecode = encodedPath;
        if (pathToDecode.startsWith('raw%3A')) {
          pathToDecode = pathToDecode.substring(6);
          debugPrint('[FileBrowser] 移除 raw: 前缀');
        } else if (pathToDecode.startsWith('msf%3A')) {
          debugPrint('[FileBrowser] 检测到 msf: 前缀（MediaStore ID），无法直接提取真实路径');
          // msf: 后面是 MediaStore ID，不是文件路径，返回 null
          return null;
        }
        
        // URL 解码
        try {
          final decodedPath = Uri.decodeComponent(pathToDecode);
          debugPrint('[FileBrowser] URL 解码后: $decodedPath');
          
          // 检查是否是一个绝对路径
          if (decodedPath.startsWith('/')) {
            debugPrint('[FileBrowser] 提取到真实路径: $decodedPath');
            return decodedPath;
          }
        } catch (e) {
          debugPrint('[FileBrowser] URL 解码失败: $e');
        }
      }
    }
    
    debugPrint('[FileBrowser] 无法从 content URI 提取真实路径');
    return null;
  }

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
      extensions: videoFormats,
    );
    final imageTypeGroup = XTypeGroup(
      label: 'Image Files',
      extensions: imageFormats,
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
        pathToUse = result.path;
        debugPrint('[FileBrowser] 使用普通文件路径: $pathToUse');
      } else if (result.uri != null) {
        final contentUri = result.uri.toString();
        debugPrint('[FileBrowser] 获得 content URI: $contentUri');
        
        // 优先使用原生通道获取真实路径
        final permissionState = ref.read(permissionProvider);
        if (permissionState.hasStoragePermission) {
          debugPrint('[FileBrowser] 使用原生通道尝试获取真实路径...');
          final realPathFromNative = await RealPathUtils.getRealPath(contentUri);
          if (realPathFromNative != null) {
            final realFile = File(realPathFromNative);
            if (await realFile.exists()) {
              pathToUse = realPathFromNative;
              debugPrint('[FileBrowser] 原生通道获取到真实路径并存在: $pathToUse');
            }
          }
        }
        
        // 如果原生通道没获取到，尝试我们自己的提取方法
        if (pathToUse == null && permissionState.hasStoragePermission) {
          debugPrint('[FileBrowser] 尝试我们自己的提取方法...');
          final realPath = _tryExtractRealPathFromContentUri(contentUri);
          if (realPath != null) {
            final realFile = File(realPath);
            if (await realFile.exists()) {
              pathToUse = realPath;
              debugPrint('[FileBrowser] 自己的方法提取到真实路径并存在: $pathToUse');
            }
          }
        }
        
        // 如果都没有获取到真实路径，使用 content URI
        if (pathToUse == null) {
          debugPrint('[FileBrowser] 使用 content URI');
          pathToUse = contentUri;
        }
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
              if (result.path != null) {
                // 普通文件路径
                debugPrint('[FileBrowser] 读取普通文件字节...');
                final file = File(result.path!);
                if (await file.exists()) {
                  debugPrint('[FileBrowser] 文件存在，开始读取...');
                  imageBytes = await file.readAsBytes();
                  debugPrint('[FileBrowser] 读取成功，字节数: ${imageBytes.length}');
                } else {
                  debugPrint('[FileBrowser] 文件不存在!');
                }
              } else if (result.uri != null) {
                // Android content URI，使用 saf_stream 读取
                debugPrint('[FileBrowser] 读取 content URI 字节...');
                debugPrint('[FileBrowser] URI: ${result.uri}');
                imageBytes = await _safStream.readFileBytes(result.uri!);
                debugPrint('[FileBrowser] 读取成功，字节数: ${imageBytes.length}');
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
  String? _tryExtractRealPathFromContentUri(String contentUri) {
    debugPrint('[HistoryListItem] 尝试从 content URI 提取真实路径: $contentUri');
    
    // 处理格式: content://com.android.providers.downloads.documents/document/raw%3A%2Fstorage%2Femulated%2F0%2FDownload%2Fimage_test.png
    // 或者格式: content://com.android.providers.downloads.documents/document/msf%3A1000000051
    if (contentUri.contains('/document/')) {
      final parts = contentUri.split('/document/');
      if (parts.length == 2) {
        final encodedPath = parts[1];
        debugPrint('[HistoryListItem] 找到编码部分: $encodedPath');
        
        // 检查常见的前缀并移除
        String pathToDecode = encodedPath;
        if (pathToDecode.startsWith('raw%3A')) {
          pathToDecode = pathToDecode.substring(6);
          debugPrint('[HistoryListItem] 移除 raw: 前缀');
        } else if (pathToDecode.startsWith('msf%3A')) {
          debugPrint('[HistoryListItem] 检测到 msf: 前缀（MediaStore ID），无法直接提取真实路径');
          // msf: 后面是 MediaStore ID，不是文件路径，返回 null
          return null;
        }
        
        // URL 解码
        try {
          final decodedPath = Uri.decodeComponent(pathToDecode);
          debugPrint('[HistoryListItem] URL 解码后: $decodedPath');
          
          // 检查是否是一个绝对路径
          if (decodedPath.startsWith('/')) {
            debugPrint('[HistoryListItem] 提取到真实路径: $decodedPath');
            return decodedPath;
          }
        } catch (e) {
          debugPrint('[HistoryListItem] URL 解码失败: $e');
        }
      }
    }
    
    debugPrint('[HistoryListItem] 无法从 content URI 提取真实路径');
    return null;
  }

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
        if (widget.history.path.startsWith('content://')) {
          isFileExists = true; // URI 假设存在
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
            
            String pathToUse = widget.history.path;
            
            // 尝试从 content URI 提取真实路径
            if (widget.history.path.startsWith('content://')) {
              final permissionState = ref.read(permissionProvider);
              if (permissionState.hasStoragePermission) {
                debugPrint('[HistoryListItem] 有存储权限，先用原生通道尝试获取真实路径...');
                final realPathFromNative = await RealPathUtils.getRealPath(widget.history.path);
                if (realPathFromNative != null) {
                  final realFile = File(realPathFromNative);
                  if (await realFile.exists()) {
                    pathToUse = realPathFromNative;
                    debugPrint('[HistoryListItem] 原生通道获取到真实路径并存在: $pathToUse');
                  } else {
                    debugPrint('[HistoryListItem] 原生通道路径不存在');
                  }
                }
                
                // 如果原生通道没获取到，尝试我们自己的提取方法
                if (pathToUse == widget.history.path) {
                  debugPrint('[HistoryListItem] 尝试我们自己的提取方法...');
                  final realPath = _tryExtractRealPathFromContentUri(widget.history.path);
                  if (realPath != null) {
                    final realFile = File(realPath);
                    if (await realFile.exists()) {
                      pathToUse = realPath;
                      debugPrint('[HistoryListItem] 自己的方法提取到真实路径并存在，使用真实路径: $pathToUse');
                    } else {
                      debugPrint('[HistoryListItem] 真实路径不存在，使用原始路径');
                    }
                  } else {
                    debugPrint('[HistoryListItem] 无法提取真实路径，使用原始路径');
                  }
                }
              } else {
                debugPrint('[HistoryListItem] 没有存储权限，使用原始路径');
              }
            }
            
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
