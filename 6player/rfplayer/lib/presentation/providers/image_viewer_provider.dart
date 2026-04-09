import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../../core/extensions/string_extensions.dart';
import '../../core/utils/real_path_utils.dart';

class ImageInfo {
  final String fileName;
  final String filePath;
  final int width;
  final int height;
  final int fileSize;
  final DateTime modifiedAt;
  final String format;

  ImageInfo({
    required this.fileName,
    required this.filePath,
    required this.width,
    required this.height,
    required this.fileSize,
    required this.modifiedAt,
    required this.format,
  });
}

class ImageViewerState {
  final String currentPath;
  final int currentIndex;
  final List<String> imagePaths;
  final bool isUIVisible;
  final double rotation;
  final bool isFlippedHorizontal;
  final bool isFlippedVertical;
  final double currentScale;
  final ImageInfo? imageInfo;
  final bool isLoading;
  final String? customFileName;

  static const _sentinel = Object();

  ImageViewerState({
    required this.currentPath,
    required this.currentIndex,
    required this.imagePaths,
    this.isUIVisible = true,
    this.rotation = 0,
    this.isFlippedHorizontal = false,
    this.isFlippedVertical = false,
    this.currentScale = 1.0,
    this.imageInfo,
    this.isLoading = false,
    this.customFileName,
  });

  String get currentFileName {
    if (customFileName != null) return customFileName!;
    return p.basename(currentPath);
  }
  int get totalCount => imagePaths.length;
  bool get canGoPrevious => currentIndex > 0;
  bool get canGoNext => currentIndex < imagePaths.length - 1;

  ImageViewerState copyWith({
    String? currentPath,
    int? currentIndex,
    List<String>? imagePaths,
    bool? isUIVisible,
    double? rotation,
    bool? isFlippedHorizontal,
    bool? isFlippedVertical,
    double? currentScale,
    Object? imageInfo = _sentinel,
    bool? isLoading,
    Object? customFileName = _sentinel,
  }) {
    return ImageViewerState(
      currentPath: currentPath ?? this.currentPath,
      currentIndex: currentIndex ?? this.currentIndex,
      imagePaths: imagePaths ?? this.imagePaths,
      isUIVisible: isUIVisible ?? this.isUIVisible,
      rotation: rotation ?? this.rotation,
      isFlippedHorizontal: isFlippedHorizontal ?? this.isFlippedHorizontal,
      isFlippedVertical: isFlippedVertical ?? this.isFlippedVertical,
      currentScale: currentScale ?? this.currentScale,
      imageInfo: identical(imageInfo, _sentinel) ? this.imageInfo : imageInfo as ImageInfo?,
      isLoading: isLoading ?? this.isLoading,
      customFileName: identical(customFileName, _sentinel) ? this.customFileName : customFileName as String?,
    );
  }
}

class ImageViewerNotifier extends StateNotifier<ImageViewerState> {
  Uint8List? _initialBytes;

  ImageViewerNotifier(String initialPath, {String? customFileName, Uint8List? initialBytes}) : super(
    ImageViewerState(
      currentPath: initialPath,
      currentIndex: 0,
      imagePaths: [initialPath],
      isLoading: true,
      customFileName: customFileName,
    ),
  ) {
    _initialBytes = initialBytes;
    _initialize();
  }
  
  // 确保路径总是真实路径
  Future<String> _ensureRealPath(String path) async {
    if (RealPathUtils.isContentUri(path)) {
      final safePath = await RealPathUtils.getSafePath(path);
      if (safePath != null) {
        return safePath;
      }
    }
    return path;
  }

  Future<void> _initialize() async {
    // 先确保使用真实路径
    final realPath = await _ensureRealPath(state.currentPath);
    if (realPath != state.currentPath) {
      debugPrint('[ImageViewerProvider] 转换路径为真实路径: $realPath');
      state = state.copyWith(
        currentPath: realPath,
        imagePaths: [realPath],
      );
    }
    
    await _loadDirectoryImages();
    await _loadImageInfo();
    state = state.copyWith(isLoading: false);
  }

  Future<void> _loadDirectoryImages() async {
    final directory = p.dirname(state.currentPath);
    final dir = Directory(directory);
    
    if (await dir.exists()) {
      final entries = await dir.list().toList();
      final imagePaths = entries
          .where((entry) => entry is File && entry.path.isImageFile)
          .map((entry) => entry.path)
          .toList();
      
      imagePaths.sort();
      
      final currentIndex = imagePaths.indexOf(state.currentPath);
      
      state = state.copyWith(
        imagePaths: imagePaths,
        currentIndex: currentIndex >= 0 ? currentIndex : 0,
      );
    }
  }

