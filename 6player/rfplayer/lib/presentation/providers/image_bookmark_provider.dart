import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/image_bookmark_repository.dart';
import '../../data/models/image_bookmark.dart';
import './database_provider.dart';

final imageBookmarkRepositoryProvider = Provider((ref) {
  final dao = ref.watch(imageBookmarkDaoProvider);
  return ImageBookmarkRepository(dao);
});

final imageBookmarkProvider = StateNotifierProvider<ImageBookmarkNotifier, List<ImageBookmark>>((ref) {
  return ImageBookmarkNotifier(ref);
});

class ImageBookmarkNotifier extends StateNotifier<List<ImageBookmark>> {
  final Ref ref;
  final ImageBookmarkRepository _repository;

  ImageBookmarkNotifier(this.ref) 
    : _repository = ref.watch(imageBookmarkRepositoryProvider),
      super([]) {
    _loadBookmarks();
  }

  Future<void> _loadBookmarks() async {
    final bookmarks = await _repository.getAll();
    state = bookmarks;
  }

  Future<void> addBookmark(String imagePath, String imageName) async {
    await _repository.addBookmark(imagePath, imageName);
    await _loadBookmarks();
  }

  Future<void> deleteBookmark(String id) async {
    await _repository.deleteBookmark(id);
    await _loadBookmarks();
  }

  Future<void> toggleBookmark(String imagePath, String imageName) async {
    final existing = await _repository.getByImagePath(imagePath);
    if (existing != null) {
      await deleteBookmark(existing.id);
    } else {
      await addBookmark(imagePath, imageName);
    }
  }

  Future<bool> isBookmarked(String imagePath) async {
    final bookmark = await _repository.getByImagePath(imagePath);
    return bookmark != null;
  }

  Future<void> refresh() async {
    await _loadBookmarks();
  }
}
