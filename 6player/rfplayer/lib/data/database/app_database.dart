import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../core/constants/app_constants.dart';
import 'tables/play_history_table.dart';
import 'tables/bookmarks_table.dart';
import 'daos/history_dao.dart';
import 'daos/bookmark_dao.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [PlayHistoryTable, BookmarksTable],
  daos: [HistoryDao, BookmarkDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, AppConstants.dbFileName));
    return NativeDatabase(file);
  });
}