import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../presets/application/preset_providers.dart';
import '../../themes/application/theme_providers.dart';
import '../../timer/application/timer_providers.dart';
import '../../timer/domain/timer_engine.dart';
import '../data/notification_service.dart';
import '../data/sound_player.dart';
import '../domain/alert_message.dart';

/// Được khởi tạo trong `main()` rồi override. Mặc định (test) là service
/// chưa init → mọi hàm no-op.
final notificationServiceProvider = Provider<NotificationService>(
  (ref) => NotificationService(),
);

final soundPlayerProvider = Provider<SoundPlayer>((ref) {
  final player = AudioSoundPlayer();
  ref.onDispose(player.dispose);
  return player;
});

/// Sự kiện hết giờ cũ hơn ngưỡng này (theo giờ thật) là do chạy bù sau khi
/// app ở nền → không kêu nữa (thông báo hẹn trước đã báo rồi).
const _staleAfter = Duration(seconds: 3);

/// Điều phối âm thanh + thông báo khi hết giờ.
///
/// - App đang mở: phát âm thanh; Linux hiện thêm thông báo hệ thống.
/// - Android/iOS vào nền: hẹn trước thông báo cho các mốc sắp tới (thông báo
///   tự có tiếng nên app không phát thêm); quay lại thì huỷ.
/// - Android: khi đang chạy giữ foreground service + thông báo đếm ngược để
///   tiến trình không bị hệ điều hành dừng.
///
/// Cần được `watch` ở gốc app.
final alertCoordinatorProvider = Provider<void>((ref) {
  final engine = ref.watch(timerEngineProvider);
  final engineClock = ref.watch(clockProvider);
  final wall = ref.watch(wallClockProvider);
  final notifications = ref.watch(notificationServiceProvider);
  final factor = ref.watch(fastTimerProvider) ? fastTimerFactor : 1.0;
  var hidden = false;

  /// Session đang chạy bị tắt chuông (nút chuông trên card).
  bool isSilent() => ref.read(mutedPresetIdsProvider).contains(engine.plan.id);

  /// Đổi mốc theo clock của engine (có thể đang tua nhanh) sang giờ thật.
  DateTime toWallTime(DateTime engineTime) =>
      wall.now().add(engineTime.difference(engineClock.now()) * (1 / factor));

  final sub = engine.events.listen((event) {
    // Bước vô hạn kết thúc do người dùng bấm Xong → không cần báo.
    if (event is! StepCompleted || event.step.infinite) return;
    final lateBy = engineClock.now().difference(event.endedAt) * (1 / factor);
    if (lateBy > _staleAfter) return;
    final nextIndex = event.index + 1;
    final message = alertForStepEnd(
      ended: event.step,
      next: nextIndex < engine.plan.length
          ? engine.plan.stepAt(nextIndex)
          : null,
      planName: engine.plan.name,
    );
    // Đang ở nền trên mobile: thông báo hẹn trước đã kêu, tránh kêu hai lần.
    final notifiedByOs = hidden && notifications.supportsScheduling;
    if (!isSilent() && !notifiedByOs) {
      // Theme đang hiển thị (nếu chọn "theo hệ thống" thì tuỳ sáng/tối).
      final theme = ref
          .read(resolvedThemesProvider)
          .current(
            WidgetsBinding.instance.platformDispatcher.platformBrightness,
          );
      unawaited(
        ref.read(soundPlayerProvider).play(message.resolveSound(theme)),
      );
    }
    if (notifications.showsImmediately) {
      unawaited(notifications.showNow(message));
    }
  });

  /// Bật/cập nhật/tắt thông báo đếm ngược theo trạng thái timer.
  void syncOngoing(TimerSnapshot snapshot) {
    if (!notifications.supportsOngoing) return;
    if (snapshot.status != TimerStatus.running) {
      unawaited(notifications.stopOngoing());
      return;
    }
    final at = snapshot.isInfinite
        ? wall.now().subtract(snapshot.elapsed * (1 / factor))
        : wall.now().add(snapshot.remaining * (1 / factor));
    unawaited(
      notifications.showOngoing((
        title:
            '${snapshot.step.displayName} · round '
            '${snapshot.round}/${snapshot.totalRounds}',
        body: engine.plan.name,
        at: at,
        countUp: snapshot.isInfinite,
      )),
    );
  }

  // Chỉ đồng bộ khi đổi trạng thái hoặc đổi bước, không phải mỗi giây.
  ref.listen<TimerSnapshot>(timerControllerProvider, (prev, next) {
    if (prev == null ||
        prev.status != next.status ||
        prev.index != next.index) {
      syncOngoing(next);
    }
  }, fireImmediately: true);

  final lifecycle = AppLifecycleListener(
    onHide: () {
      hidden = true;
      final alerts = [
        for (final end in engine.upcomingStepEnds())
          (
            at: toWallTime(end.at),
            message: alertForStepEnd(
              ended: end.step,
              next: end.next,
              planName: engine.plan.name,
            ),
          ),
      ];
      unawaited(notifications.scheduleAll(alerts, silent: isSilent()));
    },
    onShow: () {
      hidden = false;
      unawaited(notifications.cancelScheduled());
    },
  );

  ref.onDispose(() {
    sub.cancel();
    lifecycle.dispose();
    // Engine bị thay (đổi preset, tua nhanh) → mốc cũ không còn đúng.
    unawaited(notifications.cancelScheduled());
    unawaited(notifications.stopOngoing());
  });
});
