import 'dart:math' as math;

/// Tiến độ con trong đoạn [a, b] của tiến độ tổng [p], kẹp về 0–1.
double seg(double p, double a, double b) => ((p - a) / (b - a)).clamp(0.0, 1.0);

double easeOut(double t) => 1 - math.pow(1 - t, 3).toDouble();

double easeInOut(double t) =>
    t < 0.5 ? 4 * t * t * t : 1 - math.pow(-2 * t + 2, 3) / 2;

/// Rơi có nảy nhẹ khi chạm đất.
double easeOutBounce(double t) {
  const n = 7.5625;
  const d = 2.75;
  if (t < 1 / d) return n * t * t;
  if (t < 2 / d) return n * (t -= 1.5 / d) * t + 0.75;
  if (t < 2.5 / d) return n * (t -= 2.25 / d) * t + 0.9375;
  return n * (t -= 2.625 / d) * t + 0.984375;
}
