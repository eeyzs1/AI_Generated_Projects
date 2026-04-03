import 'dart:io';
import 'package:path/path.dart' as p;

class FileUtils {
  static bool isVideoFile(String path) {
    final extension = p.extension(path).toLowerCase();
    return ['.mp4', '.mkv', '.avi', '.mov', '.wmv', '.flv', '.webm'].contains(extension);
  }

  static bool isImageFile(String path) {
    final extension = p.extension(path).toLowerCase();
    return ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp', '.tiff'].contains(extension);
  }

  static String getFileName(String path) {
    return p.basename(path);
  }

  static String getDirectoryPath(String path) {
    return p.dirname(path);
  }

  static List<File> getFilesInDirectory(String directoryPath, {List<String>? extensions}) {
    final directory = Directory(directoryPath);
    if (!directory.existsSync()) return [];

    final files = directory.listSync().whereType<File>().cast<File>().toList();
    
    if (extensions != null && extensions.isNotEmpty) {
      return files.where((file) {
        final extension = p.extension(file.path).toLowerCase();
        return extensions.contains(extension);
      }).toList();
    }

    return files;
  }

  static List<File> getImageFilesInDirectory(String directoryPath) {
    return getFilesInDirectory(directoryPath, extensions: ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp', '.tiff']);
  }

  static List<File> getVideoFilesInDirectory(String directoryPath) {
    return getFilesInDirectory(directoryPath, extensions: ['.mp4', '.mkv', '.avi', '.mov', '.wmv', '.flv', '.webm']);
  }

  static String getFileSizeString(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    var size = bytes.toDouble();
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(2)} ${suffixes[i]}';
  }

  static Future<File?> pickFile({required List<String> allowedExtensions}) async {
    // 这个方法会在平台特定实现中被调用
    return null;
  }

  static Future<List<File>?> pickFiles({required List<String> allowedExtensions, bool allowMultiple = false}) async {
    // 这个方法会在平台特定实现中被调用
    return null;
  }

  static List<FileSystemEntity> sortEntries(List<FileSystemEntity> entries) {
    entries.sort((a, b) {
      final aIsDir = a is Directory;
      final bIsDir = b is Directory;
      
      if (aIsDir && !bIsDir) return -1;
      if (!aIsDir && bIsDir) return 1;
      
      return a.path.split(Platform.pathSeparator).last.compareTo(b.path.split(Platform.pathSeparator).last);
    });
    return entries;
  }
}