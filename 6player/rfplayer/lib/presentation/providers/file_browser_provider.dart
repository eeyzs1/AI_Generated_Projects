import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/file_utils.dart';
import '../../core/utils/platform_utils.dart';
import '../../presentation/providers/settings_provider.dart';

class FileBrowserState {
  final String currentPath;
  final List<FileSystemEntity> entries;
  final bool isLoading;
  final String? error;

  static const _sentinel = Object();

  FileBrowserState({
    required this.currentPath,
    required this.entries,
    this.isLoading = false,
    this.error,
  });

  FileBrowserState copyWith({
    String? currentPath,
    List<FileSystemEntity>? entries,
    bool? isLoading,
    Object? error = _sentinel,
  }) {
    return FileBrowserState(
      currentPath: currentPath ?? this.currentPath,
      entries: entries ?? this.entries,
      isLoading: isLoading ?? this.isLoading,
      error: identical(error, _sentinel) ? this.error : error as String?,
    );
  }
}

final fileBrowserProvider = StateNotifierProvider<FileBrowserNotifier, FileBrowserState>((ref) {
  return FileBrowserNotifier(ref);
});

class FileBrowserNotifier extends StateNotifier<FileBrowserState> {
  final Ref _ref;

  FileBrowserNotifier(this._ref) : super(
    FileBrowserState(
      currentPath: 'C:\\',
      entries: [],
      isLoading: true,
    ),
  ) {
    _initialize();
  }

  Future<void> _initialize() async {
    final defaultPath = await PlatformUtils.getDefaultStoragePath() ?? 'C:\\';
    await navigateTo(defaultPath);
  }

  Future<void> navigateTo(String path) async {
    state = state.copyWith(
      currentPath: path,
      isLoading: true,
      error: null,
    );

    try {
      final directory = Directory(path);
      if (!await directory.exists()) {
        throw Exception('目录不存在');
      }

      final showHiddenFiles = _ref.read(settingsProvider).showHiddenFiles;
      final entries = await directory.list().toList();
      
      // 过滤隐藏文件
      final filteredEntries = showHiddenFiles
          ? entries
          : entries.where((entry) => !entry.path.split(Platform.pathSeparator).last.startsWith('.')).toList();

      // 排序：目录在前，文件在后，各自按名称排序
      final sortedEntries = FileUtils.sortEntries(filteredEntries);

      state = state.copyWith(
        entries: sortedEntries,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
        isLoading: false,
      );
    }
  }

  Future<void> refresh() async {
    await navigateTo(state.currentPath);
  }

  Future<void> goUp() async {
    final parentPath = Directory(state.currentPath).parent.path;
    if (parentPath != state.currentPath) {
      await navigateTo(parentPath);
    }
  }
}