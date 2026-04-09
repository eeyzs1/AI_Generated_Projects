import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/video_bookmark.dart';
import '../../data/repositories/video_bookmark_repository.dart';
import './database_provider.dart';

final videoBookmarkProvider = StateNotifierProvider<VideoBookmarkNotifier, List<VideoBookmark>>((ref) {
  return VideoBookmarkNotifier(ref);
});

final videoBookmarksForVideoProvider = FutureProvider.family<List<VideoBookmark>, String>((ref, videoPath) async {
  final repository = ref.read(videoBookmarkRepositoryProvider);
  return await repository.getByVideoPath(videoPath);
});

class VideoBookmarkNotifier extends StateNotifier<List<VideoBookmark>> {
  final Ref _ref;
  VideoBookmarkRepository get _repository => _ref.read(videoBookmarkRepositoryProvider);

  VideoBookmarkNotifier(this._ref) : super([]) {
    _loadBookmarks();
  }

  Future<void> _loadBookmarks() async {
    final bookmarks = await _repository.getAll();
    state = bookmarks;
  }

  Future<void> addBookmark(String videoPath, String videoName, Duration position, {String? note, BookmarkType type = BookmarkType.video}) async {
    final bookmark = VideoBookmark(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      videoPath: videoPath,
      videoName: videoName,
      position: position,
      note: note,
      createdAt: DateTime.now(),
      type: type,
    );

    await _repository.addBookmark(bookmark);
    await _loadBookmarks();
  }

  Future<void> deleteBookmark(String id) async {
    await _repository.deleteBookmark(id);
    await _loadBookmarks();
  }

  Future<void> deleteAllBookmarksForVideo(String videoPath) async {
    await _repository.deleteAllBookmarksForVideo(videoPath);
    await _loadBookmarks();
  }

  Future<void> refresh() async {
    await _loadBookmarks();
  }
}