import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/stats_providers.dart';
import '../domain/heatmap_metric.dart';
import 'session_heatmap.dart';

/// Mục "Hằng ngày" bên dưới đồng hồ: heatmap đọc dữ liệu thật từ DB.
class DailyHeatmapSection extends ConsumerWidget {
  const DailyHeatmapSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(todayProvider);
    final metric = ref.watch(heatmapMetricProvider);
    final valuesAsync = ref.watch(heatmapValuesProvider);
    final textTheme = Theme.of(context).textTheme;
    final values = valuesAsync.value ?? const <String, int>{};

    final title = Text(
      'Daily',
      style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // Hẹp quá thì đưa chú giải xuống dưới lưới.
        final legendBelow = constraints.maxWidth < 440;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                title,
                const SizedBox(width: 12),
                const _MetricToggle(),
                const Spacer(),
                if (!legendBelow) HeatmapLegend(metric: metric),
              ],
            ),
            const SizedBox(height: 12),
            if (valuesAsync.hasError)
              Text('Could not load data: ${valuesAsync.error}')
            else
              SessionHeatmap(counts: values, today: today, metric: metric),
            if (legendBelow) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: HeatmapLegend(metric: metric),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// Công tắc nhỏ "Sessions | Minutes" chọn heatmap tô theo gì.
class _MetricToggle extends ConsumerWidget {
  const _MetricToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metric = ref.watch(heatmapMetricProvider);
    return SegmentedButton<HeatmapMetric>(
      segments: [
        for (final m in HeatmapMetric.values)
          ButtonSegment(value: m, label: Text(m.label)),
      ],
      selected: {metric},
      showSelectedIcon: false,
      onSelectionChanged: (s) =>
          ref.read(heatmapMetricProvider.notifier).select(s.first),
      style: SegmentedButton.styleFrom(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: Theme.of(context).textTheme.labelMedium,
        padding: const EdgeInsets.symmetric(horizontal: 10),
      ),
    );
  }
}
