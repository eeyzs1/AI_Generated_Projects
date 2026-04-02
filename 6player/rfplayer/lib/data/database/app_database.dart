import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../core/constants/app_constants.dart';
import 'tables/play_history_table.dart';
import 'tables/bookmarks_table.dart';
import 'tables/play_queue_table.dart';
import 'daos/history_dao.dart';
import 'daos/bookmark_dao.dart';
import 'daos/play_queue_dao.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [PlayHistoryTable, BookmarksTable, PlayQueueTable],
  daos: [HistoryDao, BookmarkDao, PlayQueueDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onUpgrade: (migrator, from, to) async {
        // 对于新版本，重新创建所有表
        await migrator.deleteTable(playHistoryTable.actualTableName);
        await migrator.deleteTable(bookmarksTable.actualTableName);
        await migrator.deleteTable(playQueueTable.actualTableName);
        await migrator.createAll();
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