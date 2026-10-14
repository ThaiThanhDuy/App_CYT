import 'package:flutter/material.dart';

import '../../../data/session_repository.dart';
import '../../themes/presentation/cyt_theme.dart';
import '../domain/heatmap_metric.dart';
import 'heatmap_colors.dart';
import 'session_heatmap.dart';

const _weekdayShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// Giá trị ngắn gọn trong ô: "3" phiên, hoặc "45m" / "1h 20m".
String _shortValue(int n, HeatmapMetric metric) => switch (metric) {
  HeatmapMetric.sessions => '$n',
  HeatmapMetric.minutes =>
    n >= 60 ? '${n ~/ 60}h${n % 60 > 0 ? ' ${n % 60}m' : ''}' : '${n}m',
};

/// Heatmap ô to theo tháng (lịch 7 cột) hoặc theo tuần (7 ô) của [today].
class PeriodHeatmap extends StatelessWidget {
  const PeriodHeatmap({
    super.key,
    required this.values,
    required this.today,
    required this.range,
    required this.metric,
  });

  /// "yyyy-MM-dd" → giá trị ngày theo [metric].
  final Map<String, int> values;
  final DateTime today;
  final HeatmapRange range;
  final HeatmapMetric metric;

  static const double _gap = 6;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final days = heatmapRangeDays(range, today);
    final todayDate = DateTime(today.year, today.month, today.day);
    final palette = CytTheme.of(context).heatmap;
    final headerStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return LayoutBuilder(
      builder: (context, c) {
        final cell = ((c.maxWidth - 6 * _gap) / 7).clamp(24.0, 120.0);
        final week = range == HeatmapRange.week;
        // Tuần: ô cao hơn để có chỗ cho số ngày + giá trị.
        final cellHeight = week ? cell * 1.35 : cell * 0.82;

        Widget dayCell(DateTime day) {
          final value = values[dayKey(day)] ?? 0;
          final future = day.isAfter(todayDate);
          final color = heatmapColor(
            value,
            theme.brightness,
            palette: palette,
            max: metric.maxValue,
          );
          // Chữ trên ô: đen trên ô sáng, trắng trên ô tối.
          final fg =
              ThemeData.estimateBrightnessForColor(color) == Brightness.light
              ? Colors.black.withValues(alpha: 0.75)
              : Colors.white.withValues(alpha: value > 0 ? 0.9 : 0.55);
          final dayStyle = theme.textTheme.labelMedium?.copyWith(
            color: fg,
            fontSize: (cell * (week ? 0.26 : 0.22)).clamp(10.0, 22.0),
            fontWeight: week ? FontWeight.w600 : FontWeight.w500,
            fontFeatures: const [FontFeature.tabularFigures()],
          );
          final content = Padding(
            padding: EdgeInsets.all((cell * 0.1).clamp(4.0, 10.0)),
            child: week
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${day.day}', style: dayStyle),
                      const Spacer(),
                      if (value > 0 && !future)
                        Text(
                          _shortValue(value, metric),
                          maxLines: 1,
                          overflow: TextOverflow.fade,
                          softWrap: false,
                          style: dayStyle?.copyWith(
                            fontSize: (cell * 0.18).clamp(10.0, 16.0),
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                    ],
                  )
                : Align(
                    alignment: Alignment.topLeft,
                    child: Text('${day.day}', style: dayStyle),
                  ),
          );
          // Ngày chưa tới: ô viền mờ, không tô màu.
          if (future) {
            return Container(
              width: cell,
              height: cellHeight,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(
                  (cell * 0.2).clamp(0.0, 14.0),
                ),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.6,
                  ),
                ),
              ),
              child: DefaultTextStyle.merge(
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                child: Padding(
                  padding: EdgeInsets.all((cell * 0.1).clamp(4.0, 10.0)),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Text(
                      '${day.day}',
                      style: dayStyle?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.6,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }
          return HeatmapCell(
            key: ValueKey(dayKey(day)),
            date: day,
            count: value,
            metric: metric,
            size: cell,
            height: cellHeight,
            isToday: day == todayDate,
            brightness: theme.brightness,
            child: content,
          );
        }

        // Tháng: chèn ô trống trước mùng 1 cho đúng cột thứ.
        final leading = week ? 0 : days.first.weekday - 1;
        final slots = <DateTime?>[
          for (var i = 0; i < leading; i++) null,
          ...days,
        ];
        while (slots.length % 7 != 0) {
          slots.add(null);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                for (var i = 0; i < 7; i++) ...[
                  if (i > 0) const SizedBox(width: _gap),
                  SizedBox(
                    width: cell,
                    child: Text(_weekdayShort[i], style: headerStyle),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            for (var r = 0; r < slots.length ~/ 7; r++) ...[
              if (r > 0) const SizedBox(height: _gap),
              Row(
                children: [
                  for (var i = 0; i < 7; i++) ...[
                    if (i > 0) const SizedBox(width: _gap),
                    switch (slots[r * 7 + i]) {
                      final day? => dayCell(day),
                      null => SizedBox(width: cell, height: cellHeight),
                    },
                  ],
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}
