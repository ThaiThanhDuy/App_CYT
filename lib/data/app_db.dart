import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../features/timer/domain/timer_plan.dart';
import 'steps_codec.dart';

part 'app_db.g.dart';

/// Cấu hình hẹn giờ người dùng lưu.
class Presets extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();

  /// JSON: [{"type":"focus"|"rest","seconds":int,"sound"?:string}, ...]
  TextColumn get stepsJson => text()();
  IntColumn get repeat => integer().withDefault(const Constant(1))();

  /// Tắt âm thanh riêng cho session này (thêm ở schema v2).
  BoolColumn get muted => boolean().withDefault(const Constant(false))();

  /// Thứ tự hiển thị trên màn chính, kéo thả để đổi (thêm ở schema v3).
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

/// Mỗi dòng là một phiên focus đã chạy hết giờ trọn vẹn.
@TableIndex(name: 'idx_completed_sessions_day', columns: {#day})
class CompletedSessions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get presetId => integer().nullable().references(
    Presets,
    #id,
    onDelete: KeyAction.setNull,
  )();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime()();
  IntColumn get focusSeconds => integer()();

  /// Ngày kết thúc phiên theo giờ máy, dạng yyyy-MM-dd.
  TextColumn get day => text()();
}

/// Block công việc trong lịch (màn Schedule), gắn với một ngày cụ thể.
@TableIndex(name: 'idx_task_blocks_day', columns: {#day})
@DataClassName('TaskBlockRow')
class TaskBlocks extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();

  /// Ngày của block, dạng yyyy-MM-dd theo giờ máy.
  TextColumn get day => text()();

  /// Giờ bắt đầu / kết thúc, tính bằng phút từ 00:00 (0–1440).
  IntColumn get startMinute => integer()();
  IntColumn get endMinute => integer()();

  /// Session gắn với block (tuỳ chọn); xoá session thì block vẫn giữ.
  IntColumn get presetId => integer().nullable().references(
    Presets,
    #id,
    onDelete: KeyAction.setNull,
  )();

  /// Màu block (ARGB); null = xám mặc định.
  IntColumn get color => integer().nullable()();
}

@DriftDatabase(tables: [Presets, CompletedSessions, TaskBlocks])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'cyt'));

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      // Preset mặc định.
      await into(presets).insert(
        PresetsCompanion.insert(
          name: TimerPlan.pomodoro.name,
          stepsJson: encodeSteps(TimerPlan.pomodoro.steps),
          repeat: Value(TimerPlan.pomodoro.repeat),
        ),
      );
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) await m.addColumn(presets, presets.muted);
      if (from < 3) {
        await m.addColumn(presets, presets.sortOrder);
        // Giữ nguyên thứ tự cũ (theo thời điểm tạo).
        await customStatement('UPDATE presets SET sort_order = id');
      }
      if (from < 4) {
        await m.createTable(taskBlocks);
        await m.createIndex(idxTaskBlocksDay);
      }
      if (from >= 4 && from < 5) {
        await m.addColumn(taskBlocks, taskBlocks.color);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
