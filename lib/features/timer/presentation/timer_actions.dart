import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../alerts/application/alert_providers.dart';
import '../../presets/application/preset_providers.dart';
import '../application/timer_providers.dart';
import '../domain/timer_engine.dart';
import '../domain/timer_plan.dart';
import 'confirm_interrupt.dart';
import 'focus_screen.dart';

/// Bắt đầu / tạm dừng. Lần đầu bấm Bắt đầu thì xin quyền thông báo.
void startOrPauseTimer(WidgetRef ref) {
  if (ref.read(timerControllerProvider).status == TimerStatus.idle) {
    unawaited(ref.read(notificationServiceProvider).requestPermissions());
  }
  ref.read(timerControllerProvider.notifier).startOrPause();
}

Future<void> openClock(BuildContext context) => Navigator.push(
  context,
  MaterialPageRoute<void>(builder: (_) => const FocusScreen()),
);

/// Nút Start trên card: chọn session [plan], chạy nếu chưa chạy, rồi mở
/// màn đồng hồ. Đang chạy session khác thì hỏi trước khi huỷ.
Future<void> startSession(
  BuildContext context,
  WidgetRef ref,
  TimerPlan plan,
) async {
  if (plan.id != ref.read(activePlanProvider).id) {
    if (!await confirmInterruptTimer(context, ref)) return;
    await ref.read(activePresetIdProvider.notifier).select(plan.id!);
  }
  // Đọc lại sau khi chọn: engine đã được tạo mới cho session này.
  final status = ref.read(timerControllerProvider).status;
  if (status == TimerStatus.idle || status == TimerStatus.finished) {
    startOrPauseTimer(ref);
  }
  if (context.mounted) await openClock(context);
}
