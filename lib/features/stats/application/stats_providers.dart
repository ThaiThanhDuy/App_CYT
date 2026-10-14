import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/data_providers.dart';
import '../../../data/session_repository.dart';
import '../../timer/application/timer_providers.dart';
import '../../timer/domain/timer_engine.dart';
import '../../timer/domain/timer_phase.dart';
import '../domain/heatmap_metric.dart';

/// Bước tập trung vô hạn chạy dưới mức này khi bấm Xong thì không được tính.
const Duration minInfiniteFocus = Duration(minutes: 1);

/// Số tuần heatmap hiển thị.
const int heatmapWeeks = 26;

/// Lắng nghe engine và ghi mỗi phiên focus hoàn thành vào DB.
///
/// Chỉ [StepCompleted] của pha focus được ghi; bỏ qua / huỷ không ghi.
/// Cần được `watch` ở gốc app để luôn hoạt động.
final sessionRecorderProvider = Provider<void>((ref) {
  final engine = ref.watch(timerEngineProvider);
  final repo = ref.watch(sessionRepositoryProvider);
  final wall = ref.watch(wallClockProvider);
  final sub = engine.events.listen((event) {
    if (event is! StepCompleted || event.step.phase != TimerPhase.focus) {
      return;
    }
    if (event.step.infinite && event.elapsed < minInfiniteFocus) return;
    final DateTime startedAt;
    final DateTime endedAt;
    if (ref.read(fastTimerProvider)) {
      // Clock tua nhanh lệch về tương lai → dùng giờ thật, thời lượng thật.
      endedAt = wall.now();
      startedAt = endedAt.subtract(
        (event.endedAt.difference(event.startedAt)) * (1 / fastTimerFactor),
      );
    } else {
      // Mốc theo lịch của engine, đúng kể cả khi app bị treo rồi chạy bù.
      startedAt = event.startedAt;
      endedAt = event.endedAt;
    }
    unawaited(
      repo
          .recordFocus(
            startedAt: startedAt,
            endedAt: endedAt,
            // Bước vô hạn: thời gian thực sự chạy; bước có giờ: thời lượng.
            focusSeconds: event.elapsed.inSeconds,
            presetId: engine.plan.id,
          )
          .catchError((Object e, StackTrace st) {
            debugPrint('Không ghi được phiên: $e\n$st');
            return -1;
          }),
    );
  });
  ref.onDispose(sub.cancel);
});

/// Ngày hôm nay (00:00 giờ máy), tự cập nhật khi qua nửa đêm.
final todayProvider = NotifierProvider<TodayNotifier, DateTime>(
  TodayNotifier.new,
);

class TodayNotifier extends Notifier<DateTime> {
  Timer? _timer;

  @override
  DateTime build() {
    ref.onDispose(() => _timer?.cancel());
    return _scheduleNext();
  }

  DateTime _scheduleNext() {
    final now = ref.read(wallClockProvider).now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    _timer?.cancel();
    // +1s để chắc chắn đã sang ngày mới.
    _timer = Timer(tomorrow.difference(now) + const Duration(seconds: 1), () {
      state = _scheduleNext();
    });
    return today;
  }
}

/// Ngày đầu tiên (thứ Hai) của lưới heatmap kết thúc ở tuần chứa [today].
DateTime heatmapStart(DateTime today, {int weeks = heatmapWeeks}) {
  final monday = DateTime(
    today.year,
    today.month,
    today.day - (today.weekday - 1),
  );
  return DateTime(monday.year, monday.month, monday.day - 7 * (weeks - 1));
}

/// Số phiên + giây tập trung theo ngày ("yyyy-MM-dd") cho toàn bộ lưới
/// heatmap.
final dailyStatsProvider = StreamProvider<Map<String, DayStats>>((ref) {
  final today = ref.watch(todayProvider);
  return ref
      .watch(sessionRepositoryProvider)
      .watchDailyStats(from: heatmapStart(today), to: today);
});

/// Chế độ heatmap (phiên / phút), lưu trong SharedPreferences.
final heatmapMetricProvider =
    NotifierProvider<HeatmapMetricNotifier, HeatmapMetric>(
      HeatmapMetricNotifier.new,
    );

class HeatmapMetricNotifier extends Notifier<HeatmapMetric> {
  static const _key = 'heatmapMetric';

  @override
  HeatmapMetric build() {
    final name = ref.watch(sharedPreferencesProvider).getString(_key);
    return HeatmapMetric.values.where((m) => m.name == name).firstOrNull ??
        HeatmapMetric.sessions;
  }

  Future<void> select(HeatmapMetric metric) async {
    state = metric;
    await ref.read(sharedPreferencesProvider).setString(_key, metric.name);
  }
}

/// Giá trị mỗi ngày theo chế độ đang chọn: số phiên, hoặc số phút tập trung.
final heatmapValuesProvider = Provider<AsyncValue<Map<String, int>>>((ref) {
  final metric = ref.watch(heatmapMetricProvider);
  return ref
      .watch(dailyStatsProvider)
      .whenData(
        (stats) => {
          for (final MapEntry(:key, :value) in stats.entries)
            key: switch (metric) {
              HeatmapMetric.sessions => value.sessions,
              HeatmapMetric.minutes => value.seconds ~/ 60,
            },
        },
      );
});

/// Khoảng heatmap (tháng / tuần), lưu trong SharedPreferences.
final heatmapRangeProvider =
    NotifierProvider<HeatmapRangeNotifier, HeatmapRange>(
      HeatmapRangeNotifier.new,
    );

class HeatmapRangeNotifier extends Notifier<HeatmapRange> {
  static const _key = 'heatmapRange';

  @override
  HeatmapRange build() {
    final name = ref.watch(sharedPreferencesProvider).getString(_key);
    return HeatmapRange.values.where((r) => r.name == name).firstOrNull ??
        HeatmapRange.month;
  }

  Future<void> select(HeatmapRange range) async {
    state = range;
    await ref.read(sharedPreferencesProvider).setString(_key, range.name);
  }
}
