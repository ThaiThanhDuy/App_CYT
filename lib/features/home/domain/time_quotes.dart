import 'dart:math' as math;

/// Một câu trích dẫn về thời gian.
typedef TimeQuote = ({String text, String author});

/// Các câu nổi tiếng về thời gian, học tập và làm việc chăm chỉ. Chỉ giữ
/// những câu có nguồn rõ ràng (ghi trong comment), bỏ các câu hay bị gán nhầm
/// tác giả.
const List<TimeQuote> timeQuotes = [
  // Poor Richard's Almanack (1748)
  (text: 'Lost time is never found again.', author: 'Benjamin Franklin'),
  // Advice to a Young Tradesman (1748)
  (text: 'Time is money.', author: 'Benjamin Franklin'),
  // Poor Richard's Almanack (1746)
  (
    text:
        'Dost thou love life? Then do not squander time, '
        "for that's the stuff life is made of.",
    author: 'Benjamin Franklin',
  ),
  // Poor Richard's Almanack
  (text: 'You may delay, but time will not.', author: 'Benjamin Franklin'),
  // Poor Richard's Almanack
  (text: 'One today is worth two tomorrows.', author: 'Benjamin Franklin'),
  // Some Fruits of Solitude (1682)
  (
    text: 'Time is what we want most, but what we use worst.',
    author: 'William Penn',
  ),
  // On the Shortness of Life
  (
    text:
        'It is not that we have a short time to live, '
        'but that we waste a lot of it.',
    author: 'Seneca',
  ),
  // War and Peace
  (
    text: 'The two most powerful warriors are patience and time.',
    author: 'Leo Tolstoy',
  ),
  // Phrynette Married (1912)
  (
    text: 'Time you enjoy wasting is not wasted time.',
    author: 'Marthe Troly-Curtin',
  ),
  // The Screwtape Letters
  (
    text:
        'The future is something which everyone reaches at the rate of '
        'sixty minutes an hour, whatever he does, whoever he is.',
    author: 'C. S. Lewis',
  ),
  // The Marble Faun
  (
    text: 'Time flies over us, but leaves its shadow behind.',
    author: 'Nathaniel Hawthorne',
  ),
  // The Fellowship of the Ring
  (
    text:
        'All we have to decide is what to do with the time '
        'that is given to us.',
    author: 'J. R. R. Tolkien',
  ),
  // The Effective Executive
  (
    text: 'Until we can manage time, we can manage nothing else.',
    author: 'Peter Drucker',
  ),
  // The Merry Wives of Windsor
  (
    text: 'Better three hours too soon than a minute too late.',
    author: 'William Shakespeare',
  ),
  // The Writing Life
  (
    text: 'How we spend our days is, of course, how we spend our lives.',
    author: 'Annie Dillard',
  ),
  (
    text: "The bad news is time flies. The good news is you're the pilot.",
    author: 'Michael Altshuler',
  ),
  (text: 'Either you run the day, or the day runs you.', author: 'Jim Rohn'),
  (
    text: 'The key is in not spending time, but in investing it.',
    author: 'Stephen R. Covey',
  ),
  // Diogenes Laërtius, Lives of the Eminent Philosophers
  (
    text: 'Time is the most valuable thing a man can spend.',
    author: 'Theophrastus',
  ),
  // Lời khuyên quen thuộc, gắn với Franklin
  (
    text: 'Never leave that till tomorrow which you can do today.',
    author: 'Benjamin Franklin',
  ),

  // --- Học tập ---
  // Phát biểu ra mắt Mindset Network (2003)
  (
    text:
        'Education is the most powerful weapon which you can use to '
        'change the world.',
    author: 'Nelson Mandela',
  ),
  // Thư gửi Carl Seelig (1952)
  (
    text: 'I have no special talents. I am only passionately curious.',
    author: 'Albert Einstein',
  ),
  // I Can Read With My Eyes Shut! (1978)
  (
    text:
        'The more that you read, the more things you will know. '
        "The more that you learn, the more places you'll go.",
    author: 'Dr. Seuss',
  ),
  // Diogenes Laërtius, Lives of the Eminent Philosophers, V.18
  (
    text: 'The roots of education are bitter, but the fruit is sweet.',
    author: 'Aristotle',
  ),
  // Politics, V
  (text: 'Well begun is half done.', author: 'Aristotle'),

  // --- Làm việc chăm chỉ ---
  // Harper's Monthly (1932)
  (
    text:
        'Genius is one percent inspiration and ninety-nine percent '
        'perspiration.',
    author: 'Thomas Edison',
  ),
  (
    text:
        'There are no secrets to success. It is the result of preparation, '
        'hard work, and learning from failure.',
    author: 'Colin Powell',
  ),
  (
    text: "Hard work beats talent when talent doesn't work hard.",
    author: 'Tim Notke',
  ),
  // The Story of Philosophy (1926), diễn giải ý của Aristotle
  (
    text:
        'We are what we repeatedly do. Excellence, then, is not an act, '
        'but a habit.',
    author: 'Will Durant',
  ),
  (
    text: 'Success is the sum of small efforts, repeated day in and day out.',
    author: 'Robert Collier',
  ),
  (
    text: "Don't watch the clock; do what it does. Keep going.",
    author: 'Sam Levenson',
  ),
  // Management: Tasks, Responsibilities, Practices (1973)
  (
    text:
        'Plans are only good intentions unless they immediately '
        'degenerate into hard work.',
    author: 'Peter Drucker',
  ),
];

/// Độ dài một khung hiển thị: mỗi khung hiện một câu.
const Duration quoteWindow = Duration(minutes: 30);

/// Số thứ tự khung 30 phút chứa [time] (đếm từ epoch, theo giờ máy để khung
/// đổi đúng lúc :00 và :30).
int quoteWindowOf(DateTime time) {
  final local = time.toLocal();
  final minutes =
      local.millisecondsSinceEpoch ~/ Duration.millisecondsPerMinute +
      local.timeZoneOffset.inMinutes;
  return minutes ~/ quoteWindow.inMinutes;
}

/// Thứ tự xáo trộn của vòng thứ [cycle] (mỗi vòng hiện mỗi câu đúng 1 lần).
List<int> _shuffled(int cycle, int n) =>
    List<int>.generate(n, (i) => i)..shuffle(math.Random(cycle));

/// Câu cho khung [window]: ngẫu nhiên nhưng cố định trong cùng khung (mở lại
/// app vẫn là câu đó). Câu được xáo theo vòng nên mọi câu đều được hiện
/// trước khi lặp lại, và hai khung liền nhau không bao giờ trùng câu.
int quoteIndexForWindow(int window, {int count = 0}) {
  final n = count > 0 ? count : timeQuotes.length;
  if (n < 3) return window % n;
  final cycle = window ~/ n;
  final order = _shuffled(cycle, n);
  // Câu đầu vòng mới trùng câu cuối vòng trước → đổi chỗ hai câu đầu.
  if (order.first == _shuffled(cycle - 1, n).last) {
    order[0] = order[1];
    order[1] = _shuffled(cycle - 1, n).last;
  }
  return order[window % n];
}

/// Câu đang hiển thị lúc [time].
TimeQuote quoteAt(DateTime time) =>
    timeQuotes[quoteIndexForWindow(quoteWindowOf(time))];

/// Thời điểm bắt đầu khung kế tiếp sau [time].
DateTime nextQuoteChange(DateTime time) {
  final local = time.toLocal();
  final minute = local.minute < 30 ? 30 : 60;
  return DateTime(local.year, local.month, local.day, local.hour, minute);
}
