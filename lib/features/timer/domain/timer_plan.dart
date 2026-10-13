import 'package:flutter/foundation.dart';

import 'timer_phase.dart';

/// Một bước trong chuỗi hẹn giờ.
@immutable
class TimerStep {
  const TimerStep({
    required this.phase,
    required this.duration,
    this.sound,
    this.infinite = false,
    this.label,
  });

  const TimerStep.focus(this.duration, {this.sound, this.label})
    : phase = TimerPhase.focus,
      infinite = false;
  const TimerStep.rest(this.duration, {this.sound, this.label})
    : phase = TimerPhase.rest,
      infinite = false;

  /// Bước không giới hạn thời gian: chạy tới khi người dùng bấm Xong/Bỏ qua.
  const TimerStep.infinite(this.phase, {this.sound, this.label})
    : duration = Duration.zero,
      infinite = true;

  final TimerPhase phase;

  /// Thời lượng; bằng 0 và bị bỏ qua nếu [infinite].
  final Duration duration;

  /// Không có giờ kết thúc.
  final bool infinite;

  /// Tên riêng người dùng đặt; null = dùng tên mặc định của pha.
  final String? label;

  /// Tên hiển thị: tên riêng, hoặc "Focus" / "Break".
  String get displayName => label ?? phase.label;

  /// Âm thanh khi bước kết thúc (dùng ở M5).
  final String? sound;

  @override
  bool operator ==(Object other) =>
      other is TimerStep &&
      other.phase == phase &&
      other.duration == duration &&
      other.sound == sound &&
      other.infinite == infinite &&
      other.label == label;

  @override
  int get hashCode => Object.hash(phase, duration, sound, infinite, label);

  @override
  String toString() => 'TimerStep(${phase.name}, ${infinite ? '∞' : duration})';
}

/// Cấu hình hẹn giờ: danh sách bước lặp lại [repeat] lần.
@immutable
class TimerPlan {
  const TimerPlan({
    required this.name,
    required this.steps,
    this.repeat = 1,
    this.id,
  });

  /// Id preset trong DB; null nếu là plan dựng sẵn chưa lưu.
  final int? id;
  final String name;
  final List<TimerStep> steps;
  final int repeat;

  /// Tổng số bước sau khi trải phẳng các vòng lặp.
  int get length => steps.length * repeat;

  TimerStep stepAt(int index) => steps[index % steps.length];

  /// Vòng hiện tại (bắt đầu từ 1) của bước thứ [index].
  int roundOf(int index) => index ~/ steps.length + 1;

  /// Có bước vô hạn → tổng thời lượng không xác định.
  bool get hasInfinite => steps.any((s) => s.infinite);

  /// Tổng thời lượng các bước có giới hạn (bước vô hạn tính là 0).
  Duration get totalDuration =>
      steps.fold(Duration.zero, (sum, s) => sum + s.duration) * repeat;

  TimerPlan copyWith({
    int? id,
    String? name,
    List<TimerStep>? steps,
    int? repeat,
  }) => TimerPlan(
    id: id ?? this.id,
    name: name ?? this.name,
    steps: steps ?? this.steps,
    repeat: repeat ?? this.repeat,
  );

  // So sánh theo giá trị: provider chỉ báo đổi (và tạo engine mới) khi
  // nội dung plan thực sự khác.
  @override
  bool operator ==(Object other) =>
      other is TimerPlan &&
      other.id == id &&
      other.name == name &&
      other.repeat == repeat &&
      listEquals(other.steps, steps);

  @override
  int get hashCode => Object.hash(id, name, repeat, Object.hashAll(steps));

  /// Preset mặc định: 25 phút tập trung / 5 phút nghỉ, 4 vòng.
  static const pomodoro = TimerPlan(
    name: 'Pomodoro 25/5',
    steps: [
      TimerStep.focus(Duration(minutes: 25)),
      TimerStep.rest(Duration(minutes: 5)),
    ],
    repeat: 4,
  );
}
