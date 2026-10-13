import 'package:counting_your_time/features/timer/domain/clock.dart';

/// Clock giả: thời gian chỉ trôi khi gọi [advance].
class FakeClock implements Clock {
  FakeClock([DateTime? start]) : _now = start ?? DateTime(2026, 1, 5, 9);

  DateTime _now;

  @override
  DateTime now() => _now;

  void advance(Duration d) => _now = _now.add(d);
}
