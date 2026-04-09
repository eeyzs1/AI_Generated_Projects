import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../core/constants/app_constants.dart';

// 先导入所有表
import 'tables/play_history_table.dart';
import 'tables/bookmarks_table.dart';
import 'tables/play_queue_table.dart';
import 'tables/video_bookmark_table.dart';
import 'tables/image_bookmark_table.dart';

// 再导入所有 DAO
import 'daos/history_dao.dart';
import 'daos/bookmark_dao.dart';
import 'daos/play_queue_dao.dart';
import 'daos/video_bookmark_dao.dart';
import 'daos/image_bookmark_dao.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [PlayHistoryTable, BookmarksTable, PlayQueueTable, VideoBookmarks, ImageBookmarks],
  daos: [HistoryDao, BookmarkDao, PlayQueueDao, VideoBookmarkDao, ImageBookmarkDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (migrator) async {
        await migrator.createAll();
      },
      onUpgrade: (migrator, from, to) async {
        if (from < 2) {
          await migrator.createTable(playHistoryTable);
          await migrator.createTable(bookmarksTable);
          await migrator.createTable(playQueueTable);
        }
        if (from < 3) {
          await migrator.createTable(playHistoryTable);
          await migrator.createTable(bookmarksTable);
          await migrator.createTable(playQueueTable);
        }
        if (from < 4) {
          await migrator.createTable(videoBookmarks);
        }
        if (from < 5) {
          await migrator.createTable(imageBookmarks);
        }
        if (from < 6) {
          await migrator.createTable(playHistoryTable);
          await migrator.createTable(bookmarksTable);
          await migrator.createTable(playQueueTable);
          await migrator.createTable(videoBookmarks);
          await migrator.createTable(imageBookmarks);
        }
      },
      beforeOpen: (details) async {
        await customStatement('PRAGMA foreign_keys = ON');
      },
    );
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, AppConstants.dbFileName));
    return NativeDatabase(file);
  });
}