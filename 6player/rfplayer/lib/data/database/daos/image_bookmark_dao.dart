import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/image_bookmark_table.dart';
import '../../models/image_bookmark.dart';

part 'image_bookmark_dao.g.dart';

@DriftAccessor(tables: [ImageBookmarks])
class ImageBookmarkDao extends DatabaseAccessor<AppDatabase> with _$ImageBookmarkDaoMixin {
  ImageBookmarkDao(super.db);

  Future<List<ImageBookmark>> getAll() async {
    final rows = await select(imageBookmarks).get();
    return rows.map((row) => _toModel(row)).toList();
  }

  Future<ImageBookmark?> getByImagePath(String imagePath) async {
    final row = await (select(imageBookmarks)
          ..where((tbl) => tbl.imagePath.equals(imagePath)))
        .getSingleOrNull();
    return row != null ? _toModel(row) : null;
  }

  Future<void> insert(ImageBookmark bookmark) async {
    await into(imageBookmarks).insert(_toCompanion(bookmark));
  }

  Future<void> deleteById(String id) async {
    await (delete(imageBookmarks)..where((tbl) => tbl.id.equals(id))).go();
  }

  Future<void> deleteByImagePath(String imagePath) async {
    await (delete(imageBookmarks)..where((tbl) => tbl.imagePath.equals(imagePath))).go();
  }

  ImageBookmark _toModel(ImageBookmarkData data) {
    return ImageBookmark(
      id: data.id,
      imagePath: data.imagePath,
      imageName: data.imageName,
      createdAt: DateTime.fromMillisecondsSinceEpoch(data.createdAtMs),
    );
  }

  ImageBookmarksCompanion _toCompanion(ImageBookmark bookmark) {
    return ImageBookmarksCompanion(
      id: Value(bookmark.id),
      imagePath: Value(bookmark.imagePath),
      imageName: Value(bookmark.imageName),
      createdAtMs: Value(bookmark.createdAt.millisecondsSinceEpoch),
    );
  }
}
