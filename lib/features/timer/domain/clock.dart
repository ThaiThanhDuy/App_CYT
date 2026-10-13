/// Nguồn thời gian, inject vào engine để test được bằng clock giả.
abstract interface class Clock {
  DateTime now();
}

class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now();
}

/// Clock chạy nhanh gấp [factor] lần so với [base], tính từ lúc tạo.
///
/// Dùng cho chế độ tua nhanh khi debug (1 giây thật = 1 phút).
/// Lưu ý: thời điểm trả về lệch dần về tương lai, nên không dùng làm
/// timestamp lưu DB.
class ScaledClock implements Clock {
  ScaledClock(this.base, this.factor) : _anchor = base.now();

  final Clock base;
  final double factor;
  final DateTime _anchor;

  @override
  DateTime now() => _anchor.add(base.now().difference(_anchor) * factor);
}
