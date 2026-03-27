import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import '../../../core/utils/file_utils.dart';
import '../../../data/repositories/history_repository.dart';
import '../../../data/models/play_history.dart';
import '../../../presentation/providers/database_provider.dart';
import 'package:path/path.dart' as p;

class ImageViewerState {
  final List<File> imageFiles;
  final int currentIndex;
  final bool isLoading;
  final String currentImagePath;

  ImageViewerState({
    required this.imageFiles,
    required this.currentIndex,
    required this.isLoading,
    required this.currentImagePath,
  });

  ImageViewerState copyWith({
    List<File>? imageFiles,
    int? currentIndex,
    bool? isLoading,
    String? currentImagePath,
  }) {
    return ImageViewerState(
      imageFiles: imageFiles ?? this.imageFiles,
      currentIndex: currentIndex ?? this.currentIndex,
      isLoading: isLoading ?? this.isLoading,
      currentImagePath: currentImagePath ?? this.currentImagePath,
    );
  }

  String get currentImageName {
    return p.basename(currentImagePath);
  }

  int get totalImages {
    return imageFiles.length;
  }

  bool get canGoPrevious {
    return currentIndex > 0;
  }

  bool get canGoNext {
    return currentIndex < imageFiles.length - 1;
  }
}

class ImageViewerNotifier extends StateNotifier<ImageViewerState> {
  final HistoryRepository historyRepository;

  ImageViewerNotifier(this.historyRepository, String initialPath) : super(
    ImageViewerState(
      imageFiles: [],
      currentIndex: 0,
      isLoading: true,
      currentImagePath: initialPath,
    ),
  ) {
    loadImages(initialPath);
  }

  Future<void> loadImages(String path) async {
    final directoryPath = FileUtils.getDirectoryPath(path);
    final imageFiles = FileUtils.getImageFilesInDirectory(directoryPath);
    
    int currentIndex = imageFiles.indexWhere((file) => file.path == path);
    if (currentIndex == -1) {
      currentIndex = 0;
    }

    state = state.copyWith(
      imageFiles: imageFiles,
      currentIndex: currentIndex,
      isLoading: false,
      currentImagePath: imageFiles.isNotEmpty ? imageFiles[currentIndex].path : path,
    );

    // 添加或更新历史记录
    await addOrUpdateHistory(path);
  }

  Future<void> navigateToImage(int index) async {
    if (index >= 0 && index < state.imageFiles.length) {
      state = state.copyWith(
        currentIndex: index,
        isLoading: true,
        currentImagePath: state.imageFiles[index].path,
      );

      // 添加或更新历史记录
      await addOrUpdateHistory(state.imageFiles[index].path);

      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> addOrUpdateHistory(String path) async {
    var history = await historyRepository.getByPath(path);
    
    if (history == null) {
      final extension = p.extension(path).substring(1).toLowerCase();
      history = PlayHistory(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        path: path,
        displayName: p.basename(path),
        extension: extension,
        type: MediaType.image,
        lastPosition: Duration.zero,
        totalDuration: Duration.zero,
        lastPlayedAt: DateTime.now(),
        playCount: 1,
      );
      await historyRepository.upsert(history);
    } else {
      final updatedHistory = PlayHistory(
        id: history.id,
        path: history.path,
        displayName: history.displayName,
        extension: history.extension,
        type: history.type,
        lastPosition: history.lastPosition,
        totalDuration: history.totalDuration,
        lastPlayedAt: DateTime.now(),
        playCount: history.playCount + 1,
      );
      await historyRepository.upsert(updatedHistory);
    }
  }
}

final imageViewerProvider = StateNotifierProvider.family<ImageViewerNotifier, ImageViewerState, String>((ref, path) {
  final historyRepository = ref.watch(historyRepositoryProvider);
  return ImageViewerNotifier(historyRepository, path);
});