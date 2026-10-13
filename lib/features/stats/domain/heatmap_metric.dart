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
