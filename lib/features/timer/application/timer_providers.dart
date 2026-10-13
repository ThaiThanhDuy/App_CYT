import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/clock.dart';
import '../domain/timer_engine.dart';
import '../../presets/application/preset_providers.dart';

/// Hệ số tua nhanh: 1 giây thật = 1 phút.
const double fastTimerFactor = 60;

/// Bật sẵn khi chạy với `--dart-define=FAST_TIMER=true`.
const bool fastTimerFromEnvironment = bool.fromEnvironment('FAST_TIMER');

/// Chế độ tua nhanh. UI chỉ hiện công tắc khi kDebugMode.
final fastTimerProvider = NotifierProvider<FastTimerNotifier, bool>(
  FastTimerNotifier.new,
);

class FastTimerNotifier extends Notifier<bool> {
  @override
  bool build() => fastTimerFromEnvironment;

  void set(bool enabled) => state = enabled;
}

/// Giờ thật, dùng cho timestamp lưu DB và xác định "hôm nay".
/// Khác [clockProvider] ở chỗ không bao giờ bị tua nhanh.
final wallClockProvider = Provider<Clock>((ref) => const SystemClock());

/// Clock dùng cho engine. Đổi chế độ tua nhanh sẽ tạo engine mới (reset).
final clockProvider = Provider<Clock>((ref) {
  final fast = ref.watch(fastTimerProvider);
  return fast
      ? ScaledClock(const SystemClock(), fastTimerFactor)
      : const SystemClock();
});

final timerEngineProvider = Provider<TimerEngine>((ref) {
  final engine = TimerEngine(
    plan: ref.watch(activePlanProvider),
    clock: ref.watch(clockProvider),
  );
  ref.onDispose(engine.dispose);
  return engine;
});

/// Luồng sự kiện của engine (hoàn thành bước, bỏ qua, xong chuỗi).
final timerEventsProvider = StreamProvider<TimerEvent>(
  (ref) => ref.watch(timerEngineProvider).events,
);

final timerControllerProvider =
    NotifierProvider<TimerController, TimerSnapshot>(TimerController.new);

/// Cầu nối engine ↔ UI. Ticker chỉ để làm mới màn hình và phát hiện hết giờ,
/// không tham gia vào việc đếm thời gian.
class TimerController extends Notifier<TimerSnapshot> {
  static const tickInterval = Duration(milliseconds: 100);

  late TimerEngine _engine;
  Timer? _ticker;

  @override
  TimerSnapshot build() {
    _engine = ref.watch(timerEngineProvider);
    // Quay lại từ nền: cập nhật ngay, không chờ tick kế tiếp.
    final lifecycle = AppLifecycleListener(onResume: refresh);
    ref.onDispose(() {
      _stopTicker();
      lifecycle.dispose();
    });
    final snapshot = _engine.snapshot;
    _syncTicker(snapshot);
    return snapshot;
  }

  void startOrPause() => _run(_engine.toggle);

  void skip() => _run(_engine.skip);

  /// "Xong" cho bước vô hạn.
  void finishInfinite() => _run(_engine.finishInfinite);

  void reset() => _run(_engine.reset);

  /// Làm mới ngay, ví dụ khi app quay lại foreground.
  void refresh() => _run(() {});

  void _run(void Function() action) {
    action();
    final snapshot = _engine.snapshot;
    state = snapshot;
    _syncTicker(snapshot);
  }

  void _syncTicker(TimerSnapshot snapshot) {
    final needsTicker = snapshot.status == TimerStatus.running;
    if (needsTicker && _ticker == null) {
      _ticker = Timer.periodic(tickInterval, (_) => refresh());
    } else if (!needsTicker) {
      _stopTicker();
    }
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  /// Chỉ báo UI rebuild khi thứ hiển thị thực sự thay đổi.
  @override
  bool updateShouldNotify(TimerSnapshot previous, TimerSnapshot next) =>
      previous.status != next.status ||
      previous.index != next.index ||
      previous.display != next.display;
}
