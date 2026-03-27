import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/bookmarks_table.dart';
import '../../models/bookmark.dart';

part 'bookmark_dao.g.dart';

@DriftAccessor(tables: [BookmarksTable])
class BookmarkDao extends DatabaseAccessor<AppDatabase> with _$BookmarkDaoMixin {
  BookmarkDao(super.db);

  Future<List<Bookmark>> getAll() async {
    final rows = await (select(bookmarksTable)..orderBy([(t) => OrderingTerm.asc(t.sortOrder)])).get();
    return rows.map((row) => Bookmark.fromDb(row)).toList();
  }

  Future<void> insert(Bookmark bookmark) async {
    // 检查是否已存在相同路径的书签
    final existing = await (select(bookmarksTable)..where((t) => t.path.equals(bookmark.path))).get();
    if (existing.isNotEmpty) {
      // 已存在，不重复插入
      return;
    }
    
    await into(bookmarksTable).insert(
      BookmarksTableCompanion(
        id: Value(bookmark.id),
        path: Value(bookmark.path),
        displayName: Value(bookmark.displayName),
        createdAt: Value(bookmark.createdAt.millisecondsSinceEpoch),
        sortOrder: Value(bookmark.sortOrder),
      ),
    );
  }

  Future<void> deleteById(String id) async {
    await (delete(bookmarksTable)..where((t) => t.id.equals(id))).go();
  }

  Future<void> reorder(List<String> orderedIds) async {
    for (int i = 0; i < orderedIds.length; i++) {
      await (update(bookmarksTable)..where((t) => t.id.equals(orderedIds[i])))
          .write(BookmarksTableCompanion(sortOrder: Value(i)));
    }
  }

  Stream<List<Bookmark>> watchAll() {
    return (select(bookmarksTable)..orderBy([(t) => OrderingTerm.asc(t.sortOrder)])).watch()
        .map((rows) => rows.map((row) => Bookmark.fromDb(row)).toList());
  }
}