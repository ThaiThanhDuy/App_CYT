import 'package:flutter/material.dart';

import '../../../themes/domain/theme_package.dart';
import '../../../themes/presentation/cyt_theme.dart';
import '../../domain/timer_engine.dart';
import '../../domain/timer_phase.dart';
import '../led_timer_display.dart';

/// Mọi thứ một renderer cần để vẽ đồng hồ.
@immutable
class TimerVisualState {
  const TimerVisualState({
    required this.remaining,
    required this.phase,
    required this.status,
    required this.progress,
    required this.colonOn,
    this.infinite = false,
    this.elapsed = Duration.zero,
    this.ending = false,
  });

  final Duration remaining;
  final TimerPhase phase;
  final TimerStatus status;

  /// Tiến độ bước hiện tại, 0 → 1.
  final double progress;

  /// Dấu ':' đang sáng (nhấp nháy khi tạm dừng).
  final bool colonOn;

  /// Bước hiện tại không giới hạn thời gian (hiện hiệu ứng ∞).
  final bool infinite;

  /// Thời gian bước hiện tại đã chạy.
  final Duration elapsed;

  /// 10% thời gian cuối của bước → hiện màu vàng báo sắp đổi pha.
  final bool ending;
}

/// Cách vẽ đồng hồ, chọn theo `renderer.type` của gói theme.
///
/// Renderer chỉ là code có sẵn trong app; gói theme chỉ cung cấp dữ liệu
/// (spec + asset như .riv, .json, .glb).
abstract interface class TimerRenderer {
  Widget build(BuildContext context, TimerVisualState state);
}

typedef TimerRendererFactory =
    TimerRenderer Function(RendererSpec spec, ThemePackage package);

/// Bảng đăng ký renderer theo `type`. Giai đoạn sau đăng ký thêm, ví dụ:
///
/// ```dart
/// TimerRendererRegistry.register('model3d', (spec, pkg) =>
///     Model3dRenderer(pkg.source.filePath(spec.asset!)));  // flutter_scene
/// ```
///
/// Type chưa hỗ trợ sẽ rơi về "led7" để theme mới vẫn dùng được trên app cũ.
abstract final class TimerRendererRegistry {
  static final Map<String, TimerRendererFactory> _factories = {
    RendererSpec.led7: (_, _) => const LedTimerRenderer(),
  };

  static void register(String type, TimerRendererFactory factory) =>
      _factories[type] = factory;

  static bool supports(String type) => _factories.containsKey(type);

  static TimerRenderer resolve(ThemePackage package) {
    final spec = package.renderer;
    final factory = _factories[spec.type] ?? _factories[RendererSpec.led7]!;
    return factory(spec, package);
  }
}

/// Renderer mặc định: LED 7 đoạn, màu + kiểu lấy từ [CytTheme].
class LedTimerRenderer implements TimerRenderer {
  const LedTimerRenderer();

  @override
  Widget build(BuildContext context, TimerVisualState state) {
    final theme = CytTheme.of(context);
    return LedTimerDisplay(
      remaining: state.remaining,
      color: theme.clockColor(state.phase, ending: state.ending),
      colonOn: state.colonOn,
      style: theme.led,
      infinite: state.infinite,
      animate: state.status == TimerStatus.running,
    );
  }
}

/// Vẽ đồng hồ bằng renderer của theme hiện tại.
class TimerView extends StatelessWidget {
  const TimerView({super.key, required this.state});

  final TimerVisualState state;

  @override
  Widget build(BuildContext context) {
    final package = CytTheme.of(context).package;
    return TimerRendererRegistry.resolve(package).build(context, state);
  }
}
