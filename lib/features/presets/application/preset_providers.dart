import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/data_providers.dart';
import '../../timer/domain/timer_plan.dart';
import '../domain/preset_entry.dart';

/// Danh sách session đã lưu, tự cập nhật khi DB đổi.
final presetsProvider = StreamProvider<List<PresetEntry>>(
  (ref) => ref.watch(presetRepositoryProvider).watchAll(),
);

/// Session đã bấm xoá nhưng còn trong thời gian Undo: ẩn khỏi giao diện,
/// chỉ xoá khỏi DB khi snackbar đóng mà không bấm Undo. Id không bao giờ
/// được dùng lại (AUTOINCREMENT) nên giữ id sau khi xoá thật cũng vô hại.
final pendingDeletionProvider =
    NotifierProvider<PendingDeletionNotifier, Set<int>>(
      PendingDeletionNotifier.new,
    );

class PendingDeletionNotifier extends Notifier<Set<int>> {
  @override
  Set<int> build() => const {};

  void add(int id) => state = {...state, id};

  void remove(int id) => state = {...state}..remove(id);
}

/// Danh sách session hiển thị: bỏ những session đang chờ xoá.
final visiblePresetsProvider = Provider<AsyncValue<List<PresetEntry>>>((ref) {
  final pending = ref.watch(pendingDeletionProvider);
  return ref
      .watch(presetsProvider)
      .whenData(
        (list) => [
          for (final e in list)
            if (!pending.contains(e.id)) e,
        ],
      );
});

/// Id preset đang chọn, lưu trong SharedPreferences để nhớ qua lần mở app.
final activePresetIdProvider = NotifierProvider<ActivePresetIdNotifier, int?>(
  ActivePresetIdNotifier.new,
);

class ActivePresetIdNotifier extends Notifier<int?> {
  static const _key = 'activePresetId';

  @override
  int? build() => ref.watch(sharedPreferencesProvider).getInt(_key);

  Future<void> select(int id) async {
    state = id;
    await ref.read(sharedPreferencesProvider).setInt(_key, id);
  }
}

/// Plan mà engine đang dùng.
///
/// Lấy preset theo id đã chọn; nếu không còn (bị xoá) thì lấy preset đầu
/// tiên; khi DB chưa nạp xong thì dùng Pomodoro dựng sẵn.
/// [TimerPlan] so sánh theo giá trị nên engine chỉ bị tạo lại khi plan
/// thực sự đổi.
final activePlanProvider = Provider<TimerPlan>((ref) {
  final presets =
      ref.watch(visiblePresetsProvider).value ?? const <PresetEntry>[];
  if (presets.isEmpty) return TimerPlan.pomodoro;
  final id = ref.watch(activePresetIdProvider);
  return presets
      .firstWhere((p) => p.id == id, orElse: () => presets.first)
      .plan;
});

/// Id các session đang tắt chuông.
final mutedPresetIdsProvider = Provider<Set<int>>((ref) {
  final presets = ref.watch(presetsProvider).value ?? const <PresetEntry>[];
  return {
    for (final p in presets)
      if (p.muted) p.id,
  };
});
