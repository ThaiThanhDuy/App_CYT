import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../home/domain/iso_week.dart';
import '../application/stats_providers.dart';
import '../domain/heatmap_metric.dart';
import 'period_heatmap.dart';
import 'session_heatmap.dart';

const _monthLong = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// Tên khoảng đang xem: "October 2026" hoặc "Week 42".
String heatmapRangeTitle(HeatmapRange range, DateTime today) => switch (range) {
  HeatmapRange.month => '${_monthLong[today.month - 1]} ${today.year}',
  HeatmapRange.week => 'Week ${isoWeekOf(today).week}',
};

/// Mục heatmap ở màn chính: tháng hoặc tuần hiện tại, ô to, đọc dữ liệu thật
/// từ DB.
class DailyHeatmapSection extends ConsumerWidget {
  const DailyHeatmapSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(todayProvider);
    final metric = ref.watch(heatmapMetricProvider);
    final range = ref.watch(heatmapRangeProvider);
    final valuesAsync = ref.watch(heatmapValuesProvider);
    final textTheme = Theme.of(context).textTheme;
    final values = valuesAsync.value ?? const <String, int>{};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: Text(
                  heatmapRangeTitle(range, today),
                  key: ValueKey(range),
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            _Toggle<HeatmapRange>(
              values: HeatmapRange.values,
              selected: range,
              label: (r) => r.label,
              onSelected: (r) =>
                  ref.read(heatmapRangeProvider.notifier).select(r),
            ),
            _Toggle<HeatmapMetric>(
              values: HeatmapMetric.values,
              selected: metric,
              label: (m) => m.label,
              onSelected: (m) =>
                  ref.read(heatmapMetricProvider.notifier).select(m),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (valuesAsync.hasError)
          Text('Could not load data: ${valuesAsync.error}')
        else
          // Đổi tháng ↔ tuần: lưới mới hiện dần, chiều cao co giãn mượt.
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: PeriodHeatmap(
                key: ValueKey(range),
                values: values,
                today: today,
                range: range,
                metric: metric,
              ),
            ),
          ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: HeatmapLegend(metric: metric),
        ),
      ],
    );
  }
}

/// Công tắc nhỏ dạng viên thuốc (vd. "Month | Week", "Sessions | Minutes").
class _Toggle<T> extends StatelessWidget {
  const _Toggle({
    required this.values,
    required this.selected,
    required this.label,
    required this.onSelected,
  });

  final List<T> values;
  final T selected;
  final String Function(T) label;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) => SegmentedButton<T>(
    segments: [
      for (final v in values) ButtonSegment(value: v, label: Text(label(v))),
    ],
    selected: {selected},
    showSelectedIcon: false,
    onSelectionChanged: (s) => onSelected(s.first),
    style: SegmentedButton.styleFrom(
      visualDensity: VisualDensity.compact,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      textStyle: Theme.of(context).textTheme.labelMedium,
      padding: const EdgeInsets.symmetric(horizontal: 10),
    ),
  );
}