  String _inferImageFormat(Uint8List bytes, String fallbackFileName) {
    // 从字节数据的魔数推断图片格式
    if (bytes.length >= 8) {
      if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
        return 'JPEG';
      }
      if (bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47 && bytes[4] == 0x0D && bytes[5] == 0x0A && bytes[6] == 0x1A && bytes[7] == 0x0A) {
        return 'PNG';
      }
      if (bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x38) {
        return 'GIF';
      }
      if (bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46) {
        if (bytes.length >= 12 && bytes[8] == 0x57 && bytes[9] == 0x45 && bytes[10] == 0x42 && bytes[11] == 0x50) {
          return 'WEBP';
        }
      }
      if (bytes[0] == 0x42 && bytes[1] == 0x4D) {
        return 'BMP';
      }
    }
    // 如果无法推断，尝试从文件名获取
    final extension = p.extension(fallbackFileName).toUpperCase().replaceAll('.', '');
    return extension.isEmpty ? 'UNKNOWN' : extension;
  }

  Future<void> _loadImageInfo() async {
    try {
      Uint8List bytes;
      String fileName;
      final effectivePath = state.currentPath;

      if (_initialBytes != null) {
        bytes = _initialBytes!;
        fileName = state.customFileName ?? p.basename(effectivePath);
      } else {
        final file = File(effectivePath);
        if (!await file.exists()) {
          return;
        }
        bytes = await file.readAsBytes();
        fileName = p.basename(effectivePath);
      }

      final image = await decodeImageFromList(bytes);
      final format = _inferImageFormat(bytes, fileName);

      int fileSize = bytes.length;
      DateTime modifiedAt = DateTime.now();
      if (_initialBytes == null) {
        try {
          final stat = await File(effectivePath).stat();
          fileSize = stat.size;
          modifiedAt = stat.modified;
        } catch (_) {}
      }

      state = state.copyWith(
        imageInfo: ImageInfo(
          fileName: fileName,
          filePath: effectivePath,
          width: image.width,
          height: image.height,
          fileSize: fileSize,
          modifiedAt: modifiedAt,
          format: format,
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('[ImageViewerProvider] Failed to load image info: $e');
      debugPrint('[ImageViewerProvider] Stack trace: $stackTrace');
    }
  }

  void toggleUIVisibility() {
    state = state.copyWith(isUIVisible: !state.isUIVisible);
  }

  void navigateToImage(int index) {
    if (index >= 0 && index < state.imagePaths.length) {
      _navigateToImageAsync(index);
    }
  }
  
  Future<void> _navigateToImageAsync(int index) async {
    if (index >= 0 && index < state.imagePaths.length) {
      final newPath = await _ensureRealPath(state.imagePaths[index]);
      state = state.copyWith(
        currentPath: newPath,
        currentIndex: index,
        rotation: 0,
        isFlippedHorizontal: false,
        isFlippedVertical: false,
        currentScale: 1.0,
        imageInfo: null,
        isLoading: true,
      );
      await _loadImageInfo();
      state = state.copyWith(isLoading: false);
    }
  }

  void goToPrevious() {
    if (state.canGoPrevious) {
      navigateToImage(state.currentIndex - 1);
    }
  }

  void goToNext() {
    if (state.canGoNext) {
      navigateToImage(state.currentIndex + 1);
    }
  }

  void rotateLeft() {
    state = state.copyWith(rotation: (state.rotation - 90) % 360);
  }

  void rotateRight() {
    state = state.copyWith(rotation: (state.rotation + 90) % 360);
  }

  void flipHorizontal() {
    state = state.copyWith(isFlippedHorizontal: !state.isFlippedHorizontal);
  }

  void flipVertical() {
    state = state.copyWith(isFlippedVertical: !state.isFlippedVertical);
  }

  void zoomIn() {
    final newScale = (state.currentScale + 0.5).clamp(0.5, 5.0);
    state = state.copyWith(currentScale: newScale);
  }

  void zoomOut() {
    final newScale = (state.currentScale - 0.5).clamp(0.5, 5.0);
    state = state.copyWith(currentScale: newScale);
  }

  void resetTransform() {
    state = state.copyWith(
      rotation: 0,
      isFlippedHorizontal: false,
      isFlippedVertical: false,
      currentScale: 1.0,
    );
  }

  void setScale(double scale) {
    state = state.copyWith(currentScale: scale.clamp(0.5, 5.0));
  }
}

class ImageViewerParams {
  final String path;
  final String? customFileName;
  final Uint8List? initialBytes;

  ImageViewerParams({
    required this.path,
    this.customFileName,
    this.initialBytes,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ImageViewerParams &&
          runtimeType == other.runtimeType &&
          path == other.path &&
          customFileName == other.customFileName;

  @override
  int get hashCode => path.hashCode ^ customFileName.hashCode;
}

final imageViewerProvider = StateNotifierProvider.family<ImageViewerNotifier, ImageViewerState, ImageViewerParams>(
  (ref, params) => ImageViewerNotifier(
    params.path,
    customFileName: params.customFileName,
    initialBytes: params.initialBytes,
  ),
);
