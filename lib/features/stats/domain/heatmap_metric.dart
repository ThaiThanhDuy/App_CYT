/// Heatmap tô màu theo gì.
enum HeatmapMetric {
  /// Số phiên focus hoàn thành; đậm nhất từ 10 phiên.
  sessions('Sessions', maxValue: 10),

  /// Số phút tập trung; đậm nhất từ 4 giờ (≈ 10 phiên Pomodoro).
  minutes('Minutes', maxValue: 240);

  const HeatmapMetric(this.label, {required this.maxValue});

  final String label;

  /// Từ giá trị này trở lên dùng màu đậm nhất.
  final int maxValue;
}

/// Heatmap ở màn chính hiển thị khoảng nào.
enum HeatmapRange {
  /// Lịch tháng hiện tại (7 cột thứ 2 → CN).
  month('Month'),

  /// 7 ngày của tuần hiện tại, ô thật to.
  week('Week');

  const HeatmapRange(this.label);

  final String label;
}

/// Các ngày (00:00) của khoảng [range] chứa [today].
List<DateTime> heatmapRangeDays(HeatmapRange range, DateTime today) {
  switch (range) {
    case HeatmapRange.month:
      final last = DateTime(today.year, today.month + 1, 0).day;
      return [
        for (var d = 1; d <= last; d++) DateTime(today.year, today.month, d),
      ];
    case HeatmapRange.week:
      final monday = today.day - (today.weekday - 1);
      return [
        for (var i = 0; i < 7; i++)
          DateTime(today.year, today.month, monday + i),
      ];
  }
}
