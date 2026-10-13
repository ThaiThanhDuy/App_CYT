import 'package:counting_your_time/data/app_db.dart';
import 'package:counting_your_time/data/preset_repository.dart';
import 'package:counting_your_time/data/session_repository.dart';
import 'package:counting_your_time/data/steps_codec.dart';
import 'package:counting_your_time/features/timer/domain/timer_phase.dart';
import 'package:counting_your_time/features/timer/domain/timer_plan.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late SessionRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = SessionRepository(db);
  });

  tearDown(() => db.close());

  /// Ghi một phiên 25 phút kết thúc tại [end] (giờ máy).
  Future<void> record(DateTime end) => repo.recordFocus(
    startedAt: end.subtract(const Duration(minutes: 25)),
    endedAt: end,
    focusSeconds: 25 * 60,
  );

  Future<Map<String, int>> counts(DateTime from, DateTime to) =>
      repo.watchDailyCounts(from: from, to: to).first;

  group('dayKey', () {
    test('định dạng yyyy-MM-dd theo giờ máy', () {
      expect(dayKey(DateTime(2026, 3, 7, 23, 59, 59)), '2026-03-07');
      expect(dayKey(DateTime(2026, 12, 31)), '2026-12-31');
    });

    test('UTC được đổi sang giờ máy trước khi lấy ngày', () {
      final utc = DateTime.utc(2026, 3, 7, 12);
      expect(dayKey(utc), dayKey(utc.toLocal()));
    });
  });

  group('watchDailyCounts', () {
    test('đếm số phiên theo từng ngày (GROUP BY day)', () async {
      await record(DateTime(2026, 3, 2, 9));
      await record(DateTime(2026, 3, 2, 10));
      await record(DateTime(2026, 3, 2, 11));
      await record(DateTime(2026, 3, 4, 15));

      expect(await counts(DateTime(2026, 3, 1), DateTime(2026, 3, 31)), {
        '2026-03-02': 3,
        '2026-03-04': 1,
      });
    });

    test(
      'quanh nửa đêm: 23:59:59 và 00:00:00 thuộc hai ngày khác nhau',
      () async {
        await record(DateTime(2026, 3, 7, 23, 59, 59));
        await record(DateTime(2026, 3, 8));
        await record(DateTime(2026, 3, 8, 0, 0, 1));

        expect(await counts(DateTime(2026, 3, 1), DateTime(2026, 3, 31)), {
          '2026-03-07': 1,
          '2026-03-08': 2,
        });
      },
    );

    test('phiên vắt qua nửa đêm được tính vào ngày kết thúc', () async {
      // Bắt đầu 23:50 ngày 7, kết thúc 00:15 ngày 8.
      await repo.recordFocus(
        startedAt: DateTime(2026, 3, 7, 23, 50),
        endedAt: DateTime(2026, 3, 8, 0, 15),
        focusSeconds: 25 * 60,
      );
      expect(await counts(DateTime(2026, 3, 1), DateTime(2026, 3, 31)), {
        '2026-03-08': 1,
      });
    });

    test('lọc theo khoảng, tính cả hai đầu', () async {
      await record(DateTime(2026, 2, 28, 23, 59));
      await record(DateTime(2026, 3, 1, 0, 1));
      await record(DateTime(2026, 3, 31, 23, 59));
      await record(DateTime(2026, 4, 1, 0, 1));

      expect(await counts(DateTime(2026, 3, 1), DateTime(2026, 3, 31)), {
        '2026-03-01': 1,
        '2026-03-31': 1,
      });
    });

    test('stream tự phát lại khi có phiên mới', () async {
      final stream = repo.watchDailyCounts(
        from: DateTime(2026, 3, 1),
        to: DateTime(2026, 3, 31),
      );
      final expectation = expectLater(
        stream,
        emitsInOrder([
          <String, int>{},
          {'2026-03-02': 1},
          {'2026-03-02': 2},
        ]),
      );
      await pumpEventQueue();
      await record(DateTime(2026, 3, 2, 9));
      await pumpEventQueue();
      await record(DateTime(2026, 3, 2, 10));
      await expectation;
    });
  });

  group('watchDailyStats', () {
    test('cộng số phiên và tổng giây tập trung theo ngày', () async {
      await repo.recordFocus(
        startedAt: DateTime(2026, 3, 2, 9),
        endedAt: DateTime(2026, 3, 2, 9, 25),
        focusSeconds: 25 * 60,
      );
      await repo.recordFocus(
        startedAt: DateTime(2026, 3, 2, 10),
        endedAt: DateTime(2026, 3, 2, 12),
        focusSeconds: 2 * 3600,
      );
      final stats = await repo
          .watchDailyStats(
            from: DateTime(2026, 3, 1),
            to: DateTime(2026, 3, 31),
          )
          .first;
      expect(stats, {'2026-03-02': (sessions: 2, seconds: 25 * 60 + 7200)});
    });
  });

  group('presets', () {
    test('DB mới có sẵn preset Pomodoro 25/5 ×4', () async {
      final all = await db.select(db.presets).get();
      expect(all, hasLength(1));
      expect(all.single.name, TimerPlan.pomodoro.name);
      expect(all.single.repeat, 4);
      expect(decodeSteps(all.single.stepsJson), TimerPlan.pomodoro.steps);
    });

    test('session mới nằm cuối, reorder đổi thứ tự hiển thị', () async {
      final presets = PresetRepository(db);
      final first = (await presets.watchAll().first).single.id;
      final second = await presets.create(
        const TimerPlan(
          name: 'B',
          steps: [TimerStep.focus(Duration(minutes: 50))],
        ),
      );
      final third = await presets.create(
        const TimerPlan(
          name: 'C',
          steps: [TimerStep.rest(Duration(minutes: 5))],
        ),
      );
      Future<List<int>> ids() async => [
        for (final e in await presets.watchAll().first) e.id,
      ];
      expect(await ids(), [first, second, third]);

      await presets.reorder([third, first, second]);
      expect(await ids(), [third, first, second]);

      // Session tạo sau khi đã sắp vẫn nằm cuối.
      final fourth = await presets.create(
        const TimerPlan(
          name: 'D',
          steps: [TimerStep.focus(Duration(minutes: 10))],
        ),
      );
      expect(await ids(), [third, first, second, fourth]);
    });

    test('xoá preset thì phiên giữ lại, presetId thành null', () async {
      final id = (await db.select(db.presets).getSingle()).id;
      await repo.recordFocus(
        startedAt: DateTime(2026, 3, 2, 9),
        endedAt: DateTime(2026, 3, 2, 9, 25),
        focusSeconds: 1500,
        presetId: id,
      );
      await (db.delete(db.presets)..where((p) => p.id.equals(id))).go();

      final session = await db.select(db.completedSessions).getSingle();
      expect(session.presetId, isNull);
    });
  });

  group('steps codec', () {
    test('mã hoá rồi giải mã giữ nguyên', () {
      const steps = [
        TimerStep.focus(Duration(minutes: 50), sound: 'bell'),
        TimerStep.rest(Duration(minutes: 10)),
      ];
      expect(decodeSteps(encodeSteps(steps)), steps);
    });

    test('tên riêng của bước được lưu ở "name", để trống thì bỏ', () {
      const steps = [
        TimerStep.focus(Duration(minutes: 30), label: 'Reading'),
        TimerStep.rest(Duration(minutes: 5)),
      ];
      expect(
        encodeSteps(steps),
        '[{"type":"focus","seconds":1800,"name":"Reading"},'
        '{"type":"rest","seconds":300}]',
      );
      expect(decodeSteps(encodeSteps(steps)), steps);
      expect(
        decodeSteps('[{"type":"rest","seconds":60,"name":"  "}]').single.label,
        isNull,
      );
      expect(steps.first.displayName, 'Reading');
      expect(steps.last.displayName, 'Break');
    });

    test('bước vô hạn mã hoá kèm "infinite": true', () {
      const steps = [TimerStep.infinite(TimerPhase.focus)];
      expect(
        encodeSteps(steps),
        '[{"type":"focus","seconds":0,"infinite":true}]',
      );
      expect(decodeSteps(encodeSteps(steps)), steps);
      expect(
        encodeSteps(steps),
        '[{"type":"focus","seconds":3000,"sound":"bell"},'
        '{"type":"rest","seconds":600}]',
      );
    });

    test('JSON sai dạng thì ném FormatException', () {
      expect(() => decodeSteps('{}'), throwsFormatException);
      expect(
        () => decodeSteps('[{"type":"nap","seconds":1}]'),
        throwsFormatException,
      );
      expect(() => decodeSteps('[{"type":"focus"}]'), throwsFormatException);
    });
  });

  test('cột day được lưu đúng', () async {
    await record(DateTime(2026, 3, 7, 23, 59, 59));
    final row = await db.select(db.completedSessions).getSingle();
    expect(row.day, '2026-03-07');
    expect(row.focusSeconds, 1500);
  });
}
