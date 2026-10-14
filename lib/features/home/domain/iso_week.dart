/// Tuần theo chuẩn ISO 8601: tuần bắt đầu thứ Hai, tuần 1 là tuần chứa thứ
/// Năm đầu tiên của năm. Vì vậy vài ngày đầu/cuối năm có thể thuộc tuần của
/// năm liền kề ([year] là năm của tuần, không phải năm của [date]).
typedef IsoWeek = ({int year, int week});

IsoWeek isoWeekOf(DateTime date) {
  // Dùng UTC để không lệch vì giờ mùa hè.
  final day = DateTime.utc(date.year, date.month, date.day);
  // Thứ Năm của cùng tuần quyết định tuần thuộc năm nào.
  final thursday = day.add(Duration(days: DateTime.thursday - day.weekday));
  final dayOfYear = thursday.difference(DateTime.utc(thursday.year)).inDays;
  return (year: thursday.year, week: dayOfYear ~/ 7 + 1);
}

/// 7 ngày (thứ Hai → Chủ nhật) của tuần chứa [date], theo giờ máy.
List<DateTime> weekDaysOf(DateTime date) {
  final monday = DateTime(date.year, date.month, date.day - (date.weekday - 1));
  return [
    for (var i = 0; i < 7; i++)
      DateTime(monday.year, monday.month, monday.day + i),
  ];
}
