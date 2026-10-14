/// Các kiểu nhân bản một block sang ngày khác.
enum DuplicateMode {
  anotherDay,
  restOfWeek,
  sameWeekday,
  restOfMonth,
  weekdays,
}

/// Các ngày sẽ nhận bản sao của block ngày [from] (không gồm chính [from]).
/// [weeks]: số tuần cho [DuplicateMode.sameWeekday] / [DuplicateMode.weekdays];
/// [date]: ngày đích cho [DuplicateMode.anotherDay].
List<DateTime> duplicateDays(
  DuplicateMode mode,
  DateTime from, {
  int weeks = 4,
  DateTime? date,
}) {
  final start = DateTime(from.year, from.month, from.day);
  // Cộng ngày theo lịch (không cộng 24h) để không lệch vì giờ mùa hè.
  DateTime plus(int days) =>
      DateTime(start.year, start.month, start.day + days);
  switch (mode) {
    case DuplicateMode.anotherDay:
      if (date == null) return const [];
      final d = DateTime(date.year, date.month, date.day);
      return d == start ? const [] : [d];
    case DuplicateMode.restOfWeek:
      return [for (var i = 1; i <= 7 - start.weekday; i++) plus(i)];
    case DuplicateMode.sameWeekday:
      return [for (var w = 1; w <= weeks; w++) plus(7 * w)];
    case DuplicateMode.restOfMonth:
      final lastDay = DateTime(start.year, start.month + 1, 0).day;
      return [for (var i = 1; i <= lastDay - start.day; i++) plus(i)];
    case DuplicateMode.weekdays:
      return [
        for (var i = 1; i <= 7 * weeks; i++)
          if (plus(i).weekday <= DateTime.friday) plus(i),
      ];
  }
}
