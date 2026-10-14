import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/stats_providers.dart';
import '../domain/achievement_stats.dart';
import '../domain/heatmap_metric.dart';
import 'daily_heatmap_section.dart';
import '../../../data/session_repository.dart';

/// Bảng thành tựu ở màn chính: 3 số liệu lớn + heatmap "Hằng ngày".
class AchievementsBoard extends ConsumerWidget {
  const AchievementsBoard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final metric = ref.watch(heatmapMetricProvider);
    final values = ref.watch(heatmapValuesProvider).value ?? const {};
    final today = ref.watch(todayProvider);
    final range = ref.watch(heatmapRangeProvider);
    final stats = computeAchievementStats(values, today);
    final minutes = metric == HeatmapMetric.minutes;
    // Tổng của tháng / tuần đang xem.
    final rangeTotal = heatmapRangeDays(
      range,
      today,
    ).fold(0, (sum, d) => sum + (values[dayKey(d)] ?? 0));
    final rangeName = switch (range) {
      HeatmapRange.month => 'THIS MONTH',
      HeatmapRange.week => 'THIS WEEK',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IntrinsicHeight(
          child: Row(
            children: [
              _StatTile(
                value: stats.today,
                label: minutes ? 'MIN TODAY' : 'TODAY',
              ),
              VerticalDivider(color: scheme.outlineVariant, width: 32),
              _StatTile(value: stats.streak, label: 'DAY STREAK'),
              VerticalDivider(color: scheme.outlineVariant, width: 32),
              // Chế độ phút: tổng quy ra giờ cho gọn.
              _StatTile(
                value: minutes ? (rangeTotal / 60).round() : rangeTotal,
                label: minutes ? 'HOURS · $rangeName' : rangeName,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(24),
          ),
          child: const DailyHeatmapSection(),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Số đổi thì chạy mượt sang giá trị mới.
          TweenAnimationBuilder<double>(
            tween: Tween(end: value.toDouble()),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => Text(
              '${v.round()}',
              style: textTheme.displayMedium?.copyWith(
                height: 1.05,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: textTheme.labelSmall),
        ],
      ),
    );
  }
}
