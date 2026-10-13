import 'package:flutter/foundation.dart';

import '../../timer/domain/timer_plan.dart';

/// Một session đã lưu: cấu hình hẹn giờ + tuỳ chọn hiển thị của card.
///
/// [muted] để ngoài [TimerPlan] để bật/tắt chuông không làm engine bị tạo
/// lại (không reset timer đang chạy).
@immutable
class PresetEntry {
  const PresetEntry({required this.plan, this.muted = false});

  final TimerPlan plan;
  final bool muted;

  int get id => plan.id!;

  @override
  bool operator ==(Object other) =>
      other is PresetEntry && other.plan == plan && other.muted == muted;

  @override
  int get hashCode => Object.hash(plan, muted);
}
