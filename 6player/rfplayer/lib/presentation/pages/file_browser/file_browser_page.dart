import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import '../../../core/extensions/string_extensions.dart';
import '../../../data/models/play_history.dart';
import '../../../presentation/providers/database_provider.dart';
import '../../../presentation/providers/play_queue_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';

class FileBrowserPage extends ConsumerStatefulWidget {
  const FileBrowserPage({super.key});

  @override
  ConsumerState<FileBrowserPage> createState() => _FileBrowserPageState();
}

class _FileBrowserPageState extends ConsumerState<FileBrowserPage> {
  List<File> _recentFiles = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadRecentFiles();
  }

  Future<void> _loadRecentFiles() async {
    final historyRepo = ref.read(historyRepositoryProvider);
    final historyList = await historyRepo.getRecent(limit: 5);
    setState(() {
      _recentFiles = historyList.map((history) => File(history.path)).toList();
    });
  }

  Future<void> _deleteRecentFile(String path) async {
    final historyRepo = ref.read(historyRepositoryProvider);
    await historyRepo.deleteByPath(path);
    await _loadRecentFiles();
  }

  Future<void> _pickFile() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: true,
      );

      if (result != null && result.files.isNotEmpty) {
        List<String> videoPaths = [];
        
        for (final file in result.files) {
          final path = file.path!;
          final fileObj = File(path);
          
          // 创建或更新历史记录
          final historyRepo = ref.read(historyRepositoryProvider);
          final history = PlayHistory(
            id: const Uuid().v4(),
            path: path,
            displayName: p.basename(fileObj.path),
            extension: path.fileExtension,
            type: path.isVideoFile ? MediaType.video : MediaType.image,
            lastPlayedAt: DateTime.now(),
            playCount: 1,
          );
          await historyRepo.upsert(history);
          
          // 如果是视频文件，添加到视频路径列表
          if (path.isVideoFile) {
            final playQueueNotifier = ref.read(playQueueProvider.notifier);
            await playQueueNotifier.addToQueue(path, p.basename(fileObj.path));
            videoPaths.add(path);
          } else if (path.isImageFile) {
            // 如果是图片文件，直接打开
            context.push('/image-viewer', extra: path);
          }
        }
        
        // 重新加载最近文件列表
        await _loadRecentFiles();
        
        // 只打开第一个视频文件
        if (videoPaths.isNotEmpty) {
          // 使用 push 导航到视频播放器页面
          // 这样当用户点击返回按钮时，会返回到之前的页面
          context.push('/video-player', extra: videoPaths[0]);
        }
      }
    } catch (e) {
      print('Error picking file: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _openFile(String path) async {
    final historyRepo = ref.read(historyRepositoryProvider);
    
    // 创建或更新历史记录
    final file = File(path);
    final history = PlayHistory(
      id: const Uuid().v4(),
      path: path,
      displayName: p.basename(file.path),
      extension: path.fileExtension,
      type: path.isVideoFile ? MediaType.video : MediaType.image,
      lastPlayedAt: DateTime.now(),
      playCount: 1,
    );
    await historyRepo.upsert(history);

    // 重新加载最近文件列表
    await _loadRecentFiles();

    // 根据文件类型打开相应的播放器
    if (path.isVideoFile) {
      // 将视频添加到播放队列
      final playQueueNotifier = ref.read(playQueueProvider.notifier);
      await playQueueNotifier.addToQueue(path, p.basename(file.path));
      
      // 使用 push 导航到视频播放器页面
      // 这样当用户点击返回按钮时，会返回到之前的页面
      context.push('/video-player', extra: path);
    } else if (path.isImageFile) {
      context.push('/image-viewer', extra: path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.fileBrowser),
        actions: [
          IconButton(
            onPressed: _pickFile,
            icon: const Icon(Icons.folder_open),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Colors.blue,
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '选择文件',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _pickFile,
                    icon: const Icon(Icons.add),
                    label: Text('${localizations.playVideo} ${localizations.viewImage}'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    localizations.recentPlays,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_recentFiles.isEmpty)
                    Expanded(
                      child: Center(
                        child: Text(localizations.noRecentPlays),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.builder(
                        itemCount: _recentFiles.length,
                        itemBuilder: (context, index) {
                          final file = _recentFiles[index];
                          return ListTile(
                            leading: Icon(
                              file.path.isVideoFile
                                  ? Icons.video_library
                                  : Icons.image,
                            ),
                            title: Text(p.basename(file.path)),
                            onTap: () => _openFile(file.path),
                            trailing: IconButton(
                              onPressed: () async {
                                await _deleteRecentFile(file.path);
                              },
                              icon: const Icon(Icons.delete),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}