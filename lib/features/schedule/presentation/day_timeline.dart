import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../themes/presentation/cyt_theme.dart';
import '../../timer/domain/timer_plan.dart';
import '../domain/task_block.dart';
import 'block_colors.dart';

/// Chiều cao một giờ trên lịch; cột trái (viên giờ hiện tại) và cột phải
/// (mốc giờ).
const double _hourHeight = 60;
const double _nowWidth = 84;
const double _labelWidth = 52;
const double _pillHeight = 24;

/// Bo góc block = bề rộng thanh màu bên trái, để thanh phủ hết cung bo.
const double _blockRadius = 8;
const double _defaultHeight = 560;

/// Một block đã xếp chỗ: cột thứ [col] trong [cols] cột (khi trùng giờ).
typedef _Placed = ({TaskBlock block, int col, int cols});

/// Xếp block trùng giờ thành các cột cạnh nhau (giống lịch ngày của Google
/// Calendar): mỗi cụm block chồng nhau chia đều bề ngang.
List<_Placed> _layout(List<TaskBlock> blocks) {
  final sorted = [...blocks]
    ..sort((a, b) {
      final byStart = a.startMinute.compareTo(b.startMinute);
      return byStart != 0 ? byStart : b.endMinute.compareTo(a.endMinute);
    });
  final result = <_Placed>[];
  final cluster = <(TaskBlock, int)>[];
  final colEnds = <int>[];
  var clusterEnd = -1;

  void flush() {
    for (final (b, c) in cluster) {
      result.add((block: b, col: c, cols: colEnds.length));
    }
    cluster.clear();
    colEnds.clear();
  }

  for (final b in sorted) {
    if (cluster.isNotEmpty && b.startMinute >= clusterEnd) flush();
    var col = colEnds.indexWhere((end) => end <= b.startMinute);
    if (col < 0) {
      col = colEnds.length;
      colEnds.add(b.endMinute);
    } else {
      colEnds[col] = b.endMinute;
    }
    cluster.add((b, col));
    clusterEnd = math.max(clusterEnd, b.endMinute);
  }
  flush();
  return result;
}

/// Lịch theo giờ của một ngày (00:00 → 24:00) kiểu Google Calendar: block
/// đặt theo giờ, vạch đỏ "bây giờ", bấm ô giờ trống để tạo block.
class DayTimeline extends StatefulWidget {
  const DayTimeline({
    super.key,
    required this.day,
    required this.isToday,
    required this.now,
    required this.blocks,
    required this.planById,
    required this.onTapBlock,
    required this.onCreateAt,
    required this.onStartPlan,
    this.height,
  });

  /// Chiều cao khung lịch; null = 560 (màn hẹp).
  final double? height;

  final DateTime day;
  final bool isToday;
  final DateTime now;
  final List<TaskBlock> blocks;
  final Map<int, TimerPlan> planById;
  final ValueChanged<TaskBlock> onTapBlock;

  /// Bấm ô giờ trống: tạo block bắt đầu ở phút này.
  final ValueChanged<int> onCreateAt;
  final void Function(TaskBlock block, TimerPlan plan) onStartPlan;

  @override
  State<DayTimeline> createState() => _DayTimelineState();
}

class _DayTimelineState extends State<DayTimeline> {
  final _scroll = ScrollController();

  /// Phút cần đưa vào tầm nhìn: giờ hiện tại (hôm nay), block đầu tiên, hoặc
  /// 08:00.
  int get _focusMinute {
    if (widget.isToday) return widget.now.hour * 60 + widget.now.minute;
    if (widget.blocks.isNotEmpty) {
      return widget.blocks.map((b) => b.startMinute).reduce(math.min);
    }
    return 8 * 60;
  }

  double get _focusOffset => math.max(0, (_focusMinute / 60 - 1) * _hourHeight);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_clamp(_focusOffset));
    });
  }

  @override
  void didUpdateWidget(DayTimeline old) {
    super.didUpdateWidget(old);
    // Đổi ngày: cuộn mượt tới giờ đáng xem của ngày mới.
    if (old.day != widget.day && _scroll.hasClients) {
      _scroll.animateTo(
        _clamp(_focusOffset),
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
    }
  }

  double _clamp(double v) => v.clamp(0.0, _scroll.position.maxScrollExtent);

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        height: widget.height ?? _defaultHeight,
        color: scheme.surfaceContainerLow,
        child: SingleChildScrollView(
          controller: _scroll,
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: SizedBox(
            height: 24 * _hourHeight,
            child: LayoutBuilder(
              builder: (context, c) {
                final gridWidth = c.maxWidth - _nowWidth - _labelWidth;
                return Stack(
                  children: [
                    // Hàng giờ: đường kẻ + mốc giờ bên phải; bấm để tạo block.
                    for (var h = 0; h < 24; h++)
                      Positioned(
                        top: h * _hourHeight,
                        left: 0,
                        right: 0,
                        height: _hourHeight,
                        child: InkWell(
                          onTap: () => widget.onCreateAt(h * 60),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(width: _nowWidth),
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    border: Border(
                                      top: BorderSide(
                                        color: scheme.outlineVariant.withValues(
                                          alpha: 0.6,
                                        ),
                                        width: 0.8,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: _labelWidth,
                                child: Transform.translate(
                                  offset: const Offset(0, -7),
                                  child: Text(
                                    h == 0
                                        ? ''
                                        : '${h.toString().padLeft(2, '0')}:00',
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      letterSpacing: 0,
                                      fontFeatures: const [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Giờ hiện tại + vạch đỏ — vẽ trước block để vạch không
                    // đè lên chữ; viên giờ nằm ở cột trái nên không bị che.
                    if (widget.isToday) const _NowIndicator(),

                    // Block theo giờ (trùng giờ thì chia cột).
                    for (final p in _layout(widget.blocks))
                      Positioned(
                        top: p.block.startMinute / 60 * _hourHeight + 1,
                        height: math.max(
                          22,
                          (p.block.endMinute - p.block.startMinute) /
                                  60 *
                                  _hourHeight -
                              3,
                        ),
                        left: _nowWidth + gridWidth / p.cols * p.col + 2,
                        width: gridWidth / p.cols - 4,
                        child: _TimelineBlock(
                          block: p.block,
                          plan: widget.planById[p.block.presetId],
                          active:
                              widget.isToday && p.block.contains(widget.now),
                          onTap: () => widget.onTapBlock(p.block),
                          onStart: (plan) => widget.onStartPlan(p.block, plan),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Viên thuốc "HH:MM:SS" ở cột trái + vạch đỏ ngang lịch. Tự tick đúng đầu
/// mỗi giây; vị trí trượt tuyến tính trong 1 giây nên đi liền mạch, chữ số
/// nào đổi thì trượt lên.
class _NowIndicator extends StatefulWidget {
  const _NowIndicator();

  @override
  State<_NowIndicator> createState() => _NowIndicatorState();
}

class _NowIndicatorState extends State<_NowIndicator> {
  DateTime _now = DateTime.now();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  /// Hẹn tick kế tiếp đúng lúc sang giây mới.
  void _schedule() {
    final wait = 1000 - DateTime.now().millisecond;
    _timer = Timer(Duration(milliseconds: wait), () {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
      _schedule();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final red = CytTheme.of(context).rest;
    final seconds = _now.hour * 3600 + _now.minute * 60 + _now.second;
    String two(int v) => v.toString().padLeft(2, '0');
    final text = '${two(_now.hour)}:${two(_now.minute)}:${two(_now.second)}';
    final style = theme.textTheme.labelMedium?.copyWith(
      color: Colors.white,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.5,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    return AnimatedPositioned(
      duration: const Duration(seconds: 1),
      curve: Curves.linear,
      top: seconds / 3600 * _hourHeight - _pillHeight / 2,
      left: 6,
      right: _labelWidth,
      height: _pillHeight,
      child: IgnorePointer(
        child: Row(
          children: [
            Container(
              width: _nowWidth - 10,
              height: _pillHeight,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: red,
                borderRadius: BorderRadius.circular(_pillHeight / 2),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Mỗi ký tự một ô: chỉ ký tự đổi mới chạy hiệu ứng.
                  for (var i = 0; i < text.length; i++)
                    ClipRect(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 280),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (child, animation) {
                          final incoming =
                              child.key == ValueKey('$i${text[i]}');
                          return SlideTransition(
                            position: Tween(
                              begin: Offset(0, incoming ? 1 : -1),
                              end: Offset.zero,
                            ).animate(animation),
                            child: FadeTransition(
                              opacity: animation,
                              child: child,
                            ),
                          );
                        },
                        child: Text(
                          text[i],
                          key: ValueKey('$i${text[i]}'),
                          style: style,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(child: Container(height: 2, color: red)),
          ],
        ),
      ),
    );
  }
}

/// Một block trên lịch, tối giản: nền nhạt + vạch trái, tên, giờ · session,
/// nút ▶ nhỏ. Session ngắn hơn block: thanh trái chỉ sáng ở đoạn có session,
/// đoạn còn lại (chỉ hiện đồng hồ) mờ — không có gì cắt ngang chữ.
class _TimelineBlock extends StatelessWidget {
  const _TimelineBlock({
    required this.block,
    required this.plan,
    required this.active,
    required this.onTap,
    required this.onStart,
  });

  final TaskBlock block;
  final TimerPlan? plan;
  final bool active;
  final VoidCallback onTap;
  final ValueChanged<TimerPlan> onStart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final plan = this.plan;
    final tint = blockColorOf(context, block);
    final minutes = block.endMinute - block.startMinute;
    final time =
        '${formatMinuteOfDay(block.startMinute)} – '
        '${formatMinuteOfDay(block.endMinute)}';
    final subtitle = plan == null ? time : '$time · ${plan.name}';

    // Tỉ lệ phần có session (1 = cả block). Phần còn lại < 10 phút thì bỏ
    // qua cho đỡ rối.
    final sessionMinutes = plan == null || plan.hasInfinite
        ? minutes
        : (plan.totalDuration.inSeconds / 60).ceil();
    final sessionFactor = minutes - sessionMinutes >= 10
        ? sessionMinutes / minutes
        : 1.0;
    final base = scheme.surfaceContainerHigh;
    final fill = Color.alphaBlend(
      tint.withValues(alpha: active ? 0.24 : 0.14),
      base,
    );

    final secondary = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(_blockRadius),
        border: Border.all(
          color: active ? tint.withValues(alpha: 0.7) : Colors.transparent,
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: BorderRadius.circular(_blockRadius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            children: [
              // Thanh trái: đoạn sáng = phần session, đoạn mờ = phần chỉ
              // hiện đồng hồ (session ngắn hơn block).
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: _blockRadius,
                child: ColoredBox(
                  color: tint.withValues(alpha: 0.25),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: FractionallySizedBox(
                      heightFactor: sessionFactor,
                      widthFactor: 1,
                      child: ColoredBox(color: tint),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(_blockRadius + 7, 3, 2, 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: minutes < 45
                          // Block ngắn: một dòng.
                          ? Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: block.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  TextSpan(
                                    text: '  $subtitle',
                                    style: secondary,
                                  ),
                                ],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall,
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  block.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: secondary,
                                ),
                              ],
                            ),
                    ),
                    if (plan != null && minutes >= 45)
                      IconButton(
                        tooltip: 'Start ${plan.name}',
                        onPressed: () => onStart(plan),
                        color: tint,
                        iconSize: 20,
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints.tightFor(
                          width: 32,
                          height: 32,
                        ),
                        icon: const Icon(Icons.play_arrow_rounded),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
