import 'package:drift/drift.dart';

import 'app_db.dart';

/// Thống kê một ngày: số phiên focus hoàn thành và tổng giây tập trung.
typedef DayStats = ({int sessions, int seconds});

/// Khoá ngày "yyyy-MM-dd" theo giờ máy (local time).
String dayKey(DateTime t) {
  final local = t.toLocal();
  final m = local.month.toString().padLeft(2, '0');
  final d = local.day.toString().padLeft(2, '0');
  return '${local.year.toString().padLeft(4, '0')}-$m-$d';
}

/// Đọc/ghi các phiên focus đã hoàn thành.
class SessionRepository {
  SessionRepository(this._db);

  final AppDatabase _db;

  /// Ghi một phiên focus hoàn thành. Ngày được tính theo [endedAt].
  Future<int> recordFocus({
    required DateTime startedAt,
    required DateTime endedAt,
    required int focusSeconds,
    int? presetId,
  }) {
    return _db
        .into(_db.completedSessions)
        .insert(
          CompletedSessionsCompanion.insert(
            presetId: Value(presetId),
            startedAt: startedAt,
            endedAt: endedAt,
            focusSeconds: focusSeconds,
            day: dayKey(endedAt),
          ),
        );
  }

  /// Số phiên theo ngày trong khoảng [from]..[to] (tính cả hai đầu).
  /// Stream tự phát lại khi bảng thay đổi.
  Stream<Map<String, int>> watchDailyCounts({
    required DateTime from,
    required DateTime to,
  }) {
    final t = _db.completedSessions;
    final count = t.id.count();
    final query = _db.selectOnly(t)
      ..addColumns([t.day, count])
      ..where(t.day.isBetweenValues(dayKey(from), dayKey(to)))
      ..groupBy([t.day]);
    return query.watch().map(
      (rows) => {for (final r in rows) r.read(t.day)!: r.read(count)!},
    );
  }

  /// Số phiên + tổng giây tập trung theo ngày trong khoảng [from]..[to]
  /// (GROUP BY day, một truy vấn). Stream tự phát lại khi bảng thay đổi.
  Stream<Map<String, DayStats>> watchDailyStats({
    required DateTime from,
    required DateTime to,
  }) {
    final t = _db.completedSessions;
    final count = t.id.count();
    final seconds = t.focusSeconds.sum();
    final query = _db.selectOnly(t)
      ..addColumns([t.day, count, seconds])
      ..where(t.day.isBetweenValues(dayKey(from), dayKey(to)))
      ..groupBy([t.day]);
    return query.watch().map(
      (rows) => {
        for (final r in rows)
          r.read(t.day)!: (
            sessions: r.read(count)!,
            seconds: r.read(seconds) ?? 0,
          ),
      },
    );
  }
}
