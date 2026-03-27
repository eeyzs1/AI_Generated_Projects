import 'package:drift/drift.dart';

class PlayHistoryTable extends Table {
  TextColumn get id => text()();
  TextColumn get path => text().unique()();
  TextColumn get displayName => text()();
  TextColumn get extension => text()();
  IntColumn get type => integer()();
  TextColumn get thumbnailPath => text().nullable()();
  IntColumn get lastPositionMs => integer().nullable()();
  IntColumn get totalDurationMs => integer().nullable()();
  IntColumn get lastPlayedAt => integer()();
  IntColumn get playCount => integer().withDefault(const Constant(1))();

  @override
  Set<Column> get primaryKey => {id};
}