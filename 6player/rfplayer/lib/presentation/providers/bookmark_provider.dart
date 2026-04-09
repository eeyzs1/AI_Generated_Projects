import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/bookmark_repository.dart';
import '../../data/models/bookmark.dart';
import './database_provider.dart';

final bookmarkProvider = StateNotifierProvider<BookmarkNotifier, List<Bookmark>>((ref) {
  return BookmarkNotifier(ref);
});

class BookmarkNotifier extends StateNotifier<List<Bookmark>> {
  final Ref _ref;
  BookmarkRepository get _repository => _ref.read(bookmarkRepositoryProvider);

  BookmarkNotifier(this._ref) : super([]) {
    _loadBookmarks();
  }

  Future<void> _loadBookmarks() async {
    final bookmarks = await _repository.getAll();
    state = bookmarks;
  }

  Future<void> addBookmark(String path, String displayName) async {
    final bookmark = Bookmark(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      path: path,
      displayName: displayName,
      createdAt: DateTime.now(),
      sortOrder: state.length,
    );

    await _repository.insert(bookmark);
    await _loadBookmarks();
  }

  Future<void> deleteBookmark(String id) async {
    await _repository.deleteById(id);
    await _loadBookmarks();
  }

  Future<void> reorderBookmarks(List<String> orderedIds) async {
    await _repository.reorder(orderedIds);
    await _loadBookmarks();
  }

  Future<void> refresh() async {
    await _loadBookmarks();
  }
}
