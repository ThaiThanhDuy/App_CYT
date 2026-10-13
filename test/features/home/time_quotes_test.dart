import 'package:counting_your_time/features/home/domain/time_quotes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final n = timeQuotes.length;

  test('mỗi vòng hiện đủ mọi câu đúng một lần', () {
    for (var cycle = 0; cycle < 5; cycle++) {
      final seen = {
        for (var w = cycle * n; w < (cycle + 1) * n; w++)
          quoteIndexForWindow(w),
      };
      expect(seen.length, n, reason: 'vòng $cycle');
    }
  });

  test('hai khung 30 phút liền nhau không trùng câu', () {
    for (var w = 1; w < n * 50; w++) {
      expect(
        quoteIndexForWindow(w),
        isNot(quoteIndexForWindow(w - 1)),
        reason: 'khung $w',
      );
    }
  });

  test('cùng khung 30 phút thì cùng câu, đổi đúng mốc :00 / :30', () {
    final a = DateTime(2026, 10, 13, 9, 0);
    expect(quoteAt(a), quoteAt(DateTime(2026, 10, 13, 9, 29, 59)));
    expect(quoteWindowOf(DateTime(2026, 10, 13, 9, 30)), quoteWindowOf(a) + 1);
    expect(
      nextQuoteChange(DateTime(2026, 10, 13, 9, 12)),
      DateTime(2026, 10, 13, 9, 30),
    );
    expect(
      nextQuoteChange(DateTime(2026, 10, 13, 9, 45)),
      DateTime(2026, 10, 13, 10, 0),
    );
  });
}
