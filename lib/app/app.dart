import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/alerts/application/alert_providers.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/stats/application/stats_providers.dart';
import '../features/themes/application/theme_providers.dart';
import '../features/themes/presentation/cyt_theme.dart';
import '../features/timer/application/timer_providers.dart';
import '../features/timer/domain/timer_engine.dart';
import '../features/timer/domain/timer_phase.dart';

/// Messenger cấp app: báo hoàn thành dù đang ở màn nào.
final _messengerKey = GlobalKey<ScaffoldMessengerState>();

class CytApp extends ConsumerWidget {
  const CytApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Giữ bộ ghi phiên và bộ báo hết giờ hoạt động suốt vòng đời app.
    ref.watch(sessionRecorderProvider);
    ref.watch(alertCoordinatorProvider);
    ref.listen(timerEventsProvider, (_, next) {
      final message = switch (next) {
        AsyncData(value: StepCompleted(step: final s))
            when s.phase == TimerPhase.focus =>
          'Focus session complete',
        AsyncData(value: PlanFinished()) => 'All rounds done',
        _ => null,
      };
      if (message == null) return;
      _messengerKey.currentState
        ?..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    });
    // Theme lấy từ gói theme đang chọn (mặc định Traffic Light).
    final themes = ref.watch(resolvedThemesProvider);
    final digitStyle = ref.watch(digitStyleProvider);
    final infinityStyle = ref.watch(infinityStyleProvider);
    final colors = ref.watch(colorOverridesProvider);
    return MaterialApp(
      title: 'Counting Your Time',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: _messengerKey,
      themeMode: themes.mode,
      theme: buildThemeData(
        themes.light,
        digitStyle: digitStyle,
        infinityStyle: infinityStyle,
        focus: colors.focus,
        rest: colors.rest,
        warning: colors.warning,
      ),
      darkTheme: buildThemeData(
        themes.dark,
        digitStyle: digitStyle,
        infinityStyle: infinityStyle,
        focus: colors.focus,
        rest: colors.rest,
        warning: colors.warning,
      ),
      home: const HomeScreen(),
    );
  }
}
