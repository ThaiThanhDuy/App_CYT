import 'package:counting_your_time/app/cyt_colors.dart';
import 'package:counting_your_time/features/timer/presentation/led_timer_display.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

LedTimerPainter _painter(WidgetTester tester) =>
    tester
            .widget<CustomPaint>(
              find.descendant(
                of: find.byType(LedTimerDisplay),
                matching: find.byType(CustomPaint),
              ),
            )
            .painter!
        as LedTimerPainter;

void main() {
  testWidgets('đổi màu thì chuyển dần trong 500ms', (tester) async {
    var color = CytColors.focus;
    late StateSetter setColor;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            setColor = setState;
            return LedTimerDisplay(
              remaining: const Duration(minutes: 5),
              color: color,
            );
          },
        ),
      ),
    );
    expect(_painter(tester).color, CytColors.focus);
    expect(find.bySemanticsLabel('Time remaining 05:00'), findsOneWidget);

    setColor(() => color = CytColors.rest);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    final mid = _painter(tester).color;
    expect(mid, isNot(CytColors.focus));
    expect(mid, isNot(CytColors.rest));

    await tester.pump(const Duration(milliseconds: 300));
    expect(_painter(tester).color, CytColors.rest);
  });

  testWidgets('glow chỉ bật ở dark mode', (tester) async {
    Future<double> glowFor(Brightness b) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: b),
          home: const LedTimerDisplay(
            remaining: Duration.zero,
            color: CytColors.focus,
          ),
        ),
      );
      // MaterialApp chuyển theme có animation, chờ xong mới đọc.
      await tester.pumpAndSettle();
      return _painter(tester).glowStrength;
    }

    expect(await glowFor(Brightness.dark), greaterThan(0));
    expect(await glowFor(Brightness.light), 0);
  });
}
