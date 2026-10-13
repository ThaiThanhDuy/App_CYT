import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../domain/time_format.dart';
import 'led_segments.dart';

export 'led_segments.dart'
    show LedDigitStyle, LedInfinityStyle, LedSegmentShape;

/// Tuỳ chọn hiển thị của đồng hồ LED. Gói theme (M6) sẽ dựng object này.
@immutable
class LedStyle {
  const LedStyle({
    this.digitStyle = LedDigitStyle.solid,
    this.infinityStyle = LedInfinityStyle.chain,
    this.segmentShape = LedSegmentShape.beveled,
    this.offOpacity = 0.07,
    this.glowStrength = 1.0,
    this.slant = 0.08,
  });

  /// Đổ đoạn bằng nét liền, chấm LED hay sọc ngang.
  final LedDigitStyle digitStyle;

  /// Kiểu hiệu ứng ∞ cho bước vô hạn.
  final LedInfinityStyle infinityStyle;

  /// Kiểu đầu thanh (áp dụng cho nét liền và sọc ngang).
  final LedSegmentShape segmentShape;

  /// Độ sáng của đoạn đang tắt (0–1), mặc định ~7%.
  final double offOpacity;

  /// Hệ số quầng sáng; 0 = tắt glow. Ở light mode glow luôn tắt.
  final double glowStrength;

  /// Độ nghiêng chữ số (tan góc nghiêng), 0 = đứng thẳng.
  final double slant;

  /// Nội suy để đổi theme mượt; kiểu đầu thanh đổi ở giữa chừng.
  static LedStyle lerp(LedStyle a, LedStyle b, double t) => LedStyle(
    digitStyle: t < 0.5 ? a.digitStyle : b.digitStyle,
    infinityStyle: t < 0.5 ? a.infinityStyle : b.infinityStyle,
    segmentShape: t < 0.5 ? a.segmentShape : b.segmentShape,
    offOpacity: lerpDouble(a.offOpacity, b.offOpacity, t)!,
    glowStrength: lerpDouble(a.glowStrength, b.glowStrength, t)!,
    slant: lerpDouble(a.slant, b.slant, t)!,
  );

  LedStyle copyWith({
    LedDigitStyle? digitStyle,
    LedInfinityStyle? infinityStyle,
  }) => LedStyle(
    digitStyle: digitStyle ?? this.digitStyle,
    infinityStyle: infinityStyle ?? this.infinityStyle,
    segmentShape: segmentShape,
    offOpacity: offOpacity,
    glowStrength: glowStrength,
    slant: slant,
  );

  @override
  bool operator ==(Object other) =>
      other is LedStyle &&
      other.digitStyle == digitStyle &&
      other.infinityStyle == infinityStyle &&
      other.segmentShape == segmentShape &&
      other.offOpacity == offOpacity &&
      other.glowStrength == glowStrength &&
      other.slant == slant;

  @override
  int get hashCode => Object.hash(
    digitStyle,
    infinityStyle,
    segmentShape,
    offOpacity,
    glowStrength,
    slant,
  );
}

/// Đồng hồ đếm ngược "MM:SS" dạng LED 7 đoạn. Đổi [color] sẽ chuyển màu mượt.
///
/// [infinite] = true: không hiện số mà chạy hiệu ứng "con rắn" theo hình
/// số 8 (∞ dựng đứng) trên cả 4 chữ số; [animate] = false thì đứng yên
/// (khi tạm dừng).
class LedTimerDisplay extends StatelessWidget {
  const LedTimerDisplay({
    super.key,
    required this.remaining,
    required this.color,
    this.colonOn = true,
    this.style = const LedStyle(),
    this.colorTransition = const Duration(milliseconds: 500),
    this.infinite = false,
    this.animate = true,
  });

  final Duration remaining;
  final Color color;
  final bool colonOn;
  final LedStyle style;
  final Duration colorTransition;
  final bool infinite;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final text = infinite ? '88:88' : formatMmSs(remaining);
    final dark = Theme.of(context).brightness == Brightness.dark;
    // Glow trên nền trắng trông bẩn nên chỉ bật ở dark mode.
    final glow = dark ? style.glowStrength : 0.0;
    return Semantics(
      label: infinite ? 'No time limit' : 'Time remaining $text',
      child: TweenAnimationBuilder<Color?>(
        tween: ColorTween(end: color),
        duration: colorTransition,
        curve: Curves.easeInOut,
        builder: (context, animatedColor, _) {
          LedTimerPainter painter(double? phase) => LedTimerPainter(
            text: text,
            color: animatedColor ?? color,
            colonOn: colonOn,
            style: style,
            glowStrength: glow,
            infinityPhase: phase,
          );
          return RepaintBoundary(
            child: AspectRatio(
              aspectRatio: LedTimerPainter.aspectRatioFor(text, style.slant),
              child: infinite
                  ? _InfinityAnimation(
                      animate: animate,
                      length: infinityLoopLength(
                        style.infinityStyle,
                        LedTimerPainter.digitCount,
                      ).toDouble(),
                      builder: (phase) => CustomPaint(painter: painter(phase)),
                    )
                  : CustomPaint(painter: painter(null)),
            ),
          );
        },
      ),
    );
  }
}

