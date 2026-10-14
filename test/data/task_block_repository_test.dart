import 'package:counting_your_time/data/app_db.dart';
import 'package:counting_your_time/features/schedule/data/task_block_repository.dart';
import 'package:counting_your_time/features/schedule/domain/task_block.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late TaskBlockRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = TaskBlockRepository(db);
  });

  tearDown(() => db.close());

  TaskBlock block(String title, DateTime day, int start, int end) =>
      TaskBlock(title: title, day: day, startMinute: start, endMinute: end);

  test('liệt kê block trong tuần, sắp theo ngày rồi giờ', () async {
    final mon = DateTime(2026, 10, 12);
    await repo.create(block('B', DateTime(2026, 10, 13), 600, 660));
    await repo.create(block('A', mon, 540, 600));
    await repo.create(block('C', mon, 480, 520));
    await repo.create(block('Next week', DateTime(2026, 10, 19), 0, 60));

    final list = await repo.watchBetween(mon, DateTime(2026, 10, 18)).first;
    expect(list.map((b) => b.title), ['C', 'A', 'B']);
  });

  test('blockAt: tính lúc bắt đầu, không tính lúc kết thúc', () async {
    final day = DateTime(2026, 10, 14);
    await repo.create(block('Deep work', day, 9 * 60, 10 * 60 + 30));

    expect((await repo.blockAt(DateTime(2026, 10, 14, 9)))?.title, 'Deep work');
    expect(
      (await repo.blockAt(DateTime(2026, 10, 14, 10, 29)))?.title,
      'Deep work',
    );
    expect(await repo.blockAt(DateTime(2026, 10, 14, 10, 30)), isNull);
    expect(await repo.blockAt(DateTime(2026, 10, 15, 9, 30)), isNull);
  });

  test('block chồng nhau: lấy block bắt đầu muộn nhất', () async {
    final day = DateTime(2026, 10, 14);
    await repo.create(block('Morning', day, 8 * 60, 12 * 60));
    await repo.create(block('Meeting', day, 10 * 60, 11 * 60));
    expect(
      (await repo.blockAt(DateTime(2026, 10, 14, 10, 15)))?.title,
      'Meeting',
    );
  });

  test('sửa và xoá block', () async {
    final day = DateTime(2026, 10, 14);
    final id = await repo.create(block('Draft', day, 60, 120));
    final saved = (await repo.watchBetween(day, day).first).single;
    expect(saved.id, id);

    await repo.update(saved.copyWith(title: 'Final', endMinute: 180));
    final updated = (await repo.watchBetween(day, day).first).single;
    expect(updated.title, 'Final');
    expect(updated.endMinute, 180);

    await repo.delete(id);
    expect(await repo.watchBetween(day, day).first, isEmpty);
  });
}
