// Logic hình học (không phụ thuộc Canvas) cho chữ số LED 7 đoạn dạng thanh liền.
//
// Mỗi chữ số dựng trên một "khung xương" 6 điểm, mỗi đoạn là một thanh nối
// hai điểm, dày [SevenSegGeometry.thickness], hai đầu vát nhọn:
//
//   p0 ──a── p1
//   │         │
//   f         b
//   │         │
//   p2 ──g── p3
//   │         │
//   e         c
//   │         │
//   p4 ──d── p5
//
// Toạ độ tính theo đơn vị trừu tượng (chiều dài đoạn = 1); painter tự co giãn.

import 'dart:math' as math;
import 'dart:ui';

/// 7 đoạn chuẩn: a (trên), b (phải trên), c (phải dưới), d (dưới),
/// e (trái dưới), f (trái trên), g (giữa).
enum Segment { a, b, c, d, e, f, g }

/// Đoạn nào sáng cho từng chữ số 0–9.
const Map<int, Set<Segment>> digitSegments = {
  0: {Segment.a, Segment.b, Segment.c, Segment.d, Segment.e, Segment.f},
  1: {Segment.b, Segment.c},
  2: {Segment.a, Segment.b, Segment.g, Segment.e, Segment.d},
  3: {Segment.a, Segment.b, Segment.g, Segment.c, Segment.d},
  4: {Segment.f, Segment.g, Segment.b, Segment.c},
  5: {Segment.a, Segment.f, Segment.g, Segment.c, Segment.d},
  6: {Segment.a, Segment.f, Segment.g, Segment.e, Segment.c, Segment.d},
  7: {Segment.a, Segment.b, Segment.c},
  8: {
    Segment.a,
    Segment.b,
    Segment.c,
    Segment.d,
    Segment.e,
    Segment.f,
    Segment.g,
  },
  9: {Segment.a, Segment.b, Segment.c, Segment.d, Segment.f, Segment.g},
};

/// Kiểu đầu thanh: vát nhọn (cổ điển) hoặc chữ nhật.
enum LedSegmentShape { beveled, rect }

/// Cách "đổ" mỗi đoạn:
/// - [solid]: thanh liền.
/// - [dots]: 2 hàng chấm LED tròn (giống đèn đếm ngược ngã tư).
/// - [scanlines]: nhiều nét ngang mảnh (kiểu màn hình máy tính retro).
enum LedDigitStyle {
  solid('Solid'),
  dots('LED dots'),
  scanlines('Scanlines');

  const LedDigitStyle(this.label);
  final String label;
}

/// Kích thước chuẩn (đơn vị trừu tượng).
abstract final class SevenSegGeometry {
  static const double length = 1.0;
  static const double thickness = 0.2;

  /// Khe hở giữa hai đoạn kề nhau.
  static const double gap = 0.035;
  static const double digitWidth = length + thickness;
  static const double height = 2 * length + thickness;
  static const double colonWidth = thickness;

  /// Khoảng cách giữa các ký tự.
  static const double spacing = 0.32;

  /// Chiều rộng cần để vẽ [text] (chỉ gồm chữ số và ':').
  static double widthFor(String text) {
    var w = 0.0;
    for (var i = 0; i < text.length; i++) {
      w += text[i] == ':' ? colonWidth : digitWidth;
      if (i < text.length - 1) w += spacing;
    }
    return w;
  }
}

/// Khung hình đã dựng: mỗi phần tử là một đa giác (danh sách đỉnh).
class SevenSegFrame {
  const SevenSegFrame({
    required this.on,
    required this.off,
    required this.width,
  });

  final List<List<Offset>> on;
  final List<List<Offset>> off;
  final double width;
  double get height => SevenSegGeometry.height;
}

/// Đa giác của đoạn [segment] cho chữ số bắt đầu tại [originX].
List<Offset> segmentPolygon(
  Segment segment, {
  double originX = 0,
  LedSegmentShape shape = LedSegmentShape.beveled,
}) {
  final (start, end) = segmentAxis(segment, originX: originX);
  return _bar(start, end, shape);
}