/// Chạy pha của hiệu ứng ∞ lặp vô hạn: đi hết [length] đoạn mỗi vòng,
/// [msPerSegment] mỗi đoạn.
class _InfinityAnimation extends StatefulWidget {
  const _InfinityAnimation({
    required this.animate,
    required this.length,
    required this.builder,
  });

  final bool animate;

  /// Số đoạn của một vòng hiệu ứng.
  final double length;
  final Widget Function(double phase) builder;

  static const msPerSegment = 200;

  Duration get period =>
      Duration(milliseconds: (msPerSegment * length).round());

  @override
  State<_InfinityAnimation> createState() => _InfinityAnimationState();
}

class _InfinityAnimationState extends State<_InfinityAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.period,
  );

  @override
  void initState() {
    super.initState();
    if (widget.animate) _controller.repeat();
  }

  @override
  void didUpdateWidget(_InfinityAnimation old) {
    super.didUpdateWidget(old);
    if (old.length != widget.length) {
      _controller.duration = widget.period;
      if (_controller.isAnimating) _controller.repeat();
    }
    if (widget.animate && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.animate && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    // Pha tính theo số đoạn trên đường đi của hiệu ứng.
    builder: (context, _) => widget.builder(_controller.value * widget.length),
  );
}

class LedTimerPainter extends CustomPainter {
  LedTimerPainter({
    required this.text,
    required this.color,
    required this.style,
    required this.glowStrength,
    this.colonOn = true,
    this.infinityPhase,
  });

  final String text;
  final Color color;
  final LedStyle style;
  final double glowStrength;
  final bool colonOn;

  /// Khác null: vẽ hiệu ứng ∞ tại pha này thay vì hiện [text]. Tính theo số
  /// đoạn trên đường đi của [LedStyle.infinityStyle].
  final double? infinityPhase;

  /// Số chữ số của "MM:SS".
  static const int digitCount = 4;

  /// Lề quanh chữ số (theo đơn vị chiều dài đoạn) để glow không bị cắt.
  static const double _padding = 0.15;

