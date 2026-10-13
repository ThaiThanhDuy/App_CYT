import 'package:counting_your_time/features/timer/domain/time_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('định dạng MM:SS', () {
    expect(formatMmSs(const Duration(minutes: 25)), '25:00');
    expect(formatMmSs(const Duration(minutes: 4, seconds: 7)), '04:07');
  });

  test('làm tròn lên theo giây, chỉ về 00:00 khi hết giờ', () {
    expect(formatMmSs(const Duration(milliseconds: 300)), '00:01');
    expect(formatMmSs(const Duration(seconds: 59, milliseconds: 200)), '01:00');
    expect(formatMmSs(Duration.zero), '00:00');
  });

  test('giới hạn 00:00 → 99:59', () {
    expect(formatMmSs(const Duration(seconds: -5)), '00:00');
    expect(formatMmSs(const Duration(hours: 3)), '99:59');
  });
}
