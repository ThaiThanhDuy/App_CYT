import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../features/presets/domain/preset_entry.dart';
import '../features/timer/domain/timer_plan.dart';
import 'app_db.dart';
import 'steps_codec.dart';

/// Tạo / sửa / xoá / đọc các preset hẹn giờ.
class PresetRepository {
  PresetRepository(this._db);

  final AppDatabase _db;

  /// Tất cả preset theo thứ tự người dùng sắp (rồi theo thời điểm tạo).
  /// Dòng có stepsJson hỏng bị bỏ qua.
  Stream<List<PresetEntry>> watchAll() {
    final query = _db.select(_db.presets)
      ..orderBy([
        (p) => OrderingTerm.asc(p.sortOrder),
        (p) => OrderingTerm.asc(p.id),
      ]);
    return query.watch().map((rows) => [for (final row in rows) ?_toPlan(row)]);
  }

  /// Thêm preset mới (đứng cuối danh sách), trả về id.
  Future<int> create(TimerPlan plan) async {
    final next = await _db
        .customSelect(
          'SELECT COALESCE(MAX(sort_order), 0) + 1 AS n FROM presets',
          readsFrom: {_db.presets},
        )
        .map((r) => r.read<int>('n'))
        .getSingle();
    return _db
        .into(_db.presets)
        .insert(
          PresetsCompanion.insert(
            name: plan.name,
            stepsJson: encodeSteps(plan.steps),
            repeat: Value(plan.repeat),
            sortOrder: Value(next),
          ),
        );
  }

  /// Lưu thứ tự mới: [ids] theo thứ tự hiển thị từ đầu đến cuối.
  Future<void> reorder(List<int> ids) => _db.transaction(() async {
    for (final (i, id) in ids.indexed) {
      await (_db.update(_db.presets)..where((p) => p.id.equals(id))).write(
        PresetsCompanion(sortOrder: Value(i + 1)),
      );
    }
  });

  Future<void> update(TimerPlan plan) async {
    final id = plan.id;
    if (id == null) throw ArgumentError('Preset has no id');
    await (_db.update(_db.presets)..where((p) => p.id.equals(id))).write(
      PresetsCompanion(
        name: Value(plan.name),
        stepsJson: Value(encodeSteps(plan.steps)),
        repeat: Value(plan.repeat),
      ),
    );
  }

  Future<void> setMuted(int id, {required bool muted}) =>
      (_db.update(_db.presets)..where((p) => p.id.equals(id))).write(
        PresetsCompanion(muted: Value(muted)),
      );

  Future<void> delete(int id) =>
      (_db.delete(_db.presets)..where((p) => p.id.equals(id))).go();

  static PresetEntry? _toPlan(Preset row) {
    try {
      final steps = decodeSteps(row.stepsJson);
      if (steps.isEmpty || row.repeat < 1) return null;
      return PresetEntry(
        plan: TimerPlan(
          id: row.id,
          name: row.name,
          steps: steps,
          repeat: row.repeat,
        ),
        muted: row.muted,
      );
    } on FormatException catch (e) {
      debugPrint('Bỏ qua preset #${row.id} hỏng: $e');
      return null;
    }
  }
}
