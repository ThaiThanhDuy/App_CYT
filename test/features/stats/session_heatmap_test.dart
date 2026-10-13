import 'package:counting_your_time/features/stats/presentation/heatmap_colors.dart';
import 'package:counting_your_time/features/stats/presentation/session_heatmap.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Thứ Tư, 14/10/2026.
final _today = DateTime(2026, 10, 14);

Widget _wrap(
  Map<String, int> counts, {
  Brightness brightness = Brightness.light,
  double width = 432,
}) => MaterialApp(
  theme: ThemeData(brightness: brightness),
  home: Scaffold(
    body: Center(
      child: SizedBox(
        width: width,
        child: Column(
          children: [
            SessionHeatmap(counts: counts, today: _today),
            const HeatmapLegend(),
          ],
        ),
      ),
    ),
  ),
);

Finder _cell(String day) => find.byKey(ValueKey(day));

HeatmapCell _cellWidget(WidgetTester tester, String day) =>
    tester.widget<HeatmapCell>(_cell(day));

BoxDecoration _decoration(WidgetTester tester, String day) =>
    tester
            .widget<AnimatedContainer>(
              find.descendant(
                of: _cell(day),
                matching: find.byType(AnimatedContainer),
              ),
            )
            .decoration!
        as BoxDecoration;

void main() {
  testWidgets('26 tuần, tuần mới nhất kết thúc ở hôm nay', (tester) async {
    await tester.pumpWidget(_wrap({}));
    // 25 tuần đủ 7 ngày + tuần này T2→T4.
    expect(find.byType(HeatmapCell), findsNWidgets(25 * 7 + 3));
    expect(_cell('2026-10-14'), findsOneWidget);
    expect(_cell('2026-10-15'), findsNothing); // tương lai không vẽ
    // Ô đầu tiên là thứ Hai của 25 tuần trước.
    expect(_cell('2026-04-27'), findsOneWidget);
    expect(_cell('2026-04-26'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('nhãn thứ, nhãn tháng và chú giải', (tester) async {
    await tester.pumpWidget(_wrap({}));
    for (final label in ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']) {
      expect(find.text(label), findsOneWidget);
    }
    for (final month in ['May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct']) {
      expect(find.text(month), findsOneWidget);
    }
    expect(find.text('Less'), findsOneWidget);
    expect(find.text('More'), findsOneWidget);
  });

  testWidgets('màu ô theo số phiên, ≥10 dùng màu đậm nhất', (tester) async {
    await tester.pumpWidget(
      _wrap({'2026-10-12': 1, '2026-10-13': 10, '2026-10-14': 15}),
    );
    const b = Brightness.light;
    expect(_decoration(tester, '2026-10-11').color, heatmapColor(0, b));
    expect(_decoration(tester, '2026-10-12').color, heatmapColor(1, b));
    expect(_decoration(tester, '2026-10-13').color, heatmapColor(10, b));
    expect(_decoration(tester, '2026-10-14').color, heatmapColor(10, b));
  });

  testWidgets('dark mode dùng bảng màu tối', (tester) async {
    await tester.pumpWidget(
      _wrap({'2026-10-14': 3}, brightness: Brightness.dark),
    );
    await tester.pumpAndSettle();
    expect(
      _decoration(tester, '2026-10-14').color,
      heatmapColor(3, Brightness.dark),
    );
  });

  testWidgets('chỉ ô hôm nay có viền', (tester) async {
    await tester.pumpWidget(_wrap({}));
    expect(_cellWidget(tester, '2026-10-14').isToday, isTrue);
    expect(_decoration(tester, '2026-10-14').border, isNotNull);
    expect(_decoration(tester, '2026-10-13').border, isNull);
  });

  testWidgets('bấm giữ hiện "N phiên · dd/mm/yyyy"', (tester) async {
    await tester.pumpWidget(_wrap({'2026-10-14': 3}));
    await tester.longPress(_cell('2026-10-14'));
    await tester.pumpAndSettle();
    expect(find.text('3 sessions · Oct 14, 2026'), findsOneWidget);
  });

  testWidgets('rê chuột hiện tooltip', (tester) async {
    await tester.pumpWidget(_wrap({}));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(_cell('2026-10-05')));
    await tester.pumpAndSettle(const Duration(milliseconds: 300));
    expect(find.text('0 sessions · Oct 5, 2026'), findsOneWidget);
  });

  testWidgets('thêm phiên thì ô hôm nay nảy lên rồi đậm dần', (tester) async {
    await tester.pumpWidget(_wrap({'2026-10-14': 1}));
    await tester.pumpWidget(_wrap({'2026-10-14': 2}));

    await tester.pump(const Duration(milliseconds: 150));
    final scale = tester
        .widget<ScaleTransition>(
          find.descendant(
            of: _cell('2026-10-14'),
            matching: find.byType(ScaleTransition),
          ),
        )
        .scale
        .value;
    expect(scale, greaterThan(1.0));
    final midColor = _decoration(tester, '2026-10-14').color;
    expect(midColor, heatmapColor(2, Brightness.light)); // đích của tween

    await tester.pumpAndSettle();
    final endScale = tester
        .widget<ScaleTransition>(
          find.descendant(
            of: _cell('2026-10-14'),
            matching: find.byType(ScaleTransition),
          ),
        )
        .scale
        .value;
    expect(endScale, 1.0);
  });

  testWidgets('màn hẹp không bị tràn', (tester) async {
    await tester.pumpWidget(_wrap({}, width: 300));
    expect(tester.takeException(), isNull);
  });
}
