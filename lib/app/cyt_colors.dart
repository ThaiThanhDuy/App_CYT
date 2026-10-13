import 'package:flutter/material.dart';

import '../features/timer/domain/timer_phase.dart';

/// Màu mặc định của theme "Traffic Light". Sau M6 sẽ lấy từ gói theme.
abstract final class CytColors {
  static const Color focus = Color(0xFF2BFF6B);
  static const Color rest = Color(0xFFFF3030);

  static Color forPhase(TimerPhase phase) => switch (phase) {
    TimerPhase.focus => focus,
    TimerPhase.rest => rest,
  };
}
