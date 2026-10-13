import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/widgets/fade_slide_in.dart';
import '../../../app/widgets/smooth_progress.dart';
import '../../presets/application/preset_providers.dart';
import '../../settings/presentation/settings_screen.dart';
import 'session_grid.dart';
import '../../stats/application/stats_providers.dart';
import '../../stats/presentation/achievements_board.dart';
import '../application/quote_provider.dart';
import '../domain/time_quotes.dart';
import '../../themes/presentation/cyt_theme.dart';
import '../../timer/application/timer_providers.dart';
import '../../timer/domain/timer_engine.dart';
import '../../timer/presentation/timer_actions.dart';

/// Từ bề ngang này trở lên: thành tựu một cột trái, session một cột phải.
const double _twoColumnBreakpoint = 1000;

/// Màn chính: bảng thành tựu + các session dạng card.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= _twoColumnBreakpoint;
            final hPad = wide ? 48.0 : 20.0;
            // Chừa chỗ cho thanh "đang chạy" nổi ở đáy.
            const bottomPad = 112.0;

            if (!wide) {
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: CustomScrollView(
                    slivers: [
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(hPad, 20, hPad, 0),
                        sliver: const SliverToBoxAdapter(child: _Header()),
                      ),
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(hPad, 28, hPad, 0),
                        sliver: const SliverToBoxAdapter(
                          child: FadeSlideIn(child: AchievementsBoard()),
                        ),
                      ),
                      ..._sessionSlivers(
                        ref,
                        EdgeInsets.fromLTRB(hPad, 36, hPad, bottomPad),
                      ),
                    ],
                  ),
                ),
              );
            }

            return Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(hPad, 28, hPad, 0),
                  child: const _Header(),
                ),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: (constraints.maxWidth * 0.4).clamp(400, 620),
                        child: ListView(
                          padding: EdgeInsets.fromLTRB(hPad, 32, 0, bottomPad),
                          children: const [
                            FadeSlideIn(child: AchievementsBoard()),
                          ],
                        ),
                      ),
                      const SizedBox(width: 48),
                      Expanded(
                        child: CustomScrollView(
                          slivers: _sessionSlivers(
                            ref,
                            EdgeInsets.fromLTRB(0, 32, hPad, bottomPad),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: const _RunningBar(),
      extendBody: true,
    );
  }

  /// Tiêu đề "Session" + lưới card (thêm ô tạo mới ở cuối).
  List<Widget> _sessionSlivers(WidgetRef ref, EdgeInsets padding) {
    final presetsAsync = ref.watch(visiblePresetsProvider);
    return [
      SliverPadding(
        padding: EdgeInsets.fromLTRB(
          padding.left,
          padding.top,
          padding.right,
          16,
        ),
        sliver: SliverToBoxAdapter(
          child: _SectionTitle(
            title: 'Sessions',
            count: presetsAsync.value?.length,
            hint: 'Long-press a card to reorder',
          ),
        ),
      ),
      switch (presetsAsync) {
        AsyncError(:final error) => SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: padding.left),
            child: Text('Error: $error'),
          ),
        ),
        AsyncData(value: final presets) => SliverPadding(
          padding: EdgeInsets.fromLTRB(
            padding.left,
            0,
            padding.right,
            padding.bottom,
          ),
          sliver: SessionGrid(presets: presets),
        ),
        _ => const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(48),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
        ),
      },
    ];
  }
}

const _weekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

const _months = [
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

class _Header extends ConsumerWidget {
  const _Header();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final today = ref.watch(todayProvider);
    final quote = ref.watch(timeQuoteProvider);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_weekdays[today.weekday - 1]}, '
                '${_months[today.month - 1]} ${today.day}',
                style: textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              // Câu trích dẫn về thời gian, đổi mỗi 30 phút (hiện dần).
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 600),
                layoutBuilder: (current, previous) => Stack(
                  alignment: Alignment.topLeft,
                  children: [...previous, ?current],
                ),
                child: _QuoteView(key: ValueKey(quote.text), quote: quote),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Settings',
          iconSize: 26,
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
          ),
          icon: const Icon(Icons.tune_rounded),
        ),
      ],
    );
  }
}

/// Câu trích dẫn (chữ lớn, nét mảnh) + tác giả nhỏ bên dưới.
class _QuoteView extends StatelessWidget {
  const _QuoteView({super.key, required this.quote});

  final TimeQuote quote;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '\u201C${quote.text}\u201D',
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w300,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '— ${quote.author}',
          style: textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.count, this.hint});

  final String title;
  final int? count;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(title, style: textTheme.titleLarge),
        if (count != null) ...[
          const SizedBox(width: 8),
          Text(
            '$count',
            style: textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        if (hint != null) ...[
          const Spacer(),
          Text(hint!, style: textTheme.bodySmall),
        ],
      ],
    );
  }
}

/// Thanh nổi ở đáy khi đang có timer chạy/tạm dừng; bấm để mở đồng hồ.
class _RunningBar extends ConsumerWidget {
  const _RunningBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(timerControllerProvider);
    final visible =
        snapshot.status == TimerStatus.running ||
        snapshot.status == TimerStatus.paused;
    final plan = ref.watch(activePlanProvider);
    final theme = Theme.of(context);
    final color = CytTheme.of(
      context,
    ).clockColor(snapshot.phase, ending: snapshot.isEnding);
    final total = snapshot.step.duration.inMilliseconds;
    final progress = snapshot.isInfinite || total <= 0
        ? null
        : (1 - snapshot.remaining.inMilliseconds / total).clamp(0.0, 1.0);

    return AnimatedSlide(
      offset: visible ? Offset.zero : const Offset(0, 1.4),
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 250),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Center(
              heightFactor: 1,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Material(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(28),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: visible ? () => openClock(context) : null,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(22, 14, 12, 12),
                          child: Row(
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 500),
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  '${plan.name} · ${snapshot.step.displayName}'
                                  '${snapshot.status == TimerStatus.paused ? ' (paused)' : ''}',
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyLarge,
                                ),
                              ),
                              Text(
                                snapshot.display,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w300,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.chevron_right_rounded),
                            ],
                          ),
                        ),
                        if (progress != null)
                          SmoothProgress(value: progress, color: color),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
