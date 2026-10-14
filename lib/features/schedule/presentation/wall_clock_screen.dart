import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../power/presentation/power_saver.dart';
import '../../themes/presentation/cyt_theme.dart';
import '../../timer/application/timer_providers.dart';
import '../../timer/presentation/led_timer_display.dart';

const _weekdayLong = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];
const _monthLong = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// Đồng hồ treo tường kiểu zen: giờ hiện tại "HH:MM" bằng LED (dấu ":"
/// nhấp nháy theo giây), ngày bên dưới, và tên block đang diễn ra (nếu có).
/// Mở từ nút Start ở màn Schedule khi lúc đó không có session để chạy.
class WallClockScreen extends ConsumerStatefulWidget {
  const WallClockScreen({super.key, this.blockTitle, this.until});

  /// Tên block đang diễn ra (block chưa gắn session), hoặc null.
  final String? blockTitle;

  /// Giờ kết thúc block (khi session của block đã xong sớm hơn block).
  final DateTime? until;

  @override
  ConsumerState<WallClockScreen> createState() => _WallClockScreenState();
}

class _WallClockScreenState extends ConsumerState<WallClockScreen> {
  Timer? _tick;

  static bool get _isMobile =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  void initState() {
    super.initState();
    // Làm mới 4 lần/giây để dấu ":" đổi gần đúng lúc sang giây mới.
    _tick = Timer.periodic(
      const Duration(milliseconds: 250),
      (_) => setState(() {}),
    );
    if (_isMobile) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    if (_isMobile) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    super.dispose();
  }

  static String _hhmm(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cyt = CytTheme.of(context);
    final now = ref.watch(wallClockProvider).now();
    final muted = theme.colorScheme.onSurfaceVariant;

    // Tiết kiệm pin: tối sau 5 phút không chạm, chạm / đổi pha thì sáng.
    return PowerSaver(
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyF): () =>
              Navigator.maybePop(context),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            body: Stack(
              children: [
                SafeArea(
                  child: LayoutBuilder(
                    builder: (context, c) => Column(
                      children: [
                        Expanded(
                          child: Center(
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: c.maxWidth * 0.94,
                                maxHeight: c.maxHeight * 0.72,
                              ),
                              // LedTimerDisplay hiện "MM:SS" → truyền giờ vào
                              // chỗ phút, phút vào chỗ giây để ra "HH:MM".
                              child: LedTimerDisplay(
                                remaining: Duration(
                                  minutes: now.hour,
                                  seconds: now.minute,
                                ),
                                color: cyt.focus,
                                colonOn: now.second.isEven,
                                style: cyt.led,
                              ),
                            ),
                          ),
                        ),
                        Text(
                          '${_weekdayLong[now.weekday - 1]}, '
                          '${_monthLong[now.month - 1]} ${now.day}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: muted,
                            letterSpacing: 1,
                          ),
                        ),
                        if (widget.blockTitle != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            widget.blockTitle!,
                            style: theme.textTheme.titleLarge,
                          ),
                        ],
                        if (widget.until case final until?) ...[
                          const SizedBox(height: 4),
                          Text(
                            now.isBefore(until)
                                ? 'Session done · until ${_hhmm(until)}'
                                : 'Block ended',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: muted,
                            ),
                          ),
                        ],
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: SafeArea(
                    child: IconButton(
                      tooltip: 'Close (F)',
                      onPressed: () => Navigator.maybePop(context),
                      color: muted,
                      icon: const Icon(Icons.fullscreen_exit_rounded),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
