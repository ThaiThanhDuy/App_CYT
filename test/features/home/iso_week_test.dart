import 'package:counting_your_time/features/home/domain/iso_week.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('số tuần ISO 8601 (đối chiếu lịch)', () {
    expect(isoWeekOf(DateTime(2026, 10, 14)), (year: 2026, week: 42));
    expect(isoWeekOf(DateTime(2026, 1, 1)), (year: 2026, week: 1));
    // 1/1/2027 là thứ Sáu → thuộc tuần 53 của năm 2026.
    expect(isoWeekOf(DateTime(2027, 1, 1)), (year: 2026, week: 53));
    // 29/12/2025 là thứ Hai → đã là tuần 1 của năm 2026.
    expect(isoWeekOf(DateTime(2025, 12, 29)), (year: 2026, week: 1));
  });

  test('tuần từ thứ Hai tới Chủ nhật', () {
    final days = weekDaysOf(DateTime(2026, 10, 14)); // thứ Tư
    expect(days.first, DateTime(2026, 10, 12));
    expect(days.last, DateTime(2026, 10, 18));
    expect(days.map((d) => d.weekday), [1, 2, 3, 4, 5, 6, 7]);
  });
}
