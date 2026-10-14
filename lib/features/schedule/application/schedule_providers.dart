import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/data_providers.dart';
import '../data/task_block_repository.dart';
import '../domain/task_block.dart';

final taskBlockRepositoryProvider = Provider<TaskBlockRepository>(
  (ref) => TaskBlockRepository(ref.watch(appDatabaseProvider)),
);

/// Block của tuần bắt đầu từ thứ Hai [monday] (7 ngày), tự cập nhật.
final weekBlocksProvider = StreamProvider.family<List<TaskBlock>, DateTime>(
  (ref, monday) => ref
      .watch(taskBlockRepositoryProvider)
      .watchBetween(
        monday,
        DateTime(monday.year, monday.month, monday.day + 6),
      ),
);

/// Block mà session đang chạy được bắt đầu từ đó (nút ▶ trên lịch / Start ở
/// Schedule), hoặc null. Session xong sớm hơn block → màn đồng hồ chuyển sang
/// đồng hồ treo tường cho phần còn lại của block.
final sessionBlockProvider = NotifierProvider<SessionBlockNotifier, TaskBlock?>(
  SessionBlockNotifier.new,
);

class SessionBlockNotifier extends Notifier<TaskBlock?> {
  @override
  TaskBlock? build() => null;

  void set(TaskBlock? block) => state = block;
}
