import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/play_history_table.dart';
import '../../models/play_history.dart';

part 'history_dao.g.dart';

@DriftAccessor(tables: [PlayHistoryTable])
class HistoryDao extends DatabaseAccessor<AppDatabase> with _$HistoryDaoMixin {
  HistoryDao(super.db);

  Future<List<PlayHistory>> getHistory({int limit = 50, int offset = 0}) async {
    final rows = await (select(playHistoryTable)
          ..orderBy([(t) => OrderingTerm.desc(t.lastPlayedAt)])
          ..limit(limit, offset: offset))
        .get();
    return rows.map((row) => PlayHistory.fromDb(row)).toList();
  }

  Future<PlayHistory?> getByPath(String path) async {
    final row = await (select(playHistoryTable)..where((t) => t.path.equals(path))).getSingleOrNull();
    return row != null ? PlayHistory.fromDb(row) : null;
  }

  Future<void> upsert(PlayHistory history) async {
    final lastPositionMs = history.lastPosition?.inMilliseconds;
    final totalDurationMs = history.totalDuration?.inMilliseconds;
    await into(playHistoryTable).insert(
      PlayHistoryTableCompanion(
        id: Value(history.id),
        path: Value(history.path),
        displayName: Value(history.displayName),
        extension: Value(history.extension),
        type: Value(history.type.index),
        thumbnailPath: history.thumbnailPath != null ? Value(history.thumbnailPath) : const Value.absent(),
        lastPositionMs: lastPositionMs != null ? Value(lastPositionMs) : const Value.absent(),
        totalDurationMs: totalDurationMs != null ? Value(totalDurationMs) : const Value.absent(),
        lastPlayedAt: Value(history.lastPlayedAt.millisecondsSinceEpoch),
        playCount: Value(history.playCount),
      ),
      mode: InsertMode.insertOrReplace,
    );
  }

  Future<void> updatePosition(String path, Duration position) async {
    await (update(playHistoryTable)..where((t) => t.path.equals(path)))
        .write(PlayHistoryTableCompanion(lastPositionMs: Value(position.inMilliseconds)));
  }

  Future<void> deleteById(String id) async {
    await (delete(playHistoryTable)..where((t) => t.id.equals(id))).go();
  }

  Future<void> deleteAll() async {
    await delete(playHistoryTable).go();
  }

  Future<void> deleteByPath(String path) async {
    await (delete(playHistoryTable)..where((t) => t.path.equals(path))).go();
  }

  Stream<List<PlayHistory>> watchHistory({int limit = 50}) {
    return (select(playHistoryTable)
          ..orderBy([(t) => OrderingTerm.desc(t.lastPlayedAt)])
          ..limit(limit))
        .watch()
        .map((rows) => rows.map((row) => PlayHistory.fromDb(row)).toList());
  }
}