/// Trục của đoạn trên khung xương: (điểm đầu, điểm cuối), chưa trừ khe hở.
(Offset, Offset) segmentAxis(Segment segment, {double originX = 0}) {
  const t = SevenSegGeometry.thickness;
  const l = SevenSegGeometry.length;
  const h = t / 2;
  // Các điểm khung xương.
  final left = originX + h, right = originX + h + l;
  const top = h, mid = h + l, bottom = h + 2 * l;

  return switch (segment) {
    Segment.a => (Offset(left, top), Offset(right, top)),
    Segment.g => (Offset(left, mid), Offset(right, mid)),
    Segment.d => (Offset(left, bottom), Offset(right, bottom)),
    Segment.f => (Offset(left, top), Offset(left, mid)),
    Segment.e => (Offset(left, mid), Offset(left, bottom)),
    Segment.b => (Offset(right, top), Offset(right, mid)),
    Segment.c => (Offset(right, mid), Offset(right, bottom)),
  };
}

/// Khoảng cách giữa hai chấm LED: 2 hàng chấm vừa khít độ dày đoạn.
const double ledDotPitch = SevenSegGeometry.thickness / 2;

// Kiểu chấm LED dùng một lưới chung cho mỗi chữ số để chấm luôn cách đều,
// không bao giờ đè nhau ở chỗ hai đoạn gặp nhau:
//
//   cột:  0 1 | 2 … 9 | 10 11        (12 cột × 22 hàng, bước = ledDotPitch)
//   hàng 0-1      [ a ]
//   hàng 2-9  [f]         [b]
//   hàng 10-11    [ g ]
//   hàng 12-19 [e]        [c]
//   hàng 20-21    [ d ]
//
// Ô ở chỗ giao nhau (góc) thuộc về [LedCorner], sáng khi đoạn kề sáng.

/// Số cột / hàng lưới chấm của một chữ số.
const int ledDotCols = 12;
const int ledDotRows = 22;

Offset _latticeDot(double originX, int col, int row) =>
    Offset(originX + ledDotPitch * (col + 0.5), ledDotPitch * (row + 0.5));

/// Tâm các chấm của đoạn [segment] (2 hàng × 8 chấm trên lưới chung).
List<Offset> segmentDots(Segment segment, {double originX = 0}) {
  // (cột đầu, hàng đầu, số cột, số hàng)
  final (c0, r0, cols, rows) = switch (segment) {
    Segment.a => (2, 0, 8, 2),
    Segment.g => (2, 10, 8, 2),
    Segment.d => (2, 20, 8, 2),
    Segment.f => (0, 2, 2, 8),
    Segment.b => (10, 2, 2, 8),
    Segment.e => (0, 12, 2, 8),
    Segment.c => (10, 12, 2, 8),
  };
  return [
    for (var r = r0; r < r0 + rows; r++)
      for (var c = c0; c < c0 + cols; c++) _latticeDot(originX, c, r),
  ];
}

/// Ô giao nhau 2×2 chấm giữa các đoạn.
enum LedCorner { topLeft, topRight, midLeft, midRight, bottomLeft, bottomRight }

/// Các đoạn gặp nhau tại mỗi góc: góc sáng khi một trong số đó sáng.
const Map<LedCorner, Set<Segment>> cornerSegments = {
  LedCorner.topLeft: {Segment.a, Segment.f},
  LedCorner.topRight: {Segment.a, Segment.b},
  LedCorner.midLeft: {Segment.f, Segment.e, Segment.g},
  LedCorner.midRight: {Segment.b, Segment.c, Segment.g},
  LedCorner.bottomLeft: {Segment.e, Segment.d},
  LedCorner.bottomRight: {Segment.c, Segment.d},
};

