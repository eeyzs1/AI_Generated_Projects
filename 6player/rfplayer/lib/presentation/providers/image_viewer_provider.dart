import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../../core/extensions/string_extensions.dart';

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
  });

  String get currentFileName => p.basename(currentPath);
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
    );
  }
}

class ImageViewerNotifier extends StateNotifier<ImageViewerState> {
  ImageViewerNotifier(String initialPath) : super(
    ImageViewerState(
      currentPath: initialPath,
      currentIndex: 0,
      imagePaths: [initialPath],
      isLoading: true,
    ),
  ) {
    _initialize();
  }

  Future<void> _initialize() async {
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

  Future<void> _loadImageInfo() async {
    try {
      final file = File(state.currentPath);
      if (await file.exists()) {
        final stat = await file.stat();
        final fileName = p.basename(state.currentPath);
        final extension = p.extension(state.currentPath).toUpperCase().replaceAll('.', '');
        
        // 获取图片尺寸
        final image = await decodeImageFromList(await file.readAsBytes());
        
        state = state.copyWith(
          imageInfo: ImageInfo(
            fileName: fileName,
            filePath: state.currentPath,
            width: image.width,
            height: image.height,
            fileSize: stat.size,
            modifiedAt: stat.modified,
            format: extension.isEmpty ? 'UNKNOWN' : extension,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error loading image info: $e');
    }
  }

  void toggleUIVisibility() {
    state = state.copyWith(isUIVisible: !state.isUIVisible);
  }

  void navigateToImage(int index) {
    if (index >= 0 && index < state.imagePaths.length) {
      state = state.copyWith(
        currentPath: state.imagePaths[index],
        currentIndex: index,
        rotation: 0,
        isFlippedHorizontal: false,
        isFlippedVertical: false,
        currentScale: 1.0,
        imageInfo: null,
        isLoading: true,
      );
      _loadImageInfo();
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

final imageViewerProvider = StateNotifierProvider.family<ImageViewerNotifier, ImageViewerState, String>(
  (ref, path) => ImageViewerNotifier(path),
);
