import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../timer/application/timer_providers.dart';
import '../domain/time_quotes.dart';

/// Câu trích dẫn đang hiển thị ở đầu màn chính; tự đổi đúng mốc :00 / :30.
final timeQuoteProvider = NotifierProvider<TimeQuoteNotifier, TimeQuote>(
  TimeQuoteNotifier.new,
);

class TimeQuoteNotifier extends Notifier<TimeQuote> {
  Timer? _timer;

  @override
  TimeQuote build() {
    ref.onDispose(() => _timer?.cancel());
    return _scheduleNext();
  }

  TimeQuote _scheduleNext() {
    final now = ref.read(wallClockProvider).now();
    _timer?.cancel();
    // +1s để chắc chắn đã sang khung mới.
    _timer = Timer(
      nextQuoteChange(now).difference(now) + const Duration(seconds: 1),
      () => state = _scheduleNext(),
    );
    return quoteAt(now);
  }
}
