import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../presets/application/preset_providers.dart';
import '../../../themes/presentation/cyt_theme.dart';
import '../../application/timer_providers.dart';
import '../../domain/timer_engine.dart';
import '../../domain/timer_phase.dart';
import 'ascii_grid.dart';
import 'ascii_scenes.dart';
import 'scene_math.dart';

/// Chu kỳ chảy hết một lượt của đồng hồ cát (bước vô hạn).
const Duration hourglassCycle = Duration(minutes: 15);

/// Thời gian lật đồng hồ cát (giờ thật).
const Duration _flipDuration = Duration(milliseconds: 1200);

/// Cảnh ASCII art thay cho đồng hồ trong chế độ zen:
/// - Focus: cây táo lớn từ hạt tới khi chín quả đúng lúc hết giờ.
/// - Break: ăn quả táo, lấy hạt gieo lại cho lượt Focus kế tiếp.
/// - Bước vô hạn: đồng hồ cát chảy hết mỗi 15 phút rồi lật ngược.
class TimerSceneView extends ConsumerStatefulWidget {
  const TimerSceneView({super.key, required this.snapshot});

  final TimerSnapshot snapshot;

  @override
  ConsumerState<TimerSceneView> createState() => _TimerSceneViewState();
}

class _TimerSceneViewState extends ConsumerState<TimerSceneView>
    with SingleTickerProviderStateMixin {
  /// Chuyển động nền (lá đung đưa, cát rơi); chỉ chạy khi timer đang chạy.
  late final AnimationController _ambient = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  );

  bool get _running => widget.snapshot.status == TimerStatus.running;

  @override
  void initState() {
    super.initState();
    if (_running) _ambient.repeat();
  }

  @override
  void didUpdateWidget(TimerSceneView old) {
    super.didUpdateWidget(old);
    if (_running && !_ambient.isAnimating) {
      _ambient.repeat();
    } else if (!_running && _ambient.isAnimating) {
      _ambient.stop();
    }
  }

  @override
  void dispose() {
    _ambient.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.snapshot;
    final theme = Theme.of(context);
    final cyt = CytTheme.of(context);
    final colors = AsciiSceneColors(
      leaf: cyt.focus,
      apple: cyt.rest,
      sand: cyt.warning,
      ground: theme.colorScheme.onSurface.withValues(alpha: 0.45),
      frame: theme.colorScheme.onSurface,
      dark: theme.brightness == Brightness.dark,
    );
    final finished = s.status == TimerStatus.finished;

    final total = s.step.duration.inMilliseconds;
    final progress = finished
        ? 1.0
        : total <= 0
        ? 0.0
        : (1 - s.remaining.inMilliseconds / total).clamp(0.0, 1.0);

    // Pha đung đưa của tán lá (một chu kỳ = 6 giây của _ambient).
    double sway() => _ambient.value;

    // Mỗi bước một key: sang bước mới thì cảnh bắt đầu lại từ đầu (không
    // chạy ngược tiến độ), và cảnh cũ mờ dần sang cảnh mới.
    final Widget scene;
    if (s.isInfinite) {
      scene = _HourglassScene(
        key: ValueKey('hourglass-${s.index}'),
        elapsed: s.elapsed,
        running: _running,
        ambient: _ambient,
        colors: colors,
      );
    } else if (finished || s.phase == TimerPhase.focus) {
      final plan = ref.watch(activePlanProvider);
      // Focus ngay sau một lượt Break (có gieo hạt) thì hạt đã nằm sẵn.
      final prev = s.index > 0 ? plan.stepAt(s.index - 1) : null;
      final seedOnGround =
          prev != null && prev.phase == TimerPhase.rest && !prev.infinite;
      scene = _SmoothProgress(
        key: ValueKey('grow-${s.index}-$finished'),
        value: progress,
        builder: (p) => AnimatedBuilder(
          animation: _ambient,
          builder: (context, _) => AsciiArt(
            grid: buildGrowScene(
              colors,
              progress: p,
              swayPhase: sway(),
              seedOnGround: seedOnGround,
            ),
          ),
        ),
      );
    } else {
      scene = _SmoothProgress(
        key: ValueKey('eat-${s.index}'),
        value: progress,
        builder: (p) => AnimatedBuilder(
          animation: _ambient,
          builder: (context, _) =>
              AsciiArt(grid: buildEatScene(colors, progress: p)),
        ),
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 700),
      child: SizedBox.expand(
        key: scene.key,
        child: Center(child: scene),
      ),
    );
  }
}

/// Nội suy tiến độ giữa các lần cập nhật (mỗi giây) để cảnh chạy liên tục.
class _SmoothProgress extends StatelessWidget {
  const _SmoothProgress({
    super.key,
    required this.value,
    required this.builder,
  });

  final double value;
  final Widget Function(double value) builder;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: value, end: value),
    duration: const Duration(milliseconds: 950),
    builder: (context, v, _) => builder(v),
  );
}

class _HourglassScene extends ConsumerWidget {
  const _HourglassScene({
    super.key,
    required this.elapsed,
    required this.running,
    required this.ambient,
    required this.colors,
  });

  final Duration elapsed;
  final bool running;
  final Animation<double> ambient;
  final AsciiSceneColors colors;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Clock tua nhanh chạy ×60 → lật vẫn mất ~1,2 giây giờ thật.
    final factor = ref.watch(fastTimerProvider) ? fastTimerFactor : 1.0;
    final flipMs = _flipDuration.inMilliseconds * factor;
    final cycleMs = hourglassCycle.inMilliseconds.toDouble();

    return TweenAnimationBuilder<double>(
      tween: Tween(end: elapsed.inMilliseconds.toDouble()),
      duration: const Duration(milliseconds: 950),
      builder: (context, ms, _) {
        double fill;
        double flip = 0;
        if (ms < cycleMs) {
          fill = ms / cycleMs;
        } else {
          final inCycle = ms % cycleMs;
          if (inCycle < flipMs) {
            // Đang lật: cát đã xuống hết, quay 180° là cát lại ở trên.
            fill = 1;
            flip = inCycle / flipMs;
          } else {
            fill = (inCycle - flipMs) / (cycleMs - flipMs);
          }
        }
        return Transform.rotate(
          angle: math.pi * easeInOut(flip),
          child: AnimatedBuilder(
            animation: ambient,
            builder: (context, _) => AsciiArt(
              grid: buildHourglassScene(
                colors,
                fill: fill.clamp(0.0, 1.0),
                // Mỗi hạt cát rơi hết quãng trong ~1 giây.
                streamPhase: (ambient.value * 6) % 1,
                running: running && flip == 0,
              ),
            ),
          ),
        );
      },
    );
  }
}
