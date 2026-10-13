import 'package:counting_your_time/features/stats/domain/achievement_stats.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final today = DateTime(2026, 3, 10);

  test('không có dữ liệu', () {
    expect(computeAchievementStats({}, today), (today: 0, streak: 0, total: 0));
  });

  test('chuỗi tính cả hôm nay', () {
    final s = computeAchievementStats({
      '2026-03-10': 2,
      '2026-03-09': 1,
      '2026-03-08': 4,
      '2026-03-06': 1, // đứt ở ngày 07
    }, today);
    expect(s, (today: 2, streak: 3, total: 8));
  });

  test('hôm nay chưa có phiên thì chuỗi tính từ hôm qua', () {
    final s = computeAchievementStats({
      '2026-03-09': 1,
      '2026-03-08': 1,
    }, today);
    expect(s.streak, 2);
    expect(s.today, 0);
  });

  test('chuỗi đi qua ranh giới tháng', () {
    final s = computeAchievementStats({
      '2026-03-01': 1,
      '2026-02-28': 1,
      '2026-02-27': 1,
    }, DateTime(2026, 3, 1));
    expect(s.streak, 3);
  });
}
