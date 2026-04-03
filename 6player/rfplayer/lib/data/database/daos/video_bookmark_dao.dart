import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/video_bookmark_table.dart';
import '../../models/video_bookmark.dart';

part 'video_bookmark_dao.g.dart';

@DriftAccessor(tables: [VideoBookmarks])
class VideoBookmarkDao extends DatabaseAccessor<AppDatabase> with _$VideoBookmarkDaoMixin {
  VideoBookmarkDao(super.db);

  Future<List<VideoBookmark>> getAll() async {
    final rows = await select(videoBookmarks).get();
    return rows.map((row) => _toModel(row)).toList();
  }

  Future<List<VideoBookmark>> getByVideoPath(String videoPath) async {
    final rows = await (select(videoBookmarks)
          ..where((tbl) => tbl.videoPath.equals(videoPath)))
        .get();
    return rows.map((row) => _toModel(row)).toList();
  }

  Future<void> insert(VideoBookmark bookmark) async {
    await into(videoBookmarks).insert(_toCompanion(bookmark));
  }

  Future<void> deleteById(String id) async {
    await (delete(videoBookmarks)..where((tbl) => tbl.id.equals(id))).go();
  }

  Future<void> deleteByVideoPath(String videoPath) async {
    await (delete(videoBookmarks)..where((tbl) => tbl.videoPath.equals(videoPath))).go();
  }

  VideoBookmark _toModel(VideoBookmarkData data) {
    BookmarkType type = BookmarkType.video;
    if (data.type == 'image') {
      type = BookmarkType.image;
    }
    
    return VideoBookmark(
      id: data.id,
      videoPath: data.videoPath,
      videoName: data.videoName,
      position: Duration(milliseconds: data.positionMs),
      note: data.note,
      createdAt: DateTime.fromMillisecondsSinceEpoch(data.createdAtMs),
      type: type,
    );
  }

  VideoBookmarksCompanion _toCompanion(VideoBookmark bookmark) {
    String typeStr = bookmark.type == BookmarkType.image ? 'image' : 'video';
    
    return VideoBookmarksCompanion(
      id: Value(bookmark.id),
      videoPath: Value(bookmark.videoPath),
      videoName: Value(bookmark.videoName),
      positionMs: Value(bookmark.position.inMilliseconds),
      note: Value(bookmark.note),
      createdAtMs: Value(bookmark.createdAt.millisecondsSinceEpoch),
      type: Value(typeStr),
    );
  }
}