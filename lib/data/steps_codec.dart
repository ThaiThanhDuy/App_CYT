import 'dart:convert';

import '../features/timer/domain/timer_phase.dart';
import '../features/timer/domain/timer_plan.dart';

/// Mã hoá danh sách bước thành JSON lưu ở cột `presets.stepsJson`.
/// Bước vô hạn: `{"type": ..., "seconds": 0, "infinite": true}`.
/// Tên riêng (nếu có): `"name": "Đọc sách"`.
String encodeSteps(List<TimerStep> steps) => jsonEncode([
  for (final s in steps)
    {
      'type': s.phase.name,
      'seconds': s.duration.inSeconds,
      if (s.sound != null) 'sound': s.sound,
      if (s.infinite) 'infinite': true,
      if (s.label != null) 'name': s.label,
    },
]);

/// Giải mã JSON từ `presets.stepsJson`. Ném [FormatException] nếu sai dạng.
List<TimerStep> decodeSteps(String json) {
  final raw = jsonDecode(json);
  if (raw is! List) throw const FormatException('stepsJson must be an array');
  return [
    for (final item in raw)
      switch (item) {
        {'type': final String type, 'seconds': final int seconds}
            when seconds >= 0 =>
          TimerStep(
            phase: TimerPhase.values.firstWhere(
              (p) => p.name == type,
              orElse: () => throw FormatException('invalid type: $type'),
            ),
            duration: item['infinite'] == true
                ? Duration.zero
                : Duration(seconds: seconds),
            sound: item['sound'] as String?,
            infinite: item['infinite'] == true,
            label: switch (item['name']) {
              final String name when name.trim().isNotEmpty => name.trim(),
              _ => null,
            },
          ),
        _ => throw FormatException('invalid step: $item'),
      },
  ];
}