/// Ô (cột, hàng) của góc khi các đoạn kề trong [lit] đang sáng; [lit] null
/// = mọi ô góc có thể sáng (dùng để vẽ nền chấm mờ).
///
/// - Bốn góc ngoài cùng: chỉ chấm phía trong → góc bo tròn bậc thang 1 chấm.
/// - Hai góc giữa: nét chạy thẳng qua (đoạn trên + dưới cùng sáng) thì đủ
///   2×2; gấp khúc kiểu chữ L (vd. số 4, số 2) chỉ giữ chấm phía trong để
///   bo tròn như góc ngoài; chỉ đoạn g sáng thì giữ cột phía trong.
List<(int, int)> cornerCells(LedCorner corner, {Set<Segment>? lit}) {
  switch (corner) {
    case LedCorner.topLeft:
      return const [(1, 1)];
    case LedCorner.topRight:
      return const [(10, 1)];
    case LedCorner.bottomLeft:
      return const [(1, 20)];
    case LedCorner.bottomRight:
      return const [(10, 20)];
    case LedCorner.midLeft || LedCorner.midRight:
      final left = corner == LedCorner.midLeft;
      final (inner, outer) = left ? (1, 0) : (10, 11);
      final upSeg = left ? Segment.f : Segment.b;
      final downSeg = left ? Segment.e : Segment.c;
      final all = [(outer, 10), (inner, 10), (outer, 11), (inner, 11)];
      if (lit == null) return all;
      final up = lit.contains(upSeg);
      final down = lit.contains(downSeg);
      final side = lit.contains(Segment.g);
      return switch ((up, down, side)) {
        (true, true, _) => all,
        (true, false, _) => [(inner, 10)],
        (false, true, _) => [(inner, 11)],
        (false, false, true) => [(inner, 10), (inner, 11)],
        (false, false, false) => const [],
      };
  }
}

/// Tâm chấm (trên lưới chung) của ô [col], [row] trong chữ số ở [originX].
Offset ledLatticeDot(double originX, int col, int row) =>
    _latticeDot(originX, col, row);

/// Tâm các chấm của ô góc khi các đoạn kề trong [lit] sáng (xem
/// [cornerCells]); [lit] null = mọi chấm góc có thể sáng.
List<Offset> cornerDots(
  LedCorner corner, {
  double originX = 0,
  Set<Segment>? lit,
}) => [
  for (final (c, r) in cornerCells(corner, lit: lit))
    _latticeDot(originX, c, r),
];

/// Mức sáng của từng góc theo mức sáng các đoạn ([levels]): lấy mức lớn
/// nhất của các đoạn kề; không đoạn kề nào sáng thì không có trong kết quả.
Map<LedCorner, double> cornerLevels(Map<Segment, double> levels) {
  final result = <LedCorner, double>{};
  for (final MapEntry(key: corner, value: segs) in cornerSegments.entries) {
    double? best;
    for (final seg in segs) {
      final v = levels[seg];
      if (v != null && (best == null || v > best)) best = v;
    }
    if (best != null) result[corner] = best;
  }
  return result;
}

/// Tâm các chấm của dấu ':' (mỗi ô vuông 2×2 chấm).
List<Offset> colonDots(double originX) => [
  for (final square in colonPolygons(originX))
    for (final dy in const [-0.5, 0.5])
      for (final dx in const [-0.5, 0.5])
        Offset(
              (square[0].dx + square[2].dx) / 2,
              (square[0].dy + square[2].dy) / 2,
            ) +
            Offset(dx, dy) * ledDotPitch,
];

/// Khung hình dạng chấm: tâm các chấm đang bật / tắt.
class LedDotFrame {
  const LedDotFrame({required this.on, required this.off, required this.width});

  final List<Offset> on;
  final List<Offset> off;
  final double width;
  double get height => SevenSegGeometry.height;
}

/// Dựng khung hình dạng chấm cho chuỗi "MM:SS".
LedDotFrame buildDotFrame(String text, {bool colonOn = true}) {
  final on = <Offset>[];
  final off = <Offset>[];
  var x = 0.0;
  for (var i = 0; i < text.length; i++) {
    final ch = text[i];
    if (ch == ':') {
      (colonOn ? on : off).addAll(colonDots(x));
      x += SevenSegGeometry.colonWidth;
    } else {
      final lit = digitSegments[int.parse(ch)]!;
      for (final seg in Segment.values) {
        (lit.contains(seg) ? on : off).addAll(segmentDots(seg, originX: x));
      }
      x += SevenSegGeometry.digitWidth;
    }
    if (i < text.length - 1) x += SevenSegGeometry.spacing;
  }
  return LedDotFrame(on: on, off: off, width: x);
}

