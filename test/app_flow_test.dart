import 'package:counting_your_time/app/app.dart';
import 'package:counting_your_time/app/cyt_colors.dart';
import 'package:counting_your_time/data/app_db.dart';
import 'package:counting_your_time/data/data_providers.dart';
import 'package:counting_your_time/features/alerts/application/alert_providers.dart';
import 'package:counting_your_time/features/alerts/data/sound_player.dart';
import 'package:counting_your_time/features/alerts/domain/sound_ref.dart';
import 'package:counting_your_time/features/stats/presentation/session_heatmap.dart';
import 'package:counting_your_time/features/timer/application/timer_providers.dart';
import 'package:counting_your_time/features/timer/presentation/led_timer_display.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fake_clock.dart';

void main() {
  late FakeClock clock;
  late AppDatabase db;

  Future<void> pumpApp(WidgetTester tester) async {
    // Thứ Hai 05/01/2026, 09:00.
    clock = FakeClock(DateTime(2026, 1, 5, 9));
    db = AppDatabase(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    addTearDown(() async {
      // Gỡ cây widget trước để huỷ stream query, rồi mới đóng DB.
      await tester.pumpWidget(const SizedBox());
      await db.close();
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          clockProvider.overrideWithValue(clock),
          wallClockProvider.overrideWithValue(clock),
          appDatabaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
          soundPlayerProvider.overrideWithValue(_SilentPlayer()),
        ],
        child: const CytApp(),
      ),
    );
    await tester.pump();
  }

  int todayCount(WidgetTester tester) => tester
      .widget<HeatmapCell>(find.byKey(const ValueKey('2026-01-05')))
      .count;

  Finder led(String text) => find.bySemanticsLabel('Time remaining $text');

  Future<void> elapse(WidgetTester tester, Duration d) async {
    clock.advance(d);
    await tester.pump(TimerController.tickInterval);
  }

  /// Bấm Start trên card Pomodoro mặc định và chờ màn đồng hồ mở.
  Future<void> startFromHome(WidgetTester tester) async {
    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();
  }

  testWidgets('màn chính có bảng thành tựu và card Pomodoro', (tester) async {
    await pumpApp(tester);
    expect(find.text('TODAY'), findsOneWidget);
    expect(find.text('Daily'), findsOneWidget);
    expect(find.text('Pomodoro 25/5'), findsOneWidget);
    expect(find.byTooltip('Mute'), findsOneWidget);
    expect(find.text('New session'), findsOneWidget);
    expect(find.byTooltip('Settings'), findsOneWidget);
  });

  testWidgets('Start mở đồng hồ và chạy ngay; tạm dừng giữ nguyên', (
    tester,
  ) async {
    await pumpApp(tester);
    await startFromHome(tester);
    expect(find.text('FOCUS'), findsOneWidget);

    await elapse(tester, const Duration(minutes: 10));
    expect(led('15:00'), findsOneWidget);

    await tester.tap(find.byTooltip('Pause (Space)'));
    await elapse(tester, const Duration(minutes: 7));
    expect(led('15:00'), findsOneWidget);
    expect(find.byTooltip('Resume (Space)'), findsOneWidget);
  });

  testWidgets('hết focus thì sang nghỉ, đổi màu; về màn chính thấy ô hôm nay '
      'tăng', (tester) async {
    await pumpApp(tester);
    await startFromHome(tester);
    await elapse(tester, const Duration(minutes: 25));

    expect(find.text('BREAK'), findsOneWidget);
    expect(find.text('Focus session complete'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 600));
    final painter =
        tester
                .widget<CustomPaint>(
                  find.descendant(
                    of: find.byType(LedTimerDisplay),
                    matching: find.byType(CustomPaint),
                  ),
                )
                .painter!
            as LedTimerPainter;
    expect(painter.color, CytColors.rest);

    await tester.pageBack();
    await tester.pump(const Duration(milliseconds: 500));
    expect(todayCount(tester), 1);
    // Timer vẫn chạy → có thanh "đang chạy" ở đáy màn chính.
    expect(find.textContaining('Pomodoro 25/5 · Break'), findsOneWidget);
  });

  testWidgets('bỏ qua focus không được tính', (tester) async {
    await pumpApp(tester);
    await startFromHome(tester);
    await tester.tap(find.byTooltip('Skip (N)'));
    await tester.pump();

    expect(find.text('BREAK'), findsOneWidget);
    expect(find.text('Focus session complete'), findsNothing);
    await tester.pageBack();
    await tester.pump(const Duration(milliseconds: 500));
    expect(todayCount(tester), 0);
  });

  testWidgets('chuông trên card bật/tắt âm thanh riêng của session', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.byTooltip('Mute'));
    await tester.pump();
    await tester.pump();
    expect(find.byTooltip('Unmute'), findsOneWidget);
    final row = await db.select(db.presets).getSingle();
    expect(row.muted, isTrue);
  });
}

/// Không phát gì, để widget test không gọi plugin âm thanh.
class _SilentPlayer implements SoundPlayer {
  @override
  Future<void> play(SoundRef sound) async {}

  @override
  Future<void> dispose() async {}
}
