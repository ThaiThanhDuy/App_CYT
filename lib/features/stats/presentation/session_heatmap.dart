import 'package:flutter/material.dart';

import '../../../data/session_repository.dart';
import '../../themes/presentation/cyt_theme.dart';
import '../application/stats_providers.dart';
import '../../presets/domain/plan_summary.dart';
import '../domain/heatmap_metric.dart';
import 'heatmap_colors.dart';

const _weekdayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _monthLabels = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// Ví dụ "Oct 14, 2026".
String _formatDate(DateTime d) =>
    '${_monthLabels[d.month - 1]} ${d.day}, ${d.year}';

/// Chú thích giá trị một ngày: "1 session" / "3 sessions" / "45 min focus".
String _valueLabel(int n, HeatmapMetric metric) => switch (metric) {
  HeatmapMetric.sessions => n == 1 ? '1 session' : '$n sessions',
  HeatmapMetric.minutes => '${formatDuration(Duration(minutes: n))} focus',
};

/// Lưới heatmap kiểu GitHub contributions.
///
/// Mỗi cột là một tuần (T2 → CN), tuần mới nhất ở bên phải; mỗi ô là một
/// ngày, màu theo số phiên focus hoàn thành trong ngày đó.
class SessionHeatmap extends StatelessWidget {
  const SessionHeatmap({
    super.key,
    required this.counts,
    required this.today,
    this.weeks = heatmapWeeks,
    this.metric = HeatmapMetric.sessions,
  });

  /// "yyyy-MM-dd" → giá trị ngày theo [metric] (số phiên hoặc số phút).
  final Map<String, int> counts;
  final HeatmapMetric metric;
  final DateTime today;
  final int weeks;

  static const double _gap = 3;
  static const double _labelWidth = 28;
  static const double _monthRowHeight = 16;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      fontSize: 9,
      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
    );
    final start = heatmapStart(today, weeks: weeks);
    final todayDate = DateTime(today.year, today.month, today.day);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Co ô theo bề ngang: lấp đầy chỗ trống, giới hạn 6–18px.
        final cell = ((constraints.maxWidth - _labelWidth) / weeks - _gap)
            .clamp(6.0, 18.0);

        Widget weekColumn(int w) {
          final days = [
            for (var d = 0; d < 7; d++)
              DateTime(start.year, start.month, start.day + w * 7 + d),
          ];
          // Ghi tên tháng ở cột chứa ngày mùng 1 (bỏ cột đầu cho khỏi chật).
          final firstOfMonth = days.where((d) => d.day == 1).firstOrNull;
          final monthLabel = w > 0 && firstOfMonth != null
              ? _monthLabels[firstOfMonth.month - 1]
              : null;
          return Padding(
            padding: const EdgeInsets.only(right: _gap),
            child: Column(
              children: [
                SizedBox(
                  width: cell,
                  height: _monthRowHeight,
                  child: monthLabel == null
                      ? null
                      : OverflowBox(
                          alignment: Alignment.bottomLeft,
                          maxWidth: 40,
                          child: Text(monthLabel, style: labelStyle),
                        ),
                ),
                for (final day in days)
                  Padding(
                    padding: const EdgeInsets.only(bottom: _gap),
                    child: day.isAfter(todayDate)
                        ? SizedBox.square(dimension: cell)
                        : HeatmapCell(
                            key: ValueKey(dayKey(day)),
                            date: day,
                            count: counts[dayKey(day)] ?? 0,
                            metric: metric,
                            size: cell,
                            isToday: day == todayDate,
                            brightness: brightness,
                          ),
                  ),
              ],
            ),
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: _labelWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: _monthRowHeight),
                  for (final label in _weekdayLabels)
                    SizedBox(
                      height: cell + _gap,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(label, style: labelStyle),
                      ),
                    ),
                ],
              ),
            ),
            for (var w = 0; w < weeks; w++) weekColumn(w),
          ],
        );
      },
    );
  }
}

/// Một ô ngày. Khi số phiên tăng thì "nảy" lên và đổi màu mượt.
class HeatmapCell extends StatefulWidget {
  const HeatmapCell({
    super.key,
    required this.date,
    required this.count,
    this.metric = HeatmapMetric.sessions,
    required this.size,
    required this.isToday,
    required this.brightness,
    this.height,
    this.child,
  });

  /// Chiều cao ô; null = vuông ([size] × [size]).
  final double? height;

  /// Nội dung trong ô (số ngày, giá trị…).
  final Widget? child;

  final DateTime date;
  final int count;
  final HeatmapMetric metric;
  final double size;
  final bool isToday;
  final Brightness brightness;

  @override
  State<HeatmapCell> createState() => _HeatmapCellState();
}

class _HeatmapCellState extends State<HeatmapCell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );
  late final Animation<double> _scale = TweenSequence([
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.45), weight: 40),
    TweenSequenceItem(tween: Tween(begin: 1.45, end: 1.0), weight: 60),
  ]).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeOut));

  @override
  void didUpdateWidget(HeatmapCell old) {
    super.didUpdateWidget(old);
    if (widget.count > old.count) _pulse.forward(from: 0);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Tooltip(
      message:
          '${_valueLabel(widget.count, widget.metric)} · '
          '${_formatDate(widget.date)}',
      waitDuration: const Duration(milliseconds: 150),
      child: ScaleTransition(
        scale: _scale,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
          width: widget.size,
          height: widget.height ?? widget.size,
          decoration: BoxDecoration(
            color: heatmapColor(
              widget.count,
              widget.brightness,
              palette: CytTheme.of(context).heatmap,
              max: widget.metric.maxValue,
            ),
            borderRadius: BorderRadius.circular(
              (widget.size * 0.2).clamp(0.0, 14.0),
            ),
            border: widget.isToday
                ? Border.all(
                    color: onSurface.withValues(alpha: 0.55),
                    width: 1.2,
                  )
                : null,
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

/// Chú giải "Ít → Nhiều".
class HeatmapLegend extends StatelessWidget {
  const HeatmapLegend({super.key, this.metric = HeatmapMetric.sessions});

  final HeatmapMetric metric;

  /// Mẫu màu: trống, ít nhất, ~40%, ~70%, đậm nhất.
  List<int> get _samples {
    final max = metric.maxValue;
    return [0, 1, (max * 0.4).round(), (max * 0.7).round(), max];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.labelSmall;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Less', style: style),
        const SizedBox(width: 4),
        for (final (i, n) in _samples.indexed)
          Container(
            key: ValueKey('legend-$i'),
            width: 10,
            height: 10,
            margin: const EdgeInsets.symmetric(horizontal: 1.5),
            decoration: BoxDecoration(
              color: heatmapColor(
                n,
                theme.brightness,
                palette: CytTheme.of(context).heatmap,
                max: metric.maxValue,
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        const SizedBox(width: 4),
        Text('More', style: style),
      ],
    );
  }
}
