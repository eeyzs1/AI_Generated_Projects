import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/play_queue_table.dart';
import '../../models/play_queue.dart';

part 'play_queue_dao.g.dart';

@DriftAccessor(tables: [PlayQueueTable])
class PlayQueueDao extends DatabaseAccessor<AppDatabase> with _$PlayQueueDaoMixin {
  final AppDatabase db;

  PlayQueueDao(this.db) : super(db);

  Future<List<PlayQueueItem>> getAll() async {
    final query = select(playQueueTable);
    query.orderBy([(t) => OrderingTerm(expression: t.sortOrder)]);
    final rows = await query.get();
    return rows.map((row) => _toPlayQueueItem(row)).toList();
  }

  Future<void> insert(PlayQueueTableCompanion item) async {
    await into(playQueueTable).insert(item);
  }

  Future<void> deleteById(String id) async {
    await (delete(playQueueTable)..where((t) => t.id.equals(id))).go();
  }

  Future<void> deleteAll() async {
    await delete(playQueueTable).go();
  }

  Future<void> deleteAllExceptCurrentPlaying() async {
    await (delete(playQueueTable)..where((t) => t.isCurrentPlaying.equals(0))).go();
    // 将当前播放项的 sortOrder 重置为 0
    await (update(playQueueTable)..where((t) => t.isCurrentPlaying.equals(1)))
        .write(PlayQueueTableCompanion(sortOrder: Value(0)));
  }

  

  Future<void> reorder(List<String> orderedIds) async {
    for (var i = 0; i < orderedIds.length; i++) {
      await (update(playQueueTable)..where((t) => t.id.equals(orderedIds[i])))
          .write(PlayQueueTableCompanion(sortOrder: Value(i)));
    }
  }

  Future<PlayQueueTableData?> getNextItem(int currentSortOrder) async {
    // 使用原始SQL查询，但处理null值
    final rows = await customSelect(
      'SELECT * FROM play_queue_table WHERE sort_order > ? ORDER BY sort_order LIMIT 1',
      variables: [Variable.withInt(currentSortOrder)],
    ).get();
    
    if (rows.isEmpty) return null;
    
    // 处理null值，确保所有字段都有默认值
    final data = Map<String, dynamic>.from(rows.first.data);
    data['id'] ??= '';
    data['path'] ??= '';
    data['displayName'] ??= '';
    data['sortOrder'] ??= 0;
    data['addedAt'] ??= 0;
    data['isCurrentPlaying'] ??= 0;
    data['hasPlayed'] ??= 0;
    data['playProgress'] ??= 0.0;
    data['isInvalid'] ??= false;
    
    return PlayQueueTableData.fromJson(data);
  }

  

  Stream<List<PlayQueueItem>> watchAll() {
    final query = select(playQueueTable);
    query.orderBy([(t) => OrderingTerm(expression: t.sortOrder)]);
    return query.watch().map((rows) => rows.map((row) => _toPlayQueueItem(row)).toList());
  }

  PlayQueueItem _toPlayQueueItem(PlayQueueTableData row) {
    return PlayQueueItem(
      id: row.id,
      path: row.path,
      displayName: row.displayName,
      sortOrder: row.sortOrder,
      addedAt: DateTime.fromMillisecondsSinceEpoch(row.addedAt),
      isCurrentPlaying: row.isCurrentPlaying == 1,
      hasPlayed: row.hasPlayed == 1,
      playProgress: row.playProgress,
      isInvalid: row.isInvalid,
    );
  }

  PlayQueueTableCompanion _toCompanion(PlayQueueItem item) {
    return PlayQueueTableCompanion(
      id: Value(item.id),
      path: Value(item.path),
      displayName: Value(item.displayName),
      sortOrder: Value(item.sortOrder),
      addedAt: Value(item.addedAt.millisecondsSinceEpoch),
      isCurrentPlaying: Value(item.isCurrentPlaying ? 1 : 0),
      hasPlayed: Value(item.hasPlayed ? 1 : 0),
      playProgress: Value(item.playProgress),
      isInvalid: Value(item.isInvalid),
    );
  }

  Future<void> resetAllCurrentPlaying() async {
    await (update(playQueueTable)
          ..where((t) => t.isCurrentPlaying.equals(1)))
        .write(PlayQueueTableCompanion(isCurrentPlaying: Value(0)));
  }

  Future<void> setCurrentPlaying(String id) async {
    // 先重置所有is_current_playing为0
    await resetAllCurrentPlaying();
    // 然后将当前id设为1
    await (update(playQueueTable)..where((t) => t.id.equals(id)))
        .write(PlayQueueTableCompanion(
      isCurrentPlaying: Value(1),
      hasPlayed: Value(0),
    ));
  }

  Future<void> markAsPlayed(String id) async {
    await (update(playQueueTable)..where((t) => t.id.equals(id)))
        .write(PlayQueueTableCompanion(
      hasPlayed: Value(1),
      isCurrentPlaying: Value(0),
    ));
  }

  Future<void> updatePlayProgress(String id, double progress) async {
    await (update(playQueueTable)..where((t) => t.id.equals(id)))
        .write(PlayQueueTableCompanion(playProgress: Value(progress)));
  }

  Future<PlayQueueTableData?> getCurrentPlaying() async {
    final query = select(playQueueTable);
    query.where((t) => t.isCurrentPlaying.equals(1));
    query.limit(1);
    return await query.getSingleOrNull();
  }
}