/// Định dạng thời gian còn lại thành "MM:SS".
///
/// Làm tròn lên theo giây (giống đồng hồ đếm ngược thật: còn 0.3s vẫn hiện
/// 00:01, chỉ về 00:00 đúng lúc hết giờ). Giới hạn trong 00:00 → 99:59.
String formatMmSs(Duration remaining) {
  final micros = remaining.inMicroseconds;
  if (micros <= 0) return '00:00';
  var seconds =
      (micros + Duration.microsecondsPerSecond - 1) ~/
      Duration.microsecondsPerSecond;
  const maxSeconds = 99 * 60 + 59;
  if (seconds > maxSeconds) seconds = maxSeconds;
  final mm = (seconds ~/ 60).toString().padLeft(2, '0');
  final ss = (seconds % 60).toString().padLeft(2, '0');
  return '$mm:$ss';
}

/// Thời gian đã chạy (đếm lên), làm tròn xuống theo giây:
/// "MM:SS", hoặc "H:MM:SS" khi từ 1 giờ trở lên.
String formatElapsed(Duration elapsed) {
  final total = elapsed.isNegative ? 0 : elapsed.inSeconds;
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final s = total % 60;
  final mmss =
      '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  return h > 0 ? '$h:$mmss' : mmss;
}
