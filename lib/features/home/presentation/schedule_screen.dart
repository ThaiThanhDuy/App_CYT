import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/widgets/fade_slide_in.dart';
import '../../../data/session_repository.dart';
import '../../presets/application/preset_providers.dart';
import '../../presets/domain/plan_summary.dart';
import '../../schedule/application/schedule_providers.dart';
import '../../schedule/domain/task_block.dart';
import '../../schedule/presentation/block_editor_sheet.dart';
import '../../schedule/presentation/day_timeline.dart';
import '../../schedule/presentation/wall_clock_screen.dart';
import '../../stats/application/stats_providers.dart';
import '../../themes/presentation/cyt_theme.dart';
import '../../timer/application/timer_providers.dart';
import '../../timer/domain/timer_plan.dart';
import '../../timer/presentation/timer_actions.dart';
import '../domain/iso_week.dart';

const _weekdayShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _monthShort = [
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

/// Màn Schedule: lịch tuần (thứ Hai → Chủ nhật) kèm số tuần trong năm,
/// và lịch theo giờ của ngày đang chọn. Xem lại được các tuần trước
/// (trong phạm vi dữ liệu heatmap).
class ScheduleScreen extends ConsumerStatefulWidget {
  const ScheduleScreen({super.key});

  @override
  ConsumerState<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends ConsumerState<ScheduleScreen> {
  /// 0 = tuần này, -1 = tuần trước, …
  int _weekOffset = 0;

  /// Chiều đổi tuần gần nhất (để nội dung trượt đúng hướng).
  int _direction = 0;
  DateTime? _selected;

  /// Làm mới định kỳ để nhãn "NOW" của block theo kịp giờ thật.
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(
      const Duration(seconds: 30),
      (_) => setState(() {}),
    );
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  void _changeWeek(int delta) => setState(() {
    _direction = delta;
    _weekOffset += delta;
    _selected = null;
  });

  void _backToToday() => setState(() {
    _direction = _weekOffset < 0 ? 1 : -1;
    _weekOffset = 0;
    _selected = null;
  });

  /// Session của block (nếu block có gắn và session vẫn còn).
  TimerPlan? _planOf(TaskBlock block) {
    final presets = ref.read(visiblePresetsProvider).value ?? const [];
    return presets.where((p) => p.id == block.presetId).firstOrNull?.plan;
  }

  /// Nút Start: lúc này đang có block gắn session → hiện để bấm chạy (mở
  /// màn đồng hồ); không có thì mở đồng hồ treo tường kiểu zen.
  Future<void> _startNow() async {
    final now = ref.read(wallClockProvider).now();
    final block = await ref.read(taskBlockRepositoryProvider).blockAt(now);
    if (!mounted) return;
    final plan = block == null ? null : _planOf(block);
    // Đã qua phần session của block (session ngắn hơn block): chỉ còn đồng
    // hồ treo tường tới hết block.
    if (block != null && plan != null && !plan.hasInfinite) {
      final sessionEnd = block.start.add(plan.totalDuration);
      if (!now.isBefore(sessionEnd)) {
        _openWallClock(block.title, until: block.end);
        return;
      }
    }
    if (block != null && plan != null) {
      await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        builder: (sheet) => _NowSheet(
          block: block,
          plan: plan,
          onStart: () {
            Navigator.pop(sheet);
            startSession(context, ref, plan, block: block);
          },
          onClock: () {
            Navigator.pop(sheet);
            _openWallClock(block.title);
          },
        ),
      );
    } else {
      _openWallClock(block?.title);
    }
  }

  void _openWallClock(String? blockTitle, {DateTime? until}) => Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) => WallClockScreen(blockTitle: blockTitle, until: until),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final today = ref.watch(todayProvider);
    final now = ref.watch(wallClockProvider).now();
    final stats = ref.watch(dailyStatsProvider).value ?? const {};
    final anchor = DateTime(
      today.year,
      today.month,
      today.day + 7 * _weekOffset,
    );
    final days = weekDaysOf(anchor);
    final week = isoWeekOf(anchor);
    final selected = _selected ?? (_weekOffset == 0 ? today : days.first);

    DayStats statsOf(DateTime d) =>
        stats[dayKey(d)] ?? (sessions: 0, seconds: 0);

    final blocks = ref.watch(weekBlocksProvider(days.first)).value ?? const [];
    List<TaskBlock> blocksOf(DateTime d) => [
      for (final b in blocks)
        if (b.day == d) b,
    ];
    final presets = ref.watch(visiblePresetsProvider).value ?? const [];
    final planById = {for (final p in presets) p.id: p.plan};

    // Lùi tới hết dữ liệu thống kê; tiến tới 12 tuần để lên kế hoạch.
    final canGoBack = _weekOffset > -(heatmapWeeks - 1);
    final canGoForward = _weekOffset < 12;

    final header = FadeSlideIn(
      child: _Header(
        week: week.week,
        days: days,
        showToday: _weekOffset != 0,
        onPrev: canGoBack ? () => _changeWeek(-1) : null,
        onNext: canGoForward ? () => _changeWeek(1) : null,
        onToday: _backToToday,
        onAddBlock: () => showBlockEditor(context, day: selected),
      ),
    );

    // Dải 7 ngày; đổi tuần thì nội dung
    // cũ trượt ra, tuần mới trượt vào.
    final week7 = AnimatedSwitcher(
      duration: const Duration(milliseconds: 380),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        final incoming = child.key == ValueKey(_weekOffset);
        final dx = (incoming ? 0.08 : -0.08) * _direction;
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween(
              begin: Offset(dx, 0),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.topCenter,
        children: [...previous, ?current],
      ),
      child: Column(
        key: ValueKey(_weekOffset),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FadeSlideIn(
            index: 1,
            child: Row(
              children: [
                for (final (i, day) in days.indexed) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    child: _DayCard(
                      weekday: _weekdayShort[i],
                      day: day,
                      isToday: day == today,
                      isFuture: day.isAfter(today),
                      selected: day == selected,
                      sessions: statsOf(day).sessions,
                      blocks: blocksOf(day).length,
                      onTap: () => setState(() => _selected = day),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    // Lịch theo giờ của ngày đang chọn (kiểu Google Calendar): bấm ô giờ
    // trống để tạo block.
    Widget timeline({double? height}) => FadeSlideIn(
      index: 3,
      child: DayTimeline(
        height: height,
        day: selected,
        isToday: selected == today,
        now: now,
        blocks: blocksOf(selected),
        planById: planById,
        onTapBlock: (b) => showBlockEditor(context, block: b),
        onCreateAt: (minute) =>
            showBlockEditor(context, day: selected, startMinute: minute),
        onStartPlan: (block, plan) =>
            startSession(context, ref, plan, block: block),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Schedule')),
      // Start: chạy block đang diễn ra (nếu có session) hoặc mở đồng hồ.
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _startNow,
        icon: const Icon(Icons.play_arrow_rounded),
        label: const Text('Start'),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Màn rộng: 2 cột (lịch tuần + thống kê | lịch theo giờ cao hết
          // màn) để không trống hai bên; màn hẹp: 1 cột cuộn.
          if (constraints.maxWidth >= 1100) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1600),
                child: Padding(
                  // Đáy chừa chỗ cho nút Start để không đè lên lịch.
                  padding: const EdgeInsets.fromLTRB(40, 8, 40, 88),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 5,
                        child: ListView(
                          padding: const EdgeInsets.only(bottom: 96),
                          children: [header, const SizedBox(height: 24), week7],
                        ),
                      ),
                      const SizedBox(width: 32),
                      Expanded(
                        flex: 6,
                        child: LayoutBuilder(
                          builder: (context, c) =>
                              timeline(height: c.maxHeight),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: ListView(
                // Chừa chỗ cho nút Start.
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 112),
                children: [
                  header,
                  const SizedBox(height: 20),
                  week7,
                  const SizedBox(height: 16),
                  timeline(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// "Week 42" + khoảng ngày, nút tuần trước / sau / về tuần này.
class _Header extends StatelessWidget {
  const _Header({
    required this.week,
    required this.days,
    required this.showToday,
    required this.onPrev,
    required this.onNext,
    required this.onToday,
    required this.onAddBlock,
  });

  final VoidCallback onAddBlock;
  final int week;
  final List<DateTime> days;
  final bool showToday;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    String short(DateTime d) => '${_monthShort[d.month - 1]} ${d.day}';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: Text(
                      'Week $week',
                      key: ValueKey(week),
                      style: theme.textTheme.displaySmall,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Tạo block công việc mới.
                  IconButton.filledTonal(
                    tooltip: 'New block',
                    onPressed: onAddBlock,
                    icon: const Icon(Icons.edit_outlined),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${short(days.first)} – ${short(days.last)}, '
                '${days.last.year}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: showToday
              ? TextButton(onPressed: onToday, child: const Text('Today'))
              : const SizedBox.shrink(),
        ),
        IconButton.outlined(
          tooltip: 'Previous week',
          onPressed: onPrev,
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        const SizedBox(width: 6),
        IconButton.outlined(
          tooltip: 'Next week',
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }
}

/// Card một ngày: thứ, ngày, chấm số phiên. Chọn = tô đặc; hôm nay = viền
/// màu Focus; ngày tương lai mờ đi.
class _DayCard extends StatelessWidget {
  const _DayCard({
    required this.weekday,
    required this.day,
    required this.isToday,
    required this.isFuture,
    required this.selected,
    required this.sessions,
    required this.blocks,
    required this.onTap,
  });

  /// Số block công việc trong ngày.
  final int blocks;
  final String weekday;
  final DateTime day;
  final bool isToday;
  final bool isFuture;
  final bool selected;
  final int sessions;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = CytTheme.of(context).focus;
    final fg = selected ? scheme.surface : scheme.onSurface;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 250),
      opacity: isFuture ? 0.7 : 1,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: selected ? scheme.onSurface : scheme.surfaceContainer,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isToday && !selected ? accent : Colors.transparent,
            width: 1.6,
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          borderRadius: BorderRadius.circular(18),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Column(
                children: [
                  Text(
                    weekday,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: fg.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${day.day}',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: fg,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 8),
                  _SessionDots(
                    count: sessions,
                    color: selected ? scheme.surface : accent,
                  ),
                  const SizedBox(height: 6),
                  // Vạch nhỏ: ngày có block công việc.
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: blocks > 0 ? 16 : 0,
                    height: 3,
                    decoration: BoxDecoration(
                      color: fg.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tối đa 4 chấm cho số phiên trong ngày; nhiều hơn thì chấm cuối thành "+".
class _SessionDots extends StatelessWidget {
  const _SessionDots({required this.count, required this.color});

  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final shown = math.min(count, 4);
    return SizedBox(
      height: 8,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < shown; i++)
            Container(
              width: 5,
              height: 5,
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              decoration: BoxDecoration(
                color: i == 3 && count > 4
                    ? color.withValues(alpha: 0.5)
                    : color,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }
}

/// Bảng hiện khi bấm Start lúc đang có block gắn session: bấm để chạy.
class _NowSheet extends StatelessWidget {
  const _NowSheet({
    required this.block,
    required this.plan,
    required this.onStart,
    required this.onClock,
  });

  final TaskBlock block;
  final TimerPlan plan;
  final VoidCallback onStart;
  final VoidCallback onClock;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = CytTheme.of(context).focus;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'NOW · ${formatMinuteOfDay(block.startMinute)} – '
            '${formatMinuteOfDay(block.endMinute)}',
            style: theme.textTheme.labelMedium?.copyWith(
              color: accent,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 6),
          Text(block.title, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(
            '${plan.name} · ${describeSteps(plan)}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onStart,
            style: FilledButton.styleFrom(
              shape: const StadiumBorder(),
              minimumSize: const Size.fromHeight(52),
            ),
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Start session'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: onClock,
            child: const Text('Just show the clock'),
          ),
        ],
      ),
    );
  }
}
