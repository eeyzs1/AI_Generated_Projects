import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/file_utils.dart';
import '../../../../core/extensions/string_extensions.dart';
import '../../../providers/file_browser_provider.dart';
import '../../../router/app_router.dart';

class FileListItem extends ConsumerWidget {
  final FileSystemEntity entity;

  const FileListItem({super.key, required this.entity});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDirectory = entity is Directory;
    final isVideo = !isDirectory && entity.path.isVideoFile;
    final isImage = !isDirectory && entity.path.isImageFile;

    IconData getIcon() {
      if (isDirectory) return Icons.folder;
      if (isVideo) return Icons.video_file;
      if (isImage) return Icons.image;
      return Icons.insert_drive_file;
    }

    Color getIconColor() {
      if (isDirectory) return Colors.amber;
      if (isVideo) return Colors.blue;
      if (isImage) return Colors.green;
      return Colors.grey;
    }

    Future<String> getFileInfo() async {
      if (isDirectory) return '';
      final file = entity as File;
      final stat = await file.stat();
      final size = FileUtils.getFileSizeString(stat.size);
      final modified = stat.modified.toString().substring(0, 16);
      return '$size • $modified';
    }

    return FutureBuilder<String>(
      future: getFileInfo(),
      builder: (context, snapshot) {
        return ListTile(
          leading: Icon(getIcon(), color: getIconColor()),
          title: Text(
            entity.path.split(Platform.pathSeparator).last,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: snapshot.hasData ? Text(snapshot.data!) : null,
          onTap: () {
            if (isDirectory) {
              ref.read(fileBrowserProvider.notifier).navigateTo(entity.path);
            } else if (isVideo) {
              appRouter.push('/video-player', extra: {'path': entity.path});
            } else if (isImage) {
              appRouter.push('/image-viewer', extra: {'path': entity.path});
            }
          },
        );
      },
    );
  }
}