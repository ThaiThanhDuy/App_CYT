import 'package:counting_your_time/features/timer/domain/clock.dart';
import 'package:counting_your_time/features/timer/domain/timer_engine.dart';
import 'package:counting_your_time/features/timer/domain/timer_phase.dart';
import 'package:counting_your_time/features/timer/domain/timer_plan.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_clock.dart';

const _min = Duration(minutes: 1);

void main() {
  late FakeClock clock;
  late TimerEngine engine;
  late List<TimerEvent> events;

  // 25/5 × 2 → 4 bước.
  const plan = TimerPlan(
    name: 'test',
    steps: [
      TimerStep.focus(Duration(minutes: 25)),
      TimerStep.rest(Duration(minutes: 5)),
    ],
    repeat: 2,
  );

  setUp(() {
    clock = FakeClock();
    engine = TimerEngine(plan: plan, clock: clock);
    events = [];
    engine.events.listen(events.add);
  });

  tearDown(() => engine.dispose());

  List<StepCompleted> completed() => events.whereType<StepCompleted>().toList();

  test('ban đầu ở trạng thái idle, còn đủ 25 phút', () {
    final s = engine.snapshot;
    expect(s.status, TimerStatus.idle);
    expect(s.index, 0);
    expect(s.phase, TimerPhase.focus);
    expect(s.remaining, _min * 25);
    expect(s.round, 1);
    expect(s.totalRounds, 2);
  });

  test('remaining = endAt - now', () {
    engine.start();
    clock.advance(_min * 10);
    expect(engine.snapshot.remaining, _min * 15);
    clock.advance(const Duration(seconds: 30));
    expect(engine.snapshot.display, '14:30');
  });

  test('tạm dừng thì thời gian không trôi, chạy tiếp từ chỗ dừng', () {
    engine.start();
    clock.advance(_min * 10);
    engine.pause();
    clock.advance(const Duration(hours: 3));
    expect(engine.snapshot.status, TimerStatus.paused);
    expect(engine.snapshot.remaining, _min * 15);

    engine.start();
    clock.advance(_min * 15);
    final s = engine.snapshot;
    expect(s.index, 1);
    expect(s.phase, TimerPhase.rest);
    expect(s.status, TimerStatus.running);
    expect(s.remaining, _min * 5);
  });

  test(
    'hết giờ đúng tại endAt thì phát StepCompleted với mốc thời gian đúng',
    () {
      final t0 = clock.now();
      engine.start();
      clock.advance(_min * 25 - const Duration(milliseconds: 1));
      engine.tick();
      expect(completed(), isEmpty);

      clock.advance(const Duration(milliseconds: 1));
      engine.tick();
      final done = completed().single;
      expect(done.index, 0);
      expect(done.step.phase, TimerPhase.focus);
      expect(done.startedAt, t0);
      expect(done.endedAt, t0.add(_min * 25));
    },
  );

  test('app bị treo lâu: chạy bù toàn bộ chuỗi với mốc chính xác', () {
    final t0 = clock.now();
    engine.start();
    clock.advance(const Duration(hours: 5)); // tổng chuỗi chỉ 60 phút
    final s = engine.snapshot;

    expect(s.status, TimerStatus.finished);
    expect(s.remaining, Duration.zero);
    final done = completed();
    expect(done.map((e) => e.index), [0, 1, 2, 3]);
    expect(done.map((e) => e.endedAt), [
      t0.add(_min * 25),
      t0.add(_min * 30),
      t0.add(_min * 55),
      t0.add(_min * 60),
    ]);
    // Bước sau bắt đầu đúng lúc bước trước kết thúc.
    for (var i = 1; i < done.length; i++) {
      expect(done[i].startedAt, done[i - 1].endedAt);
    }
    expect(events.last, isA<PlanFinished>());
    expect((events.last as PlanFinished).at, t0.add(_min * 60));
  });

  test('bỏ qua focus không tính là hoàn thành, bước nghỉ chạy luôn', () {
    engine.start();
    clock.advance(_min * 20);
    engine.skip();

    expect(completed(), isEmpty);
    expect(events.single, isA<StepSkipped>());
    final s = engine.snapshot;
    expect(s.phase, TimerPhase.rest);
    expect(s.status, TimerStatus.running);
    expect(s.remaining, _min * 5);
  });

  test('bỏ qua khi đang tạm dừng thì bước mới vẫn dừng, đủ thời lượng', () {
    engine.start();
    clock.advance(_min * 3);
    engine.pause();
    engine.skip();
    clock.advance(_min * 30);

    final s = engine.snapshot;
    expect(s.status, TimerStatus.paused);
    expect(s.index, 1);
    expect(s.remaining, _min * 5);
  });

  test('bỏ qua bước cuối thì kết thúc chuỗi', () {
    for (var i = 0; i < plan.length; i++) {
      engine.skip();
    }
    expect(engine.snapshot.status, TimerStatus.finished);
    expect(events.whereType<StepSkipped>().length, 4);
    expect(events.last, isA<PlanFinished>());
    expect(completed(), isEmpty);
  });

  test('huỷ giữa chừng quay về đầu, không tính phiên', () {
    engine.start();
    clock.advance(_min * 24);
    engine.reset();
    clock.advance(_min * 10);

    final s = engine.snapshot;
    expect(s.status, TimerStatus.idle);
    expect(s.index, 0);
    expect(s.remaining, _min * 25);
    expect(events, isEmpty);
  });

  test('start khi đã xong thì chạy lại từ đầu', () {
    engine.start();
    clock.advance(const Duration(hours: 2));
    expect(engine.status, TimerStatus.finished);

    engine.start();
    final s = engine.snapshot;
    expect(s.status, TimerStatus.running);
    expect(s.index, 0);
    expect(s.remaining, _min * 25);
  });

  test('vòng lặp được đánh số đúng', () {
    engine.skip();
    engine.skip();
    final s = engine.snapshot;
    expect(s.index, 2);
    expect(s.phase, TimerPhase.focus);
    expect(s.round, 2);
  });

  test('plan rỗng bị từ chối', () {
    expect(
      () => TimerEngine(
        plan: const TimerPlan(name: 'x', steps: []),
        clock: clock,
      ),
      throwsArgumentError,
    );
  });

  test('ScaledClock: 1 giây thật = 1 phút', () {
    final base = FakeClock();
    final scaled = ScaledClock(base, 60);
    final start = scaled.now();
    base.advance(const Duration(seconds: 1));
    expect(scaled.now().difference(start), _min);

    final fastEngine = TimerEngine(plan: plan, clock: scaled)..start();
    base.advance(const Duration(seconds: 25));
    expect(fastEngine.snapshot.phase, TimerPhase.rest);
    fastEngine.dispose();
  });

  test('10% thời gian cuối của bước là "sắp đổi pha" (đèn vàng)', () {
    // Focus 25 phút → 2,5 phút cuối.
    expect(engine.snapshot.isEnding, isFalse); // chưa bắt đầu
    engine.start();
    clock.advance(const Duration(minutes: 22, seconds: 29));
    expect(engine.snapshot.isEnding, isFalse);
    clock.advance(const Duration(seconds: 1)); // còn đúng 2:30
    expect(engine.snapshot.isEnding, isTrue);
    engine.pause();
    expect(engine.snapshot.isEnding, isTrue); // tạm dừng vẫn vàng
    engine.start();
    clock.advance(const Duration(minutes: 2, seconds: 30));
    // Sang bước nghỉ 5 phút → hết vàng.
    expect(engine.snapshot.phase, TimerPhase.rest);
    expect(engine.snapshot.isEnding, isFalse);
    clock.advance(const Duration(minutes: 4, seconds: 30)); // còn 30 giây
    expect(engine.snapshot.isEnding, isTrue);
  });

  group('bước vô hạn', () {
    // ∞ tập trung → nghỉ 5 phút.
    const infinitePlan = TimerPlan(
      name: 'deep',
      steps: [
        TimerStep.infinite(TimerPhase.focus),
        TimerStep.rest(Duration(minutes: 5)),
      ],
    );
    late TimerEngine inf;
    late List<TimerEvent> infEvents;

    setUp(() {
      inf = TimerEngine(plan: infinitePlan, clock: clock);
      infEvents = [];
      inf.events.listen(infEvents.add);
    });

    tearDown(() => inf.dispose());

    test('không bao giờ tự hết giờ, đếm thời gian đã chạy', () {
      inf.start();
      clock.advance(const Duration(hours: 10));
      final s = inf.snapshot;
      expect(s.status, TimerStatus.running);
      expect(s.index, 0);
      expect(s.isInfinite, isTrue);
      expect(s.remaining, Duration.zero);
      expect(s.elapsed, const Duration(hours: 10));
      expect(infEvents, isEmpty);
    });

    test('tạm dừng không tính vào thời gian đã chạy', () {
      inf.start();
      clock.advance(_min * 10);
      inf.pause();
      clock.advance(_min * 30);
      expect(inf.snapshot.elapsed, _min * 10);
      inf.start();
      clock.advance(_min * 5);
      expect(inf.snapshot.elapsed, _min * 15);
    });

    test('Xong: phát StepCompleted với thời gian thực chạy, sang bước sau', () {
      final t0 = clock.now();
      inf.start();
      clock.advance(_min * 12);
      inf.pause();
      clock.advance(_min * 3);
      inf.finishInfinite();

      final done = infEvents.whereType<StepCompleted>().single;
      expect(done.step.infinite, isTrue);
      expect(done.startedAt, t0);
      expect(done.endedAt, t0.add(_min * 15));
      expect(done.elapsed, _min * 12);
      final s = inf.snapshot;
      expect(s.index, 1);
      expect(s.phase, TimerPhase.rest);
      // Đang tạm dừng lúc bấm Xong → bước sau cũng dừng, đủ thời lượng.
      expect(s.status, TimerStatus.paused);
      expect(s.remaining, _min * 5);
    });

    test('Xong không có tác dụng khi chưa bắt đầu hoặc bước có giờ', () {
      inf.finishInfinite();
      expect(infEvents, isEmpty);
      engine.start();
      engine.finishInfinite();
      expect(events, isEmpty);
    });

    test('chạy bù dừng lại ở bước vô hạn', () {
      const p = TimerPlan(
        name: 'x',
        steps: [
          TimerStep.focus(Duration(minutes: 25)),
          TimerStep.infinite(TimerPhase.rest),
        ],
      );
      final e = TimerEngine(plan: p, clock: clock);
      e.start();
      clock.advance(const Duration(hours: 3));
      final s = e.snapshot;
      expect(s.index, 1);
      expect(s.status, TimerStatus.running);
      // Bước vô hạn bắt đầu đúng lúc bước trước hết giờ.
      expect(s.elapsed, const Duration(hours: 3) - _min * 25);
      expect(e.upcomingStepEnds(), isEmpty);
      e.dispose();
    });

    test('mốc hẹn trước dừng trước bước vô hạn', () {
      const p = TimerPlan(
        name: 'x',
        steps: [
          TimerStep.focus(Duration(minutes: 25)),
          TimerStep.infinite(TimerPhase.rest),
        ],
        repeat: 2,
      );
      final e = TimerEngine(plan: p, clock: clock)..start();
      final ends = e.upcomingStepEnds();
      expect(ends, hasLength(1));
      expect(ends.single.next!.infinite, isTrue);
      e.dispose();
    });
  });
}
