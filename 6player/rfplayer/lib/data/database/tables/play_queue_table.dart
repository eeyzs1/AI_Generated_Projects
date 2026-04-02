import 'package:drift/drift.dart';

class PlayQueueTable extends Table {
  TextColumn get id => text()();
  TextColumn get path => text().withDefault(const Constant(''))();
  TextColumn get displayName => text().withDefault(const Constant(''))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  IntColumn get addedAt => integer().withDefault(const Constant(0))();
  IntColumn get isCurrentPlaying => integer().withDefault(const Constant(0))();
  IntColumn get hasPlayed => integer().withDefault(const Constant(0))();
  RealColumn get playProgress => real().withDefault(const Constant(0.0))();
  BoolColumn get isInvalid => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}