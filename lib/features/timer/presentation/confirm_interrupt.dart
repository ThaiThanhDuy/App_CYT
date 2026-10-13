import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/timer_providers.dart';
import '../domain/timer_engine.dart';

/// Hỏi lại trước khi làm một việc sẽ huỷ phiên đang chạy/tạm dừng
/// (đổi preset, sửa preset đang dùng...). Trả về true nếu được phép làm tiếp.
Future<bool> confirmInterruptTimer(BuildContext context, WidgetRef ref) async {
  final status = ref.read(timerControllerProvider).status;
  if (status != TimerStatus.running && status != TimerStatus.paused) {
    return true;
  }
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Stop the current session?'),
      content: const Text(
        "This resets the timer. The unfinished session won't be counted.",
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Continue'),
        ),
      ],
    ),
  );
  return ok ?? false;
}
