import 'dart:io';
import 'package:path/path.dart' as p;
import '../constants/supported_formats.dart';

class FileUtils {
  static bool isVideoFile(String path) {
    final ext = p.extension(path).toLowerCase();
    final extension = ext.length > 1 ? ext.substring(1) : ext;
    return videoFormats.contains(extension);
  }

  static bool isImageFile(String path) {
    final ext = p.extension(path).toLowerCase();
    final extension = ext.length > 1 ? ext.substring(1) : ext;
    return imageFormats.contains(extension);
  }

  static bool isSubtitleFile(String path) {
    final ext = p.extension(path).toLowerCase();
    final extension = ext.length > 1 ? ext.substring(1) : ext;
    return subtitleFormats.contains(extension);
  }

  static String getFileName(String path) {
    return p.basename(path);
  }

  static String getDirectoryPath(String path) {
    return p.dirname(path);
  }

  static List<File> getFilesInDirectory(String directoryPath, {Iterable<String>? extensions}) {
    final directory = Directory(directoryPath);
    if (!directory.existsSync()) return [];

    final files = directory.listSync().whereType<File>().cast<File>().toList();
    
    if (extensions != null && extensions.isNotEmpty) {
      return files.where((file) {
        final ext = p.extension(file.path).toLowerCase();
        final extension = ext.length > 1 ? ext.substring(1) : ext;
        return extensions.contains(extension);
      }).toList();
    }

    return files;
  }

  static List<File> getImageFilesInDirectory(String directoryPath) {
    return getFilesInDirectory(directoryPath, extensions: imageFormats);
  }

  static List<File> getVideoFilesInDirectory(String directoryPath) {
    return getFilesInDirectory(directoryPath, extensions: videoFormats);
  }

  static List<File> getSubtitleFilesInDirectory(String directoryPath) {
    return getFilesInDirectory(directoryPath, extensions: subtitleFormats);
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