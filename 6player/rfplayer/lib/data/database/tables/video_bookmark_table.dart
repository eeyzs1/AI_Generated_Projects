import 'package:drift/drift.dart';

@DataClassName('VideoBookmarkData')
class VideoBookmarks extends Table {
  TextColumn get id => text()();
  TextColumn get videoPath => text()();
  TextColumn get videoName => text()();
  IntColumn get positionMs => integer()();
  TextColumn get note => text().nullable()();
  IntColumn get createdAtMs => integer()();
  TextColumn get type => text().withDefault(const Constant('video'))();

  @override
  Set<Column> get primaryKey => {id};

  @override
  String? get tableName => 'video_bookmarks';
}