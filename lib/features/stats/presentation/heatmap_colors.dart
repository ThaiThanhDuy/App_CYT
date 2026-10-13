import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../themes/domain/theme_package.dart';

/// Từ mức này trở lên đều dùng màu đậm nhất.
const int heatmapMaxCount = 10;

/// Màu ô heatmap theo số phiên trong ngày.
///
/// 0 → xám; 1 → [heatmapMaxCount] → xanh nhạt dần sang đậm (nội suy liên tục);
/// từ [heatmapMaxCount] trở lên giữ màu đậm nhất.
/// Ở dark mode, "đậm" nghĩa là xanh rực hơn trên nền đen.
/// Gói theme có thể thay bảng màu qua [palette]. [max]: mốc đậm nhất
/// (10 phiên, hoặc 240 phút ở chế độ phút).
Color heatmapColor(
  int count,
  Brightness brightness, {
  HeatmapPalette? palette,
  int max = heatmapMaxCount,
}) {
  final p = palette ?? defaultHeatmapPalette(brightness);
  if (count <= 0) return p.empty;
  final t = (math.min(count, max) - 1) / (max - 1);
  return Color.lerp(p.low, p.high, t)!;
}

HeatmapPalette defaultHeatmapPalette(Brightness brightness) =>
    brightness == Brightness.dark
    ? const HeatmapPalette(
        empty: Color(0xFF262626),
        low: Color(0xFF0E4429),
        high: Color(0xFF39D353),
      )
    : const HeatmapPalette(
        empty: Color(0xFFE5E5E5),
        low: Color(0xFFB4EFC2),
        high: Color(0xFF0A5C24),
      );
