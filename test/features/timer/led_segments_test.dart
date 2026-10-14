import 'package:counting_your_time/features/timer/presentation/led_segments.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const colonParts = 2;

  group('digitSegments', () {
    test('chữ số 8 sáng cả 7 đoạn, chữ số 1 chỉ sáng b và c', () {
      expect(digitSegments[8], Segment.values.toSet());
      expect(digitSegments[1], {Segment.b, Segment.c});
    });

    test('có đủ 10 chữ số', () {
      expect(digitSegments.keys.toSet(), {for (var i = 0; i < 10; i++) i});
    });
  });

  group('segmentPolygon', () {
    test('kiểu vát có 6 đỉnh, kiểu chữ nhật có 4 đỉnh', () {
      for (final seg in Segment.values) {
        expect(segmentPolygon(seg).length, 6);
        expect(segmentPolygon(seg, shape: LedSegmentShape.rect).length, 4);
      }
    });
  });

  group('buildSevenSegFrame', () {
    test('"88:88" bật toàn bộ đoạn, không có đoạn tắt', () {
      final frame = buildSevenSegFrame('88:88');
      expect(frame.on.length, 4 * 7 + colonParts);
      expect(frame.off, isEmpty);
    });

    test('"11:11" chỉ bật đoạn b, c và dấu hai chấm', () {
      final frame = buildSevenSegFrame('11:11');
      expect(frame.on.length, 4 * 2 + colonParts);
      expect(frame.off.length, 4 * 5);
    });

    test('colonOn=false chuyển dấu hai chấm sang đoạn tắt', () {
      final frame = buildSevenSegFrame('88:88', colonOn: false);
      expect(frame.on.length, 4 * 7);
      expect(frame.off.length, colonParts);
    });

    test('mọi đỉnh nằm trong khung', () {
      final frame = buildSevenSegFrame('08:59');
      expect(frame.width, closeTo(SevenSegGeometry.widthFor('08:59'), 1e-9));
      for (final poly in [...frame.on, ...frame.off]) {
        for (final p in poly) {
          expect(p.dx, inInclusiveRange(0, frame.width));
          expect(p.dy, inInclusiveRange(0, frame.height));
        }
      }
    });
  });

  group('buildDotFrame (kiểu chấm LED)', () {
    int dotsOf(Iterable<Segment> segs) =>
        segs.fold(0, (n, s) => n + segmentDots(s).length);

    test('mỗi đoạn 3 hàng: 12 · 14 · 12 chấm (đầu nhọn)', () {
      for (final seg in Segment.values) {
        expect(segmentDots(seg).length, 38);
      }
    });

    test('"88:88" bật toàn bộ chấm', () {
      final frame = buildDotFrame('88:88');
      expect(frame.on.length, 4 * dotsOf(Segment.values) + 18);
      expect(frame.off, isEmpty);
    });

    test('"11:11" chỉ bật chấm của đoạn b, c và dấu hai chấm', () {
      final frame = buildDotFrame('11:11');
      final bc = dotsOf(const [Segment.b, Segment.c]);
      expect(frame.on.length, 4 * bc + 18);
      expect(frame.off.length, 4 * (dotsOf(Segment.values) - bc));
    });

    test('chấm các đoạn nằm trên lưới chung, không chấm nào đè nhau', () {
      final dots = [for (final seg in Segment.values) ...segmentDots(seg)];
      for (var i = 0; i < dots.length; i++) {
        for (var j = i + 1; j < dots.length; j++) {
          expect(
            (dots[i] - dots[j]).distance,
            greaterThanOrEqualTo(ledDotPitch * 0.999),
          );
        }
      }
    });

    test('mọi chấm nằm trong khung', () {
      final frame = buildDotFrame('08:59');
      for (final p in [...frame.on, ...frame.off]) {
        expect(p.dx, inInclusiveRange(0, frame.width));
        expect(p.dy, inInclusiveRange(0, frame.height));
      }
    });
  });

  group('hiệu ứng ∞ (rắn chạy nối tiếp)', () {
    const t = SevenSegGeometry.thickness;
    const l = SevenSegGeometry.length;
    // Điểm giữa-trái / giữa-phải trên khung xương của chữ số ở x = 0.
    const midLeft = Offset(t / 2, t / 2 + l);
    const midRight = Offset(t / 2 + l, t / 2 + l);

    /// Đi theo [path], trả về điểm kết thúc; fail nếu có đoạn không nối
    /// liền với đoạn trước (bắt đầu tại [from]).
    Offset walk(List<Segment> path, Offset from) {
      var at = from;
      for (final seg in path) {
        final (p0, p1) = segmentAxis(seg);
        if ((p0 - at).distance < 1e-9) {
          at = p1;
        } else if ((p1 - at).distance < 1e-9) {
          at = p0;
        } else {
          fail('Đoạn $seg không nối liền tại $at');
        }
      }
      return at;
    }

    test('mỗi chữ số đi qua đủ 7 đoạn, mỗi đoạn một lần', () {
      for (var d = 0; d < 4; d++) {
        final path = figureEightPathFor(d);
        expect(path, hasLength(figureEightSegmentsPerDigit));
        expect(path.toSet(), Segment.values.toSet());
      }
    });

    test('vào ở giữa-trái, ra ở giữa-phải → nối liền sang chữ số sau', () {
      for (var d = 0; d < 4; d++) {
        expect(walk(figureEightPathFor(d), midLeft), midRight);
      }
    });

    test('hai chữ số cạnh nhau đối xứng trên/dưới', () {
      const flip = {
        Segment.a: Segment.d,
        Segment.d: Segment.a,
        Segment.b: Segment.c,
        Segment.c: Segment.b,
        Segment.f: Segment.e,
        Segment.e: Segment.f,
        Segment.g: Segment.g,
      };
      expect(figureEightPathFor(1), [
        for (final s in figureEightPathFor(0)) flip[s],
      ]);
      expect(figureEightPathFor(2), figureEightPathFor(0));
    });

    Map<Segment, double> at(double p, int digit) =>
        figureEightLevels(p, digit: digit, digitCount: 4);

    test('đầu rắn sáng nhất, đuôi mờ dần', () {
      final levels = at(2, 0); // đầu ở đoạn thứ 3 (b) của chữ số 1
      expect(levels[Segment.b], 1);
      expect(levels[Segment.a], closeTo(2 / 3, 1e-9));
      expect(levels[Segment.f], closeTo(1 / 3, 1e-9));
      expect(levels[Segment.d], isNull);
    });

    test('hết chữ số 1 mới sang chữ số 2, đuôi vắt qua ranh giới', () {
      // Đầu ở đoạn cuối (g) của chữ số 1 → chữ số 2 vẫn tối.
      expect(at(6, 0)[Segment.g], 1);
      expect(at(6, 1), isEmpty);
      // Sang đoạn đầu của chữ số 2 (e, vì lật dọc); đuôi còn ở chữ số 1.
      expect(at(7, 1)[Segment.e], 1);
      expect(at(7, 0)[Segment.g], closeTo(2 / 3, 1e-9));
      expect(at(7, 2), isEmpty);
      // Hết chữ số 4 thì quay về chữ số 1.
      expect(at(28, 0)[Segment.f], 1);
      expect(at(28, 3)[Segment.g], closeTo(2 / 3, 1e-9));
    });

    test('mức sáng luôn trong (0, 1]', () {
      for (var p = 0.0; p < 28; p += 0.37) {
        for (var d = 0; d < 4; d++) {
          for (final v in at(p, d).values) {
            expect(v, inExclusiveRange(0, 1.0000001));
          }
        }
      }
    });
  });

  group('hiệu ứng ∞ đồng bộ', () {
    test('vòng số 8 kín đi qua đủ 7 đoạn, g hai lần', () {
      expect(figureEightLoop.toSet(), Segment.values.toSet());
      expect(figureEightLoop.where((s) => s == Segment.g).length, 2);
      expect(infinityLoopLength(LedInfinityStyle.sync, 4), 8);
      expect(infinityLoopLength(LedInfinityStyle.chain, 4), 28);
    });

    test('cả 4 chữ số sáng giống hệt nhau cùng lúc', () {
      for (var p = 0.0; p < 8; p += 0.45) {
        final first = infinityLevels(
          LedInfinityStyle.sync,
          p,
          digit: 0,
          digitCount: 4,
        );
        expect(first, isNotEmpty);
        for (var d = 1; d < 4; d++) {
          expect(
            infinityLevels(LedInfinityStyle.sync, p, digit: d, digitCount: 4),
            first,
          );
        }
      }
    });

    test('đầu rắn ở a lúc bắt đầu, quay vòng sau 8 đoạn', () {
      final start = infinityLevels(LedInfinityStyle.sync, 0);
      expect(start[Segment.a], 1);
      expect(infinityLevels(LedInfinityStyle.sync, 8), start);
    });
  });
}
