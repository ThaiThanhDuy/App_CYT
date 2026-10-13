import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/data_providers.dart';
import '../../timer/domain/timer_plan.dart';
import '../application/preset_providers.dart';

/// Thời gian cho phép bấm Undo sau khi xoá.
const Duration undoWindow = Duration(seconds: 5);

/// Xoá session [plan] kèm Undo: ẩn ngay khỏi giao diện, hiện snackbar
/// "Deleted … · Undo"; hết [undoWindow] mà không Undo mới xoá khỏi DB.
///
/// Dùng container và messenger cấp app nên vẫn chạy đúng khi màn gọi hàm
/// này (màn sửa session) đã đóng.
void deleteSessionWithUndo(BuildContext context, TimerPlan plan) {
  final id = plan.id!;
  final container = ProviderScope.containerOf(context, listen: false);
  final pending = container.read(pendingDeletionProvider.notifier);
  pending.add(id);

  final controller = ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('Deleted "${plan.name}"'),
      duration: undoWindow,
      // Có action thì mặc định không tự đóng; ở đây cần tự đóng để xoá thật.
      persist: false,
      action: SnackBarAction(
        label: 'Undo',
        onPressed: () => pending.remove(id),
      ),
    ),
  );
  controller.closed.then((reason) async {
    if (reason == SnackBarClosedReason.action) return;
    await container.read(presetRepositoryProvider).delete(id);
  });
}
