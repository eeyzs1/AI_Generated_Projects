import 'package:drift/drift.dart';

class BookmarksTable extends Table {
  TextColumn get id => text()();
  TextColumn get path => text().unique()();
  TextColumn get displayName => text()();
  IntColumn get createdAt => integer()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}