/// Thanh nối [start]→[end] (ngang hoặc dọc), đã trừ khe hở hai đầu.
List<Offset> _bar(Offset start, Offset end, LedSegmentShape shape) {
  const h = SevenSegGeometry.thickness / 2;
  const g = SevenSegGeometry.gap;
  final horizontal = start.dy == end.dy;
  // Trục dọc theo thanh (u) và trục vuông góc (v).
  final u = horizontal ? const Offset(1, 0) : const Offset(0, 1);
  final v = horizontal ? const Offset(0, 1) : const Offset(1, 0);
  final s = start + u * g;
  final e = end - u * g;
  return switch (shape) {
    LedSegmentShape.beveled => [
      s,
      s + u * h - v * h,
      e - u * h - v * h,
      e,
      e - u * h + v * h,
      s + u * h + v * h,
    ],
    LedSegmentShape.rect => [
      s + u * h - v * h,
      e - u * h - v * h,
      e - u * h + v * h,
      s + u * h + v * h,
    ],
  };
}

/// Hai ô vuông của dấu ':' bắt đầu tại [originX].
List<List<Offset>> colonPolygons(double originX) {
  const t = SevenSegGeometry.thickness;
  const l = SevenSegGeometry.length;
  return [
    for (final cy in const [t / 2 + l * 0.55, t / 2 + l * 1.45])
      [
        Offset(originX, cy - t / 2),
        Offset(originX + t, cy - t / 2),
        Offset(originX + t, cy + t / 2),
        Offset(originX, cy + t / 2),
      ],
  ];
}

/// Dựng khung hình cho chuỗi dạng "MM:SS".
///
/// [colonOn] = false thì dấu ':' hiển thị như đoạn tắt (dùng để nhấp nháy
/// khi tạm dừng).
SevenSegFrame buildSevenSegFrame(
  String text, {
  bool colonOn = true,
  LedSegmentShape shape = LedSegmentShape.beveled,
}) {
  final on = <List<Offset>>[];
  final off = <List<Offset>>[];
  var x = 0.0;
  for (var i = 0; i < text.length; i++) {
    final ch = text[i];
    if (ch == ':') {
      (colonOn ? on : off).addAll(colonPolygons(x));
      x += SevenSegGeometry.colonWidth;
    } else {
      final lit = digitSegments[int.parse(ch)]!;
      for (final seg in Segment.values) {
        (lit.contains(seg) ? on : off).add(
          segmentPolygon(seg, originX: x, shape: shape),
        );
      }
      x += SevenSegGeometry.digitWidth;
    }
    if (i < text.length - 1) x += SevenSegGeometry.spacing;
  }
  return SevenSegFrame(on: on, off: off, width: x);
}

/// Một ký tự đã dàn trang: chữ số hoặc ':' và toạ độ x bắt đầu.
typedef LedGlyph = ({String char, double originX});

/// Vị trí từng ký tự của chuỗi "MM:SS" theo cùng quy tắc với
/// [buildSevenSegFrame].
List<LedGlyph> layoutGlyphs(String text) {
  final glyphs = <LedGlyph>[];
  var x = 0.0;
  for (var i = 0; i < text.length; i++) {
    final ch = text[i];
    glyphs.add((char: ch, originX: x));
    x += ch == ':' ? SevenSegGeometry.colonWidth : SevenSegGeometry.digitWidth;
    if (i < text.length - 1) x += SevenSegGeometry.spacing;
  }
  return glyphs;
}

/// Đường đi của "con rắn" trong một chữ số: vào ở giữa-trái, đi hết hai
/// vòng của số 8 rồi theo đoạn g ra giữa-phải — đúng chỗ chữ số kế tiếp bắt
/// đầu, nên 4 chữ số nối thành một nét liền.
///
/// Chữ số chẵn (1, 3) đi vòng trên trước, chữ số lẻ (2, 4) là bản lật dọc
/// (vòng dưới trước) để hai chữ số cạnh nhau đối xứng nhau.
const figureEightTopFirst = [
  Segment.f, // giữa-trái → trên-trái
  Segment.a, // → trên-phải
  Segment.b, // → giữa-phải
  Segment.c, // → dưới-phải
  Segment.d, // → dưới-trái
  Segment.e, // → giữa-trái
  Segment.g, // → giữa-phải, sang chữ số kế
];

const figureEightBottomFirst = [
  Segment.e, // giữa-trái → dưới-trái
  Segment.d, // → dưới-phải
  Segment.c, // → giữa-phải
  Segment.b, // → trên-phải
  Segment.a, // → trên-trái
  Segment.f, // → giữa-trái
  Segment.g, // → giữa-phải, sang chữ số kế
];

