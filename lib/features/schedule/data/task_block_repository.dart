import 'package:drift/drift.dart';

import '../../../data/app_db.dart';
import '../../../data/session_repository.dart';
import '../domain/task_block.dart';

/// Đọc / ghi block công việc của màn Schedule.
class TaskBlockRepository {
  TaskBlockRepository(this._db);

  final AppDatabase _db;

  /// Các block trong khoảng ngày [from]..[to] (tính cả hai đầu), sắp theo
  /// ngày rồi giờ bắt đầu. Stream tự phát lại khi bảng thay đổi.
  Stream<List<TaskBlock>> watchBetween(DateTime from, DateTime to) {
    final t = _db.taskBlocks;
    final query = _db.select(t)
      ..where((b) => b.day.isBetweenValues(dayKey(from), dayKey(to)))
      ..orderBy([
        (b) => OrderingTerm.asc(b.day),
        (b) => OrderingTerm.asc(b.startMinute),
      ]);
    return query.watch().map((rows) => [for (final r in rows) _toBlock(r)]);
  }

  /// Block đang diễn ra lúc [time] (nếu nhiều block chồng nhau thì lấy block
  /// bắt đầu muộn nhất — thường là việc cụ thể hơn).
  Future<TaskBlock?> blockAt(DateTime time) async {
    final t = _db.taskBlocks;
    final minute = time.hour * 60 + time.minute;
    final row =
        await (_db.select(t)
              ..where(
                (b) =>
                    b.day.equals(dayKey(time)) &
                    b.startMinute.isSmallerOrEqualValue(minute) &
                    b.endMinute.isBiggerThanValue(minute),
              )
              ..orderBy([(b) => OrderingTerm.desc(b.startMinute)])
              ..limit(1))
            .getSingleOrNull();
    return row == null ? null : _toBlock(row);
  }

  Future<int> create(TaskBlock block) =>
      _db.into(_db.taskBlocks).insert(_companion(block));

  /// Tạo bản sao của [block] vào từng ngày trong [days]; ngày đã có block
  /// y hệt (cùng tên, cùng giờ) thì bỏ qua. Trả về số block đã tạo.
  Future<int> createCopies(TaskBlock block, List<DateTime> days) =>
      _db.transaction(() async {
        final t = _db.taskBlocks;
        var created = 0;
        for (final day in days) {
          final same =
              await (_db.select(t)..where(
                    (b) =>
                        b.day.equals(dayKey(day)) &
                        b.title.equals(block.title) &
                        b.startMinute.equals(block.startMinute) &
                        b.endMinute.equals(block.endMinute),
                  ))
                  .get();
          if (same.isNotEmpty) continue;
          await _db.into(t).insert(_companion(block.copyWith(day: day)));
          created++;
        }
        return created;
      });

  Future<void> update(TaskBlock block) async {
    final id = block.id;
    if (id == null) throw ArgumentError('Block has no id');
    await (_db.update(
      _db.taskBlocks,
    )..where((b) => b.id.equals(id))).write(_companion(block));
  }

  Future<void> delete(int id) =>
      (_db.delete(_db.taskBlocks)..where((b) => b.id.equals(id))).go();

  TaskBlocksCompanion _companion(TaskBlock b) => TaskBlocksCompanion.insert(
    title: b.title,
    day: dayKey(b.day),
    startMinute: b.startMinute,
    endMinute: b.endMinute,
    presetId: Value(b.presetId),
    color: Value(b.color),
  );

  static TaskBlock _toBlock(TaskBlockRow row) {
    final parts = row.day.split('-').map(int.parse).toList();
    return TaskBlock(
      id: row.id,
      title: row.title,
      day: DateTime(parts[0], parts[1], parts[2]),
      startMinute: row.startMinute,
      endMinute: row.endMinute,
      presetId: row.presetId,
      color: row.color,
    );
  }
}
