import 'package:flutter/foundation.dart';

/// Một block công việc trong lịch: tên, ngày, giờ bắt đầu – kết thúc
/// (phút từ 00:00), và session gắn kèm (tuỳ chọn).
@immutable
class TaskBlock {
  const TaskBlock({
    this.id,
    required this.title,
    required this.day,
    required this.startMinute,
    required this.endMinute,
    this.presetId,
    this.color,
  });

  final int? id;
  final String title;

  /// Ngày (00:00 giờ máy).
  final DateTime day;
  final int startMinute;
  final int endMinute;
  final int? presetId;

  /// Màu block (ARGB); null = xám mặc định.
  final int? color;

  DateTime get start => day.add(Duration(minutes: startMinute));
  DateTime get end => day.add(Duration(minutes: endMinute));

  /// [time] nằm trong block (tính cả lúc bắt đầu, không tính lúc kết thúc).
  bool contains(DateTime time) => !time.isBefore(start) && time.isBefore(end);

  TaskBlock copyWith({
    String? title,
    DateTime? day,
    int? startMinute,
    int? endMinute,
    int? Function()? presetId,
    int? Function()? color,
  }) => TaskBlock(
    id: id,
    title: title ?? this.title,
    day: day ?? this.day,
    startMinute: startMinute ?? this.startMinute,
    endMinute: endMinute ?? this.endMinute,
    presetId: presetId == null ? this.presetId : presetId(),
    color: color == null ? this.color : color(),
  );

  @override
  bool operator ==(Object other) =>
      other is TaskBlock &&
      other.id == id &&
      other.title == title &&
      other.day == day &&
      other.startMinute == startMinute &&
      other.endMinute == endMinute &&
      other.presetId == presetId &&
      other.color == color;

  @override
  int get hashCode =>
      Object.hash(id, title, day, startMinute, endMinute, presetId, color);
}

/// "09:05" từ số phút trong ngày.
String formatMinuteOfDay(int minutes) {
  final h = (minutes ~/ 60).toString().padLeft(2, '0');
  final m = (minutes % 60).toString().padLeft(2, '0');
  return '$h:$m';
}