/// Đường đi của chữ số thứ [digit] (đếm từ 0).
List<Segment> figureEightPathFor(int digit) =>
    digit.isEven ? figureEightTopFirst : figureEightBottomFirst;

/// Số đoạn rắn đi qua trong mỗi chữ số.
const int figureEightSegmentsPerDigit = 7;

/// Kiểu hiệu ứng ∞ cho bước vô hạn.
enum LedInfinityStyle {
  /// Một con rắn chạy lần lượt qua 4 chữ số thành một nét liền.
  chain('Chain'),

  /// Cả 4 chữ số cùng chạy vòng số 8 kín, cùng đoạn cùng lúc.
  sync('Sync');

  const LedInfinityStyle(this.label);
  final String label;
}

/// Vòng số 8 kín (dùng cho kiểu đồng bộ): vòng trên theo chiều kim đồng hồ,
/// cắt qua g, vòng dưới ngược chiều, rồi qua g về lại đầu.
const figureEightLoop = [
  Segment.a,
  Segment.b,
  Segment.g,
  Segment.e,
  Segment.d,
  Segment.c,
  Segment.g,
  Segment.f,
];

/// Độ dài một vòng hiệu ứng (số đoạn) cho [digitCount] chữ số.
int infinityLoopLength(LedInfinityStyle style, int digitCount) =>
    switch (style) {
      LedInfinityStyle.chain => figureEightSegmentsPerDigit * digitCount,
      LedInfinityStyle.sync => figureEightLoop.length,
    };

/// Độ sáng từng đoạn của chữ số thứ [digit] theo kiểu [style].
/// [position] tính theo số đoạn, quay vòng sau [infinityLoopLength].
Map<Segment, double> infinityLevels(
  LedInfinityStyle style,
  double position, {
  int digit = 0,
  int digitCount = 1,
  double tail = 3,
}) => switch (style) {
  LedInfinityStyle.chain => figureEightLevels(
    position,
    digit: digit,
    digitCount: digitCount,
    tail: tail,
  ),
  // Mọi chữ số cùng pha: chỉ phụ thuộc vị trí, không phụ thuộc [digit].
  LedInfinityStyle.sync => _snakeLevels(
    path: figureEightLoop,
    position: position,
    offset: 0,
    total: figureEightLoop.length,
    tail: tail,
  ),
};

/// Độ sáng (0–1] từng đoạn của chữ số thứ [digit] khi một "con rắn" chạy
/// nối tiếp qua [digitCount] chữ số theo [figureEightPathFor]: hết chữ số
/// này mới sang đoạn đầu của chữ số kế tiếp, hết chữ số cuối thì quay về
/// chữ số đầu.
///
/// [position] tính theo số đoạn trên toàn đường đi (có phần lẻ, tự quay
/// vòng sau `7 × digitCount`). Đầu rắn sáng nhất, đuôi dài [tail] đoạn mờ
/// dần (có thể vắt sang chữ số trước); đoạn phía trước sáng dần lên theo phần
/// lẻ để chuyển động mượt.
Map<Segment, double> figureEightLevels(
  double position, {
  int digit = 0,
  int digitCount = 1,
  double tail = 3,
}) => _snakeLevels(
  path: figureEightPathFor(digit),
  position: position,
  offset: digit * figureEightSegmentsPerDigit,
  total: figureEightSegmentsPerDigit * digitCount,
  tail: tail,
);

/// Lõi chung của "con rắn": [path] là các đoạn của một chữ số, nằm ở vị trí
/// [offset] trên toàn đường đi dài [total] đoạn. Đoạn đi qua hai lần (g ở
/// vòng số 8 kín) thì lấy mức sáng lớn hơn.
Map<Segment, double> _snakeLevels({
  required List<Segment> path,
  required double position,
  required int offset,
  required int total,
  required double tail,
}) {
  final head = position % total;
  final levels = <Segment, double>{};
  for (var k = 0; k < path.length; k++) {
    // 0 = đầu rắn, tăng dần về phía đuôi (tính trên toàn đường đi).
    final behind = (head - (offset + k)) % total;
    // behind > total - 1: đoạn ngay trước đầu rắn, đang sáng dần lên.
    final level = behind > total - 1 ? behind - (total - 1) : 1 - behind / tail;
    if (level <= 0) continue;
    final seg = path[k];
    levels[seg] = math.max(levels[seg] ?? 0, level);
  }
  return levels;
}
