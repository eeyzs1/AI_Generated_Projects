import 'dart:io';
import '../database/app_database.dart';
import '../models/bookmark.dart';

class BookmarkRepository {
  final AppDatabase _db;

  BookmarkRepository(this._db);

  Future<List<Bookmark>> getAll() {
    return _db.bookmarkDao.getAll();
  }

  Future<void> insert(Bookmark bookmark) {
    return _db.bookmarkDao.insert(bookmark);
  }

  Future<void> deleteById(String id) {
    return _db.bookmarkDao.deleteById(id);
  }

  Future<void> reorder(List<String> orderedIds) {
    return _db.bookmarkDao.reorder(orderedIds);
  }

  Stream<List<Bookmark>> watchAll() {
    return _db.bookmarkDao.watchAll();
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