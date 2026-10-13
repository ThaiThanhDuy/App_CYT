import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/widgets/smooth_progress.dart';
import '../../../data/data_providers.dart';
import '../../presets/application/preset_providers.dart';
import '../../presets/domain/plan_summary.dart';
import '../../themes/application/theme_providers.dart';
import '../../themes/presentation/cyt_theme.dart';
import '../application/timer_providers.dart';
import '../domain/timer_engine.dart';
import 'renderers/timer_renderer.dart';
import 'scenes/timer_scene_view.dart';
import 'timer_actions.dart';

const _fade = Duration(milliseconds: 300);

/// Màn đồng hồ: mở từ nút Start trên card ở màn chính.
///
/// Có chế độ zen (nút phóng to / phím F): chỉ còn đồng hồ to hết cỡ và một
/// nút thu nhỏ để thoát; trên điện thoại ẩn luôn thanh hệ thống.
class FocusScreen extends ConsumerStatefulWidget {
  const FocusScreen({super.key});

  @override
  ConsumerState<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends ConsumerState<FocusScreen> {
  bool _zen = false;

  /// Trang trong chế độ zen: 0 = đồng hồ, 1 = cảnh hoạt hình.
  final _zenPages = PageController();
  int _zenPage = 0;

  void _goZenPage(int page) {
    if (!_zen || !_zenPages.hasClients) return;
    _zenPages.animateToPage(
      page.clamp(0, 1),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
    );
  }

  static bool get _isMobile =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  void _setZen(bool on) {
    setState(() => _zen = on);
    if (_isMobile) {
      SystemChrome.setEnabledSystemUIMode(
        on ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
      );
    }
  }

  @override
  void dispose() {
    _zenPages.dispose();
    // Rời màn khi đang zen: trả lại thanh hệ thống.
    if (_zen && _isMobile) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    super.dispose();
  }

  static double _progress(TimerSnapshot s) {
    final total = s.step.duration.inMilliseconds;
    if (total <= 0 || s.status == TimerStatus.finished) return 1;
    return (1 - s.remaining.inMilliseconds / total).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(timerControllerProvider);
    final controller = ref.read(timerControllerProvider.notifier);
    final plan = ref.watch(activePlanProvider);
    final muted = ref.watch(mutedPresetIdsProvider).contains(plan.id);
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final accent = CytTheme.of(
      context,
    ).clockColor(snapshot.phase, ending: snapshot.isEnding);
    final finished = snapshot.status == TimerStatus.finished;
    final running = snapshot.status == TimerStatus.running;
    final progressStyle = ref.watch(progressStyleProvider);

    final phaseLabel = finished
        ? 'COMPLETE'
        : '${snapshot.step.displayName.toUpperCase()}'
              '${snapshot.isInfinite ? '  ·  ∞' : ''}';

    // Đồng hồ (nhấp nháy dấu ':' khi tạm dừng), dùng cho cả chế độ thường
    // và chế độ zen.
    Widget timerView() => _BlinkWhen(
      enabled: snapshot.status == TimerStatus.paused,
      builder: (visible) => TimerView(
        state: TimerVisualState(
          remaining: snapshot.remaining,
          phase: snapshot.phase,
          status: snapshot.status,
          progress: _progress(snapshot),
          colonOn: visible,
          infinite: snapshot.isInfinite,
          elapsed: snapshot.elapsed,
          ending: snapshot.isEnding,
        ),
      ),
    );

    // Chế độ zen: chỉ đồng hồ, to hết cỡ, và nút thu nhỏ ở góc.
    final zenBody = Stack(
      key: const ValueKey('zen'),
      children: [
        SafeArea(
          child: LayoutBuilder(
            builder: (context, c) => Column(
              children: [
                // Vuốt / phím ←→ để đổi giữa đồng hồ và cảnh hoạt hình.
                Expanded(
                  child: ScrollConfiguration(
                    // Desktop: cho kéo bằng chuột để đổi trang.
                    behavior: ScrollConfiguration.of(
                      context,
                    ).copyWith(dragDevices: PointerDeviceKind.values.toSet()),
                    child: PageView(
                      controller: _zenPages,
                      onPageChanged: (i) => setState(() => _zenPage = i),
                      children: [
                        Center(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: c.maxWidth * 0.94,
                              maxHeight: c.maxHeight * 0.8,
                            ),
                            child: timerView(),
                          ),
                        ),
                        // Cảnh ASCII dùng gần hết trang để nhìn to, rõ.
                        Padding(
                          padding: const EdgeInsets.fromLTRB(56, 8, 56, 0),
                          child: TimerSceneView(snapshot: snapshot),
                        ),
                      ],
                    ),
                  ),
                ),
                _PageDots(count: 2, current: _zenPage, color: accent),
                const SizedBox(height: 16),
                // Thanh tiến trình ở đáy (bước vô hạn không có tiến trình).
                AnimatedOpacity(
                  opacity: snapshot.isInfinite ? 0 : 1,
                  duration: _fade,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: c.maxWidth * 0.7),
                    child: SmoothProgress(
                      value: _progress(snapshot),
                      color: accent,
                      height: 4,
                      trackColor: theme.colorScheme.surfaceContainerHigh,
                      style: progressStyle,
                      barHeight: 44,
                      animate: running,
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
        // Mũi tên mờ ở mép để đổi trang.
        for (final (page, align, icon, tip) in const [
          (1, Alignment.centerRight, Icons.chevron_right_rounded, 'Scene (→)'),
          (0, Alignment.centerLeft, Icons.chevron_left_rounded, 'Clock (←)'),
        ])
          Align(
            alignment: align,
            child: SafeArea(
              child: AnimatedOpacity(
                opacity: _zenPage == page ? 0 : 1,
                duration: _fade,
                child: IgnorePointer(
                  ignoring: _zenPage == page,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: IconButton(
                      tooltip: tip,
                      iconSize: 32,
                      color: theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.6,
                      ),
                      onPressed: () => _goZenPage(page),
                      icon: Icon(icon),
                    ),
                  ),
                ),
              ),
            ),
          ),
        Positioned(
          right: 12,
          bottom: 12,
          child: SafeArea(
            child: IconButton(
              tooltip: 'Exit focus mode (F)',
              onPressed: () => _setZen(false),
              color: theme.colorScheme.onSurfaceVariant,
              icon: const Icon(Icons.fullscreen_exit_rounded),
            ),
          ),
        ),
      ],
    );

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyF): () => _setZen(!_zen),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
            _goZenPage(1),
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
            _goZenPage(0),
        const SingleActivator(LogicalKeyboardKey.space): () =>
            startOrPauseTimer(ref),
        const SingleActivator(LogicalKeyboardKey.keyN): controller.skip,
        const SingleActivator(LogicalKeyboardKey.keyR): controller.reset,
        const SingleActivator(LogicalKeyboardKey.enter):
            controller.finishInfinite,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          extendBodyBehindAppBar: true,
          appBar: _zen
              ? null
              : AppBar(
                  backgroundColor: Colors.transparent,
                  centerTitle: true,
                  title: Text(
                    plan.name,
                    style: textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  actions: [
                    IconButton(
                      tooltip: 'Focus mode (F)',
                      onPressed: () => _setZen(true),
                      icon: const Icon(Icons.fullscreen_rounded),
                    ),
                    if (plan.id != null)
                      IconButton(
                        tooltip: muted ? 'Unmute' : 'Mute',
                        onPressed: () => ref
                            .read(presetRepositoryProvider)
                            .setMuted(plan.id!, muted: !muted),
                        icon: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          transitionBuilder: (child, a) =>
                              ScaleTransition(scale: a, child: child),
                          child: Icon(
                            muted
                                ? Icons.notifications_off_outlined
                                : Icons.notifications_none_rounded,
                            key: ValueKey(muted),
                          ),
                        ),
                      ),
                    const SizedBox(width: 8),
                  ],
                ),
          body: AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: _zen
                ? zenBody
                : Stack(
                    key: const ValueKey('normal'),
                    children: [
                      // Quầng sáng rất nhẹ theo màu pha phía sau đồng hồ (dark mode).
                      if (theme.brightness == Brightness.dark)
                        Positioned.fill(
                          child: TweenAnimationBuilder<Color?>(
                            tween: ColorTween(end: accent),
                            duration: const Duration(milliseconds: 600),
                            builder: (context, c, _) => DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: RadialGradient(
                                  radius: 0.9,
                                  colors: [
                                    (c ?? accent).withValues(alpha: 0.07),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      SafeArea(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            // Màn ngang (điện thoại nằm ngang, desktop full screen):
                            // đồng hồ bên trái, điều khiển bên phải.
                            final wide =
                                constraints.maxWidth >
                                constraints.maxHeight * 1.2;

                            final clock = Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AnimatedSwitcher(
                                  duration: _fade,
                                  child: Text(
                                    phaseLabel,
                                    key: ValueKey(phaseLabel),
                                    textAlign: TextAlign.center,
                                    style: textTheme.labelLarge?.copyWith(
                                      letterSpacing: 4,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _RoundDots(snapshot: snapshot, color: accent),
                                const SizedBox(height: 10),
                                // Giờ kết thúc bước hiện tại (chỉ màn thường).
                                _EndAtLabel(snapshot: snapshot),
                                SizedBox(height: wide ? 24 : 16),
                                // Giới hạn chiều cao để đồng hồ không tràn màn thấp.
                                ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxHeight: wide
                                        ? constraints.maxHeight * 0.58
                                        : double.infinity,
                                  ),
                                  child: timerView(),
                                ),
                                const SizedBox(height: 20),
                                AnimatedSwitcher(
                                  duration: _fade,
                                  child: snapshot.isInfinite
                                      ? Text(
                                          'Elapsed ${snapshot.display}',
                                          key: const ValueKey('elapsed'),
                                          style: textTheme.titleLarge?.copyWith(
                                            fontWeight: FontWeight.w300,
                                            fontFeatures: const [
                                              FontFeature.tabularFigures(),
                                            ],
                                          ),
                                        )
                                      : ConstrainedBox(
                                          key: const ValueKey('progress'),
                                          constraints: const BoxConstraints(
                                            maxWidth: 560,
                                          ),
                                          child: SmoothProgress(
                                            value: _progress(snapshot),
                                            color: accent,
                                            height: 4,
                                            trackColor: theme
                                                .colorScheme
                                                .surfaceContainerHigh,
                                            style: progressStyle,
                                            barHeight: 32,
                                            animate: running,
                                          ),
                                        ),
                                ),
                              ],
                            );

                            final controls = Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _Controls(
                                  status: snapshot.status,
                                  controller: controller,
                                  onStartOrPause: () => startOrPauseTimer(ref),
                                ),
                                // Bước vô hạn: bấm Xong để kết thúc và tính phiên.
                                AnimatedSize(
                                  duration: _fade,
                                  curve: Curves.easeOutCubic,
                                  child:
                                      snapshot.isInfinite &&
                                          snapshot.status != TimerStatus.idle
                                      ? Padding(
                                          padding: const EdgeInsets.only(
                                            top: 20,
                                          ),
                                          child: OutlinedButton.icon(
                                            onPressed:
                                                controller.finishInfinite,
                                            style: OutlinedButton.styleFrom(
                                              shape: const StadiumBorder(),
                                            ),
                                            icon: const Icon(
                                              Icons.check_rounded,
                                            ),
                                            label: const Text('Done'),
                                          ),
                                        )
                                      : const SizedBox(width: 0),
                                ),
                                const SizedBox(height: 24),
                                _PlanInfo(
                                  snapshot: snapshot,
                                  totalLabel: plan.hasInfinite
                                      ? '∞'
                                      : formatDuration(plan.totalDuration),
                                  accent: accent,
                                ),
                              ],
                            );

                            if (wide) {
                              return Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  48,
                                  56,
                                  48,
                                  24,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(child: Center(child: clock)),
                                    const SizedBox(width: 56),
                                    controls,
                                  ],
                                ),
                              );
                            }
                            return Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 560,
                                ),
                                child: ListView(
                                  shrinkWrap: true,
                                  padding: const EdgeInsets.fromLTRB(
                                    24,
                                    72,
                                    24,
                                    32,
                                  ),
                                  children: [
                                    clock,
                                    const SizedBox(height: 40),
                                    controls,
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// Dưới nút điều khiển: icon lặp lại + bong bóng số vòng đang chạy, và
/// icon đồng hồ cát + tổng thời gian của chuỗi.
class _PlanInfo extends StatelessWidget {
  const _PlanInfo({
    required this.snapshot,
    required this.totalLabel,
    required this.accent,
  });

  final TimerSnapshot snapshot;
  final String totalLabel;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final textStyle = theme.textTheme.bodyMedium?.copyWith(
      color: muted,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final total = snapshot.totalRounds;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Chỉ có 1 vòng thì không cần biết đang ở vòng mấy.
        if (total > 1) ...[
          Tooltip(
            message: 'Round ${snapshot.round} of $total',
            child: Badge(
              backgroundColor: accent,
              textColor: theme.colorScheme.surface,
              offset: const Offset(10, -8),
              label: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (child, a) =>
                    ScaleTransition(scale: a, child: child),
                child: Text(
                  '${snapshot.round}',
                  key: ValueKey(snapshot.round),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              child: Icon(Icons.repeat_rounded, size: 22, color: muted),
            ),
          ),
          const SizedBox(width: 28),
        ],
        Tooltip(
          message: 'Total time',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.hourglass_bottom_rounded, size: 20, color: muted),
              const SizedBox(width: 4),
              Text(
                totalLabel,
                // "∞" to gần bằng icon đồng hồ cát (20px).
                style: totalLabel == '∞'
                    ? textStyle?.copyWith(fontSize: 22, height: 1)
                    : textStyle,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// "End at HH:MM" (24h): lúc bước hiện tại kết thúc = giờ thật + thời gian
/// còn lại. Tự làm mới định kỳ để khi tạm dừng giờ kết thúc vẫn lùi đúng.
/// Ẩn ở bước vô hạn và khi đã xong chuỗi.
class _EndAtLabel extends ConsumerStatefulWidget {
  const _EndAtLabel({required this.snapshot});

  final TimerSnapshot snapshot;

  @override
  ConsumerState<_EndAtLabel> createState() => _EndAtLabelState();
}

class _EndAtLabelState extends ConsumerState<_EndAtLabel> {
  Timer? _refresh;

  @override
  void initState() {
    super.initState();
    _refresh = Timer.periodic(
      const Duration(seconds: 15),
      (_) => setState(() {}),
    );
  }

  @override
  void dispose() {
    _refresh?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.snapshot;
    final hidden = s.isInfinite || s.status == TimerStatus.finished;
    final factor = ref.watch(fastTimerProvider) ? fastTimerFactor : 1.0;
    // Clock tua nhanh chạy ×60 → quy thời gian còn lại về giờ thật.
    final end = ref
        .watch(wallClockProvider)
        .now()
        .add(s.remaining * (1 / factor));
    String two(int v) => v.toString().padLeft(2, '0');
    final textTheme = Theme.of(context).textTheme;

    return AnimatedSwitcher(
      duration: _fade,
      child: hidden
          ? const SizedBox(key: ValueKey('none'), height: 20)
          : Text(
              'Ends at ${two(end.hour)}:${two(end.minute)}',
              key: const ValueKey('end'),
              style: textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
    );
  }
}

/// Chấm chỉ trang (chế độ zen): trang hiện tại là vạch dài màu pha.
class _PageDots extends StatelessWidget {
  const _PageDots({
    required this.count,
    required this.current,
    required this.color,
  });

  final int count;
  final int current;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.outline;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == current ? 18 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: i == current ? color : muted,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
      ],
    );
  }
}

/// Hàng chấm thể hiện vòng: đã xong (đậm), đang chạy (màu pha), chưa tới
/// (viền). Nhiều vòng quá thì hiện dạng chữ.
class _RoundDots extends StatelessWidget {
  const _RoundDots({required this.snapshot, required this.color});

  final TimerSnapshot snapshot;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final total = snapshot.totalRounds;
    final finished = snapshot.status == TimerStatus.finished;
    if (total <= 1) return const SizedBox(height: 8);
    if (total > 12) {
      return Text(
        'Round ${snapshot.round}/$total',
        style: Theme.of(context).textTheme.bodySmall,
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var r = 1; r <= total; r++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            // Vòng hiện tại dài hơn, như một thanh trượt.
            width: r == snapshot.round && !finished ? 22 : 8,
            height: 8,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: finished || r < snapshot.round
                  ? scheme.onSurface.withValues(alpha: 0.75)
                  : r == snapshot.round
                  ? color
                  : Colors.transparent,
              border: Border.all(
                color: r > snapshot.round && !finished
                    ? scheme.outline
                    : Colors.transparent,
              ),
            ),
          ),
      ],
    );
  }
}

/// Nút điều khiển: Huỷ · Bắt đầu/Tạm dừng (tròn lớn) · Bỏ qua.
class _Controls extends StatefulWidget {
  const _Controls({
    required this.status,
    required this.controller,
    required this.onStartOrPause,
  });

  final TimerStatus status;
  final TimerController controller;
  final VoidCallback onStartOrPause;

  @override
  State<_Controls> createState() => _ControlsState();
}

class _ControlsState extends State<_Controls>
    with SingleTickerProviderStateMixin {
  // 0 = play, 1 = pause; biến hình mượt giữa hai icon.
  late final AnimationController _morph = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
    value: widget.status == TimerStatus.running ? 1 : 0,
  );

  @override
  void didUpdateWidget(_Controls old) {
    super.didUpdateWidget(old);
    if (widget.status == TimerStatus.running) {
      _morph.forward();
    } else {
      _morph.reverse();
    }
  }

  @override
  void dispose() {
    _morph.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final status = widget.status;
    final active =
        status == TimerStatus.running || status == TimerStatus.paused;
    final tooltip = switch (status) {
      TimerStatus.running => 'Pause (Space)',
      TimerStatus.paused => 'Resume (Space)',
      TimerStatus.idle => 'Start (Space)',
      TimerStatus.finished => 'Restart (Space)',
    };

    Widget side({
      required String tooltip,
      required IconData icon,
      required VoidCallback? onPressed,
    }) => IconButton.outlined(
      tooltip: tooltip,
      onPressed: onPressed,
      iconSize: 26,
      style: IconButton.styleFrom(
        fixedSize: const Size.square(60),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      icon: Icon(icon),
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        side(
          tooltip: 'Reset (R)',
          icon: Icons.stop_rounded,
          onPressed: active ? widget.controller.reset : null,
        ),
        const SizedBox(width: 28),
        Tooltip(
          message: tooltip,
          child: FilledButton(
            onPressed: widget.onStartOrPause,
            style: FilledButton.styleFrom(
              shape: const CircleBorder(),
              fixedSize: const Size.square(88),
              minimumSize: const Size.square(88),
              padding: EdgeInsets.zero,
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (child, a) =>
                  ScaleTransition(scale: a, child: child),
              child: status == TimerStatus.finished
                  ? const Icon(
                      Icons.replay_rounded,
                      size: 38,
                      key: ValueKey('replay'),
                    )
                  : AnimatedIcon(
                      key: const ValueKey('play_pause'),
                      icon: AnimatedIcons.play_pause,
                      progress: _morph,
                      size: 40,
                    ),
            ),
          ),
        ),
        const SizedBox(width: 28),
        side(
          tooltip: 'Skip (N)',
          icon: Icons.skip_next_rounded,
          onPressed: status == TimerStatus.finished
              ? null
              : widget.controller.skip,
        ),
      ],
    );
  }
}

/// Nhấp nháy 500ms bật/tắt khi [enabled]; ngược lại luôn hiện.
class _BlinkWhen extends StatefulWidget {
  const _BlinkWhen({required this.enabled, required this.builder});

  final bool enabled;
  final Widget Function(bool visible) builder;

  @override
  State<_BlinkWhen> createState() => _BlinkWhenState();
}

class _BlinkWhenState extends State<_BlinkWhen> {
  Timer? _timer;
  bool _visible = true;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(_BlinkWhen old) {
    super.didUpdateWidget(old);
    if (old.enabled != widget.enabled) _sync();
  }

  void _sync() {
    _timer?.cancel();
    _timer = null;
    _visible = true;
    if (widget.enabled) {
      _timer = Timer.periodic(
        const Duration(milliseconds: 500),
        (_) => setState(() => _visible = !_visible),
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(_visible);
}
