import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Ký tự đặt ở vị trí lẻ ô (di chuyển mượt, không nhảy từng ô).
typedef AsciiSprite = ({double x, double y, String char, Color color});

/// Lưới ký tự có màu để vẽ ASCII art.
///
/// Ngoài các ô cố định còn có [rowOffsets] (dịch cả hàng một khoảng lẻ ô,
/// dùng cho tán lá đung đưa) và [sprites] (ký tự ở toạ độ lẻ, dùng cho vật
/// đang rơi/bay) để chuyển động liên tục.
class AsciiGrid {
  AsciiGrid(this.width, this.height)
    : _chars = List.filled(width * height, ' '),
      _colors = List.filled(width * height, null),
      rowOffsets = List.filled(height, 0);

  final int width;
  final int height;
  final List<String> _chars;
  final List<Color?> _colors;

  /// Độ dịch ngang của từng hàng, tính theo ô.
  final List<double> rowOffsets;
  final List<AsciiSprite> sprites = [];

  bool inside(int x, int y) => x >= 0 && y >= 0 && x < width && y < height;

  void put(int x, int y, String ch, Color color) {
    if (!inside(x, y) || color.a <= 0.01) return;
    _chars[y * width + x] = ch;
    _colors[y * width + x] = color;
  }

  /// Viết chuỗi [s] bắt đầu ở ([x], [y]); khoảng trắng trong chuỗi bỏ qua.
  void text(int x, int y, String s, Color color) {
    for (var i = 0; i < s.length; i++) {
      if (s[i] != ' ') put(x + i, y, s[i], color);
    }
  }

  void sprite(double x, double y, String ch, Color color) {
    if (color.a > 0.01) sprites.add((x: x, y: y, char: ch, color: color));
  }

  /// Khoá của một hàng (ký tự + màu) để tái dùng bản đã dàn trang.
  String rowKey(int y) {
    final b = StringBuffer();
    for (var x = 0; x < width; x++) {
      b.write(_chars[y * width + x]);
      b.write(_colors[y * width + x]?.toARGB32() ?? 0);
      b.write(',');
    }
    return b.toString();
  }

  /// Một hàng thành TextSpan, gom các ký tự liền nhau cùng màu.
  TextSpan rowSpan(int y, TextStyle base) {
    final spans = <TextSpan>[];
    var x = 0;
    while (x < width) {
      final color = _colors[y * width + x];
      final run = StringBuffer();
      while (x < width && _colors[y * width + x] == color) {
        run.write(_chars[y * width + x]);
        x++;
      }
      spans.add(
        TextSpan(
          text: run.toString(),
          style: TextStyle(color: color ?? Colors.transparent),
        ),
      );
    }
    return TextSpan(style: base, children: spans);
  }
}

const _asciiStyle = TextStyle(
  fontFamily: 'monospace',
  fontFamilyFallback: [
    'DejaVu Sans Mono',
    'Noto Sans Mono',
    'Roboto Mono',
    'Menlo',
    'Courier New',
    'Courier',
  ],
  fontSize: 16,
  height: 1.0,
  fontWeight: FontWeight.w700,
  letterSpacing: 0,
);

/// Lưu sẵn các hàng / ký tự đã dàn trang để vẽ 60 khung/giây mà nhẹ máy:
/// khung chỉ dịch chỗ thì không phải dàn trang lại.
class _GlyphCache {
  final _rows = <String, TextPainter>{};
  final _glyphs = <String, TextPainter>{};
  Size? _cell;

  TextPainter _layout(TextSpan span) =>
      TextPainter(text: span, textDirection: TextDirection.ltr)..layout();

  Size cell() => _cell ??= () {
    final m = _layout(const TextSpan(text: 'M', style: _asciiStyle));
    return Size(m.width, m.height);
  }();

  TextPainter row(AsciiGrid g, int y) {
    if (_rows.length > 600) _clear(_rows);
    return _rows.putIfAbsent(
      g.rowKey(y),
      () => _layout(g.rowSpan(y, _asciiStyle)),
    );
  }

  TextPainter glyph(String ch, Color color) {
    if (_glyphs.length > 300) _clear(_glyphs);
    return _glyphs.putIfAbsent(
      '$ch${color.toARGB32()}',
      () => _layout(
        TextSpan(
          text: ch,
          style: _asciiStyle.copyWith(color: color),
        ),
      ),
    );
  }

  void _clear(Map<String, TextPainter> map) {
    for (final p in map.values) {
      p.dispose();
    }
    map.clear();
  }

  void dispose() {
    _clear(_rows);
    _clear(_glyphs);
  }
}

/// Hiển thị [grid] bằng font đơn cách, phóng to vừa khung (giữ tỉ lệ).
class AsciiArt extends StatefulWidget {
  const AsciiArt({super.key, required this.grid});

  final AsciiGrid grid;

  @override
  State<AsciiArt> createState() => _AsciiArtState();
}

class _AsciiArtState extends State<AsciiArt> {
  final _cache = _GlyphCache();

  @override
  void dispose() {
    _cache.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.infinite,
    painter: _AsciiPainter(widget.grid, _cache),
  );
}

class _AsciiPainter extends CustomPainter {
  _AsciiPainter(this.grid, this.cache);

  final AsciiGrid grid;
  final _GlyphCache cache;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = cache.cell();
    final w = grid.width * cell.width;
    final h = grid.height * cell.height;
    final scale = math.min(size.width / w, size.height / h);
    canvas.save();
    canvas.translate(
      (size.width - w * scale) / 2,
      (size.height - h * scale) / 2,
    );
    canvas.scale(scale);
    for (var y = 0; y < grid.height; y++) {
      cache
          .row(grid, y)
          .paint(
            canvas,
            Offset(grid.rowOffsets[y] * cell.width, y * cell.height),
          );
    }
    for (final s in grid.sprites) {
      cache
          .glyph(s.char, s.color)
          .paint(canvas, Offset(s.x * cell.width, s.y * cell.height));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_AsciiPainter old) => !identical(old.grid, grid);
}
