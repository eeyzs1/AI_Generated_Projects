import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:saf_stream/saf_stream.dart';
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
  final Uint8List? bytes;

  ImageInfo({
    required this.fileName,
    required this.filePath,
    required this.width,
    required this.height,
    required this.fileSize,
    required this.modifiedAt,
    required this.format,
    this.bytes,
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
  final Uint8List? initialBytes;

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
    this.initialBytes,
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
    ImageInfo? imageInfo,
    bool? isLoading,
    String? customFileName,
    Uint8List? initialBytes,
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
      imageInfo: imageInfo ?? this.imageInfo,
      isLoading: isLoading ?? this.isLoading,
      customFileName: customFileName ?? this.customFileName,
      initialBytes: initialBytes ?? this.initialBytes,
    );
  }
}

class ImageViewerNotifier extends StateNotifier<ImageViewerState> {
  final SafStream _safStream = SafStream();

  ImageViewerNotifier(String initialPath, {String? customFileName, Uint8List? initialBytes}) : super(
    ImageViewerState(
      currentPath: initialPath,
      currentIndex: 0,
      imagePaths: [initialPath],
      isLoading: true,
      customFileName: customFileName,
      initialBytes: initialBytes,
    ),
  ) {
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

  String? _tryExtractRealPathFromContentUri(String contentUri) {
    debugPrint('[ImageViewerProvider] 尝试从 content URI 提取真实路径: $contentUri');
    
    // 处理格式: content://com.android.providers.downloads.documents/document/raw%3A%2Fstorage%2Femulated%2F0%2FDownload%2Fimage_test.png
    // 或者格式: content://com.android.providers.downloads.documents/document/msf%3A1000000051
    if (contentUri.contains('/document/')) {
      final parts = contentUri.split('/document/');
      if (parts.length == 2) {
        final encodedPath = parts[1];
        debugPrint('[ImageViewerProvider] 找到编码部分: $encodedPath');
        
        // 检查常见的前缀并移除
        String pathToDecode = encodedPath;
        if (pathToDecode.startsWith('raw%3A')) {
          pathToDecode = pathToDecode.substring(6);
          debugPrint('[ImageViewerProvider] 移除 raw: 前缀');
        } else if (pathToDecode.startsWith('msf%3A')) {
          debugPrint('[ImageViewerProvider] 检测到 msf: 前缀（MediaStore ID），无法直接提取真实路径');
          // msf: 后面是 MediaStore ID，不是文件路径，返回 null
          return null;
        }
        
        // URL 解码
        try {
          final decodedPath = Uri.decodeComponent(pathToDecode);
          debugPrint('[ImageViewerProvider] URL 解码后: $decodedPath');
          
          // 检查是否是一个绝对路径
          if (decodedPath.startsWith('/')) {
            debugPrint('[ImageViewerProvider] 提取到真实路径: $decodedPath');
            return decodedPath;
          }
        } catch (e) {
          debugPrint('[ImageViewerProvider] URL 解码失败: $e');
        }
      }
    }
    
    debugPrint('[ImageViewerProvider] 无法从 content URI 提取真实路径');
    return null;
  }

  Future<void> _loadImageInfo() async {
    debugPrint('[ImageViewerProvider] ======== 加载图片信息 ========');
    debugPrint('[ImageViewerProvider] currentPath: ${state.currentPath}');
    debugPrint('[ImageViewerProvider] customFileName: ${state.customFileName}');
    debugPrint('[ImageViewerProvider] initialBytes: ${state.initialBytes != null ? '有数据' : '无数据'}');
    
    try {
      Uint8List bytes;
      String fileName;
      final effectivePath = state.currentPath;
      
      // 优先使用从路由传递过来的 initialBytes
      if (state.initialBytes != null) {
        debugPrint('[ImageViewerProvider] 使用 initialBytes');
        bytes = state.initialBytes!;
        fileName = state.customFileName ?? p.basename(effectivePath);
      } else {
        debugPrint('[ImageViewerProvider] 处理普通文件');
        final file = File(effectivePath);
        if (!await file.exists()) {
          debugPrint('[ImageViewerProvider] 文件不存在');
          return;
        }
        bytes = await file.readAsBytes();
        fileName = p.basename(effectivePath);
      }
      
      debugPrint('[ImageViewerProvider] 读取成功，字节数: ${bytes.length}');
      
      final image = await decodeImageFromList(bytes);
      final format = _inferImageFormat(bytes, fileName);
      
      final stat = await File(effectivePath).stat();
      final fileSize = stat.size;
      final modifiedAt = stat.modified;
      
      state = state.copyWith(
        imageInfo: ImageInfo(
          fileName: fileName,
          filePath: effectivePath,
          width: image.width,
          height: image.height,
          fileSize: fileSize,
          modifiedAt: modifiedAt,
          format: format,
          bytes: bytes,
        ),
      );
      debugPrint('[ImageViewerProvider] 图片信息加载完成，格式: $format, 路径: $effectivePath');
    } catch (e, stackTrace) {
      debugPrint('[ImageViewerProvider] 加载图片信息失败: $e');
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
