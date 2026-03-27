import 'dart:io';
import '../../core/utils/file_utils.dart';

class WindowsFileAccess {
  static Future<List<File>> getFilesInDirectory(String directoryPath) {
    final directory = Directory(directoryPath);
    if (!directory.existsSync()) {
      return Future.value([]);
    }

    final files = directory.listSync().whereType<File>().cast<File>().toList();
    return Future.value(files);
  }

  static Future<List<File>> getVideoFiles(String directoryPath) {
    return Future.value(FileUtils.getVideoFilesInDirectory(directoryPath));
  }

  static Future<List<File>> getImageFiles(String directoryPath) {
    return Future.value(FileUtils.getImageFilesInDirectory(directoryPath));
  }

  static bool directoryExists(String path) {
    return Directory(path).existsSync();
  }

  static bool fileExists(String path) {
    return File(path).existsSync();
  }

  static String getFileExtension(String path) {
    return path.split('.').last.toLowerCase();
  }

  static String getFileNameWithoutExtension(String path) {
    final fileName = File(path).uri.pathSegments.last;
    final lastDotIndex = fileName.lastIndexOf('.');
    if (lastDotIndex == -1) return fileName;
    return fileName.substring(0, lastDotIndex);
  }
}