  static double aspectRatioFor(String text, double slant) {
    const h = SevenSegGeometry.height + 2 * _padding;
    final w =
        SevenSegGeometry.widthFor(text) +
        slant * SevenSegGeometry.height +
        2 * _padding;
    return w / h;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final width = SevenSegGeometry.widthFor(text);
    const height = SevenSegGeometry.height;
    final unitW = width + style.slant * height + 2 * _padding;
    const unitH = height + 2 * _padding;
    final scale = math.min(size.width / unitW, size.height / unitH);

    canvas.save();
    // Căn giữa, đặt gốc ở đáy chữ số rồi nghiêng (đỉnh lệch sang phải).
    canvas.translate(
      (size.width - unitW * scale) / 2 + _padding * scale,
      (size.height - unitH * scale) / 2 + (_padding + height) * scale,
    );
    canvas.scale(scale);
    canvas.skew(-style.slant, 0);
    canvas.translate(0, -height);

    // Gom các đoạn theo mức sáng để mỗi mức chỉ cần một lệnh vẽ.
    final off = _Parts();
    final lit = <double, _Parts>{};
    var digitIndex = 0;
    for (final glyph in layoutGlyphs(text)) {
      if (glyph.char == ':') {
        (colonOn ? lit.putIfAbsent(1, _Parts.new) : off).colons.add(
          glyph.originX,
        );
        continue;
      }
      final levels = switch (infinityPhase) {
        // Mức sáng làm tròn 0.2 để giới hạn số lệnh vẽ.
        final phase? => {
          for (final MapEntry(:key, :value) in infinityLevels(
            style.infinityStyle,
            phase,
            digit: digitIndex,
            digitCount: digitCount,
          ).entries)
            key: (value * 5).ceil() / 5,
        },
        null => {
          for (final seg in digitSegments[int.parse(glyph.char)]!) seg: 1.0,
        },
      };
      for (final seg in Segment.values) {
        final level = levels[seg];
        // Hiệu ứng ∞: vẫn vẽ nền mờ dưới đoạn đang sáng một phần.
        if (level == null || infinityPhase != null) {
          off.segments.add((glyph.originX, seg));
        }
        if (level != null) {
          lit.putIfAbsent(level, _Parts.new).segments.add((glyph.originX, seg));
        }
      }
      // Kiểu chấm: ô giao nhau giữa các đoạn sáng theo đoạn kề sáng nhất;
      // hình dạng ô tuỳ đoạn kề nào sáng (bo tròn chỗ gấp khúc).
      if (style.digitStyle == LedDigitStyle.dots) {
        final x = glyph.originX;
        final corners = cornerLevels(levels);
        for (final corner in LedCorner.values) {
          final level = corners[corner];
          final litCells = level == null
              ? const <(int, int)>[]
              : cornerCells(
                  corner,
                  lit: {
                    for (final seg in cornerSegments[corner]!)
                      if (levels[seg] != null) seg,
                  },
                );
          for (final cell in cornerCells(corner)) {
            // Hiệu ứng ∞: luôn vẽ nền mờ; còn lại chỉ ô không sáng mới mờ.
            if (infinityPhase != null || !litCells.contains(cell)) {
              off.dots.add(ledLatticeDot(x, cell.$1, cell.$2));
            }
          }
          if (level != null) {
            lit.putIfAbsent(level, _Parts.new).dots.addAll([
              for (final (c, r) in litCells) ledLatticeDot(x, c, r),
            ]);
          }
        }
      }
      digitIndex++;
    }

    canvas.drawPath(
      _pathFor(off, width, height),
      Paint()..color = color.withValues(alpha: style.offOpacity),
    );
    for (final MapEntry(key: level, value: parts) in lit.entries) {
      final path = _pathFor(parts, width, height);
      if (glowStrength > 0) {
        // Sigma của blur tính theo toạ độ local (đã scale cùng canvas).
        const t = SevenSegGeometry.thickness;
        for (final (alpha, sigma) in const [(0.35, 0.6), (0.7, 0.2)]) {
          canvas.drawPath(
            path,
            Paint()
              ..color = color.withValues(alpha: alpha * level)
              ..maskFilter = MaskFilter.blur(
                BlurStyle.normal,
                t * sigma * glowStrength,
              ),
          );
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = Color.lerp(
            color.withValues(alpha: style.offOpacity),
            color,
            level,
          )!,
      );
    }
    canvas.restore();
  }

  /// Dựng Path cho một nhóm đoạn + dấu ':' theo kiểu chữ số đang chọn.
  Path _pathFor(_Parts parts, double width, double height) {
    final path = Path();
    switch (style.digitStyle) {
      case LedDigitStyle.dots:
        void dot(Offset c) => path.addOval(
          Rect.fromCircle(center: c, radius: ledDotPitch * 0.42),
        );
        for (final (x, seg) in parts.segments) {
          segmentDots(seg, originX: x).forEach(dot);
        }
        parts.dots.forEach(dot);
        for (final x in parts.colons) {
          colonDots(x).forEach(dot);
        }
        return path;
      case LedDigitStyle.solid || LedDigitStyle.scanlines:
        for (final (x, seg) in parts.segments) {
          path.addPolygon(
            segmentPolygon(seg, originX: x, shape: style.segmentShape),
            true,
          );
        }
        for (final x in parts.colons) {
          for (final square in colonPolygons(x)) {
            path.addPolygon(square, true);
          }
        }
        return style.digitStyle == LedDigitStyle.scanlines
            ? _striped(path, width, height)
            : path;
    }
  }

  /// Cắt [segments] thành các nét ngang mảnh (kiểu màn hình retro).
  static Path _striped(Path segments, double width, double height) {
    const pitch = SevenSegGeometry.thickness / 3.5;
    final stripes = Path();
    for (var y = 0.0; y < height; y += pitch) {
      stripes.addRect(Rect.fromLTWH(-1, y, width + 2, pitch * 0.55));
    }
    return Path.combine(PathOperation.intersect, segments, stripes);
  }

  @override
  bool shouldRepaint(LedTimerPainter old) =>
      old.text != text ||
      old.color != color ||
      old.colonOn != colonOn ||
      old.style != style ||
      old.glowStrength != glowStrength ||
      old.infinityPhase != infinityPhase;
}

/// Một nhóm đoạn (x gốc của chữ số, đoạn) và dấu ':' (x gốc) cùng mức sáng.
class _Parts {
  final segments = <(double, Segment)>[];
  final colons = <double>[];

  /// Chấm lẻ ở các ô góc (chỉ dùng cho kiểu chấm LED).
  final dots = <Offset>[];
}
