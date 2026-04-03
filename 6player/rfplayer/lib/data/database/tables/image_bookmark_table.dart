import 'package:drift/drift.dart';

@DataClassName('ImageBookmarkData')
class ImageBookmarks extends Table {
  TextColumn get id => text()();
  TextColumn get imagePath => text()();
  TextColumn get imageName => text()();
  IntColumn get createdAtMs => integer()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  String? get tableName => 'image_bookmarks';
}
