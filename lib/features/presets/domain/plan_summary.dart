import '../../timer/domain/timer_plan.dart';

/// Thời lượng một bước dạng gọn: "25" (phút chẵn) hoặc "2:30".
String _stepLabel(Duration d) {
  final s = d.inSeconds;
  if (s % 60 == 0) return '${s ~/ 60}';
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

/// Chỉ các bước (không có số vòng), ví dụ "25 · 5", "∞ · 5"; các mốc thời
/// gian ngăn bằng dấu chấm giữa.
String describeStepsOnly(TimerPlan plan, {String separator = ' · '}) => plan
    .steps
    .map((s) => s.infinite ? '∞' : _stepLabel(s.duration))
    .join(separator);

/// Mô tả chuỗi bước, ví dụ "25 · 5 × 4", "50 · 10 · 50 · 20", "∞ · 5".
String describeSteps(TimerPlan plan) {
  final steps = describeStepsOnly(plan);
  return plan.repeat > 1 ? '$steps × ${plan.repeat}' : steps;
}

/// Ví dụ "2h 10m", "2h", "45 min", "1 min 30s", "30s".
String formatDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes % 60;
  final s = d.inSeconds % 60;
  if (h > 0) return m > 0 ? '${h}h ${m}m' : '${h}h';
  if (m > 0) return s > 0 ? '$m min ${s}s' : '$m min';
  return s > 0 ? '${s}s' : '0 min';
}

/// Tổng thời gian của chuỗi; có bước vô hạn thì "no limit".
String describeTotal(TimerPlan plan) =>
    plan.hasInfinite ? 'no limit' : formatDuration(plan.totalDuration);
