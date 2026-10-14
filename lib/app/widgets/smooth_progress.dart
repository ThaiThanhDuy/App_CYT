import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Kiểu thanh tiến trình.
enum ProgressStyle {
  /// Đường thẳng mảnh.
  line('Line'),

  /// Các cột cao thấp khác nhau, chung đáy (kiểu equalizer).
  bars('Bars'),

  /// Các cột đối xứng qua đường giữa (kiểu sóng âm thanh).
  wave('Wave'),

  /// Đường gợn sóng hình sin mảnh, sóng trôi nhẹ khi đang chạy.
  squiggle('Squiggle');

  const ProgressStyle(this.label);
  final String label;
}

/// Thanh tiến trình chạy mượt giữa các lần cập nhật (state chỉ đổi mỗi
/// giây, thanh nội suy liên tục trong khoảng đó).
///
/// [style] khác [ProgressStyle.line] thì vẽ dạng cột cao [barHeight];
/// [animate] = true thì các cột nhấp nhô nhẹ (dùng khi timer đang chạy).
class SmoothProgress extends StatefulWidget {
  const SmoothProgress({
    super.key,
    required this.value,
    required this.color,
    this.height = 3,
    this.trackColor = Colors.transparent,
    this.style = ProgressStyle.line,
    this.barHeight = 32,
    this.animate = false,
  });

  final double value;
  final Color color;

  /// Độ dày của kiểu đường thẳng.
  final double height;
  final Color trackColor;
  final ProgressStyle style;

  /// Chiều cao tối đa của cột (kiểu bars / wave).
  final double barHeight;
  final bool animate;

  @override
  State<SmoothProgress> createState() => _SmoothProgressState();
}

class _SmoothProgressState extends State<SmoothProgress>
    with SingleTickerProviderStateMixin {
  late final AnimationController _wobble = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  bool get _shouldAnimate =>
      widget.animate && widget.style != ProgressStyle.line;

  @override
  void initState() {
    super.initState();
    if (_shouldAnimate) _wobble.repeat();
  }

  @override
  void didUpdateWidget(SmoothProgress old) {
    super.didUpdateWidget(old);
    if (_shouldAnimate && !_wobble.isAnimating) {
      _wobble.repeat();
    } else if (!_shouldAnimate && _wobble.isAnimating) {
      _wobble.stop();
    }
  }

  @override
  void dispose() {
    _wobble.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(end: widget.value),
    duration: const Duration(milliseconds: 950),
    builder: (context, v, _) => switch (widget.style) {
      ProgressStyle.line => ClipRRect(
        borderRadius: BorderRadius.circular(widget.height),
        child: LinearProgressIndicator(
          value: v,
          minHeight: widget.height,
          color: widget.color,
          backgroundColor: widget.trackColor,
        ),
      ),
      ProgressStyle.squiggle => SizedBox(
        // Sóng chỉ cần thấp; không cao bằng kiểu cột.
        height: math.min(widget.barHeight, 18),
        width: double.infinity,
        child: CustomPaint(
          painter: _SquigglePainter(
            progress: v,
            color: widget.color,
            trackColor: widget.trackColor,
            phase: _wobble,
          ),
        ),
      ),
      ProgressStyle.bars || ProgressStyle.wave => SizedBox(
        height: widget.barHeight,
        width: double.infinity,
        child: CustomPaint(
          painter: _BarsPainter(
            progress: v,
            color: widget.color,
            trackColor: widget.trackColor,
            centered: widget.style == ProgressStyle.wave,
            wobble: _wobble,
          ),
        ),
      ),
    },
  );
}

/// Đường gợn sóng: cả đường màu nền, phần đã chạy tô màu; [phase] làm sóng
/// trôi về phía trước khi đang chạy.
class _SquigglePainter extends CustomPainter {
  _SquigglePainter({
    required this.progress,
    required this.color,
    required this.trackColor,
    required this.phase,
  }) : super(repaint: phase);

  final double progress;
  final Color color;
  final Color trackColor;
  final Animation<double> phase;

  /// Bước sóng (px) và độ dày nét.
  static const double _wavelength = 18;
  static const double _stroke = 2.6;

  @override
  void paint(Canvas canvas, Size size) {
    final mid = size.height / 2;
    final amplitude = math.max(1.5, mid - _stroke);
    // Trôi hai bước sóng mỗi vòng của animation, từ trái sang phải
    // (cùng chiều tiến trình).
    final shift = phase.value * 2 * math.pi * 2;
    final start = _stroke / 2;
    final end = size.width - _stroke / 2;
    final path = Path()..moveTo(start, mid);
    for (var x = start; x <= end; x += 1.5) {
      path.lineTo(
        x,
        mid + amplitude * math.sin(2 * math.pi * x / _wavelength + shift),
      );
    }
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, paint..color = trackColor);
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width * progress, size.height));
    canvas.drawPath(path, paint..color = color);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SquigglePainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.trackColor != trackColor;
}

class _BarsPainter extends CustomPainter {
  _BarsPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
    required this.centered,
    required this.wobble,
  }) : super(repaint: wobble);

  final double progress;
  final Color color;
  final Color trackColor;

  /// true: cột đối xứng qua đường giữa (wave); false: chung đáy (bars).
  final bool centered;
  final Animation<double> wobble;

  /// Khoảng cách tâm hai cột (px), cột chiếm ~55%.
  static const double _pitch = 7;

  /// Chiều cao gốc (0–1) của cột thứ [i]: cố định theo vị trí, pha trộn vài
  /// sóng sin để trông như âm thanh thật mà không ngẫu nhiên mỗi lần vẽ.
  static double _baseHeight(int i) =>
      (0.55 +
              0.25 * math.sin(i * 0.82) +
              0.2 * math.sin(i * 2.31 + 1.3) +
              0.1 * math.sin(i * 5.7 + 0.4))
          .clamp(0.18, 1.0);

  @override
  void paint(Canvas canvas, Size size) {
    final n = math.max(1, (size.width / _pitch).floor());
    final step = size.width / n;
    final barWidth = step * 0.55;
    final radius = Radius.circular(barWidth / 2);
    final t = wobble.value * 2 * math.pi;

    final bars = Path();
    for (var i = 0; i < n; i++) {
      // Nhấp nhô nhẹ ±12% quanh chiều cao gốc khi đang chạy.
      final wave = wobble.isAnimating ? 0.88 + 0.12 * math.sin(t + i * 0.7) : 1;
      final h = math.max(barWidth, size.height * _baseHeight(i) * wave);
      final x = i * step + (step - barWidth) / 2;
      final top = centered ? (size.height - h) / 2 : size.height - h;
      bars.addRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x, top, barWidth, h), radius),
      );
    }

    // Toàn bộ cột màu nền, rồi tô màu phần đã chạy (cắt đúng vị trí tiến
    // trình, có thể cắt ngang một cột → di chuyển mượt).
    canvas.drawPath(bars, Paint()..color = trackColor);
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width * progress, size.height));
    canvas.drawPath(bars, Paint()..color = color);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BarsPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.trackColor != trackColor ||
      old.centered != centered;
}
