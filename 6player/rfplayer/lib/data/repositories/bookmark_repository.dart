import 'dart:io';
import '../database/daos/bookmark_dao.dart';
import '../models/bookmark.dart';

class BookmarkRepository {
  final BookmarkDao _dao;

  BookmarkRepository(this._dao);

  Future<List<Bookmark>> getAll() {
    return _dao.getAll();
  }

  Future<void> insert(Bookmark bookmark) {
    return _dao.insert(bookmark);
  }

  Future<void> deleteById(String id) {
    return _dao.deleteById(id);
  }

  Future<void> reorder(List<String> orderedIds) {
    return _dao.reorder(orderedIds);
  }

  Stream<List<Bookmark>> watchAll() {
    return _dao.watchAll();
  }

  /// 检查书签中的文件是否存在，删除不存在的记录
  Future<void> cleanupInvalidRecords() async {
    final allBookmarks = await getAll();
    
    for (final bookmark in allBookmarks) {
      if (!(await File(bookmark.path).exists() || await Directory(bookmark.path).exists())) {
        await deleteById(bookmark.id);
      }
    }
  }
}