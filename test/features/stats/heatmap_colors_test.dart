import 'package:counting_your_time/features/stats/presentation/heatmap_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Độ sáng cảm nhận (0–1) để so "nhạt/đậm".
double _luminance(Color c) => c.computeLuminance();

double _saturationGreen(Color c) => c.g - (c.r + c.b) / 2;

void main() {
  for (final b in Brightness.values) {
    group('heatmapColor (${b.name})', () {
      test('0 phiên là màu xám (không ám xanh)', () {
        final c = heatmapColor(0, b);
        expect(c.r, closeTo(c.g, 1e-9));
        expect(c.g, closeTo(c.b, 1e-9));
      });

      test('1 phiên là xanh, khác 0 phiên', () {
        final c = heatmapColor(1, b);
        expect(c, isNot(heatmapColor(0, b)));
        expect(_saturationGreen(c), greaterThan(0));
      });

      test('10 phiên là màu đậm nhất, khác 1 phiên', () {
        expect(heatmapColor(10, b), isNot(heatmapColor(1, b)));
      });

      test('>10 phiên giữ màu của 10 phiên', () {
        expect(heatmapColor(11, b), heatmapColor(10, b));
        expect(heatmapColor(999, b), heatmapColor(10, b));
      });

      test('số âm coi như 0', () {
        expect(heatmapColor(-3, b), heatmapColor(0, b));
      });
    });
  }

  test('light mode: càng nhiều phiên càng tối (đậm)', () {
    var prev = double.infinity;
    for (var n = 1; n <= 10; n++) {
      final l = _luminance(heatmapColor(n, Brightness.light));
      expect(l, lessThan(prev), reason: 'n=$n');
      prev = l;
    }
  });

  test('dark mode: càng nhiều phiên càng rực trên nền đen', () {
    var prev = -1.0;
    for (var n = 1; n <= 10; n++) {
      final l = _luminance(heatmapColor(n, Brightness.dark));
      expect(l, greaterThan(prev), reason: 'n=$n');
      prev = l;
    }
  });

  test('chế độ phút: đậm nhất từ 240 phút', () {
    const b = Brightness.dark;
    expect(heatmapColor(240, b, max: 240), heatmapColor(10, b));
    expect(heatmapColor(999, b, max: 240), heatmapColor(240, b, max: 240));
    expect(heatmapColor(1, b, max: 240), heatmapColor(1, b));
    expect(
      heatmapColor(120, b, max: 240),
      isNot(heatmapColor(240, b, max: 240)),
    );
  });
}
