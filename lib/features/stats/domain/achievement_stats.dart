import '../../../data/session_repository.dart';

/// Số liệu nhanh cho bảng thành tựu.
typedef AchievementStats = ({int today, int streak, int total});

/// Tính từ bảng đếm theo ngày ("yyyy-MM-dd" → số phiên).
///
/// [streak]: số ngày liên tiếp có ít nhất 1 phiên, tính lùi từ hôm nay;
/// hôm nay chưa có phiên thì tính từ hôm qua (chuỗi chưa bị đứt).
AchievementStats computeAchievementStats(
  Map<String, int> counts,
  DateTime today,
) {
  int countOn(int daysAgo) =>
      counts[dayKey(DateTime(today.year, today.month, today.day - daysAgo))] ??
      0;

  final start = countOn(0) > 0 ? 0 : 1;
  var streak = 0;
  while (countOn(start + streak) > 0) {
    streak++;
  }
  return (
    today: countOn(0),
    streak: streak,
    total: counts.values.fold(0, (a, b) => a + b),
  );
}
