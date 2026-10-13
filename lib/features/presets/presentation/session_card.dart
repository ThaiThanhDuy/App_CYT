import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/data_providers.dart';
import '../../themes/presentation/cyt_theme.dart';
import '../../timer/application/timer_providers.dart';
import '../../timer/domain/timer_engine.dart';
import '../../timer/domain/timer_plan.dart';
import '../../timer/presentation/timer_actions.dart';
import '../application/preset_providers.dart';
import '../domain/plan_summary.dart';
import '../domain/preset_entry.dart';
import 'preset_editor_screen.dart';

const _cardRadius = 24.0;

/// Card một session ở màn chính.
///
/// Bấm card để sửa; góc dưới trái là chuông (tắt/bật âm thanh riêng cho
/// session này); góc dưới phải là nút Start hình viên thuốc mở màn đồng hồ.
class SessionCard extends ConsumerStatefulWidget {
  const SessionCard({super.key, required this.entry});

  final PresetEntry entry;

  @override
  ConsumerState<SessionCard> createState() => _SessionCardState();
}

class _SessionCardState extends ConsumerState<SessionCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final cyt = CytTheme.of(context);
    final entry = widget.entry;
    final plan = entry.plan;
    final isActive = ref.watch(activePlanProvider).id == plan.id;
    // Chỉ cần trạng thái/pha, không rebuild mỗi giây.
    final (status, phase, ending) = ref.watch(
      timerControllerProvider.select((s) => (s.status, s.phase, s.isEnding)),
    );
    final inProgress =
        isActive &&
        (status == TimerStatus.running || status == TimerStatus.paused);
    final accent = cyt.clockColor(phase, ending: ending);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        scale: _hovered ? 1.015 : 1,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: _hovered
                ? scheme.surfaceContainerHigh
                : scheme.surfaceContainer,
            borderRadius: BorderRadius.circular(_cardRadius),
            border: Border.all(
              color: inProgress ? accent : Colors.transparent,
              width: 1.6,
            ),
          ),
          child: Material(
            type: MaterialType.transparency,
            borderRadius: BorderRadius.circular(_cardRadius),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => PresetEditorScreen(initial: plan),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 20, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Thời lượng các bước: thông tin chính của card.
                    Text(
                      describeStepsOnly(plan),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 8),
                    _PlanMeta(plan: plan),
                    const Spacer(),
                    _StepsBar(entry: entry),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        IconButton(
                          tooltip: entry.muted ? 'Unmute' : 'Mute',
                          onPressed: () => ref
                              .read(presetRepositoryProvider)
                              .setMuted(entry.id, muted: !entry.muted),
                          icon: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            transitionBuilder: (child, a) =>
                                ScaleTransition(scale: a, child: child),
                            child: Icon(
                              entry.muted
                                  ? Icons.notifications_off_outlined
                                  : Icons.notifications_none_rounded,
                              key: ValueKey(entry.muted),
                              color: entry.muted
                                  ? scheme.onSurfaceVariant
                                  : scheme.onSurface,
                            ),
                          ),
                        ),
                        const Spacer(),
                        FilledButton.icon(
                          onPressed: () => startSession(context, ref, plan),
                          style: FilledButton.styleFrom(
                            shape: const StadiumBorder(),
                            minimumSize: const Size(0, 44),
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                          ),
                          icon: Icon(
                            inProgress
                                ? Icons.graphic_eq_rounded
                                : Icons.play_arrow_rounded,
                          ),
                          label: Text(inProgress ? 'Running' : 'Start'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Số vòng + tổng thời gian, cùng kiểu icon với màn đồng hồ: icon lặp lại
/// kèm bong bóng số vòng, icon đồng hồ cát kèm tổng thời gian.
class _PlanMeta extends StatelessWidget {
  const _PlanMeta({required this.plan});

  final TimerPlan plan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Row(
      children: [
        if (plan.repeat > 1) ...[
          Tooltip(
            message: '${plan.repeat} rounds',
            child: Badge(
              backgroundColor: theme.colorScheme.onSurface,
              textColor: theme.colorScheme.surface,
              offset: const Offset(9, -7),
              label: Text(
                '${plan.repeat}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              child: Icon(Icons.repeat_rounded, size: 18, color: muted),
            ),
          ),
          const SizedBox(width: 22),
        ],
        Tooltip(
          message: 'Total time',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.hourglass_bottom_rounded, size: 16, color: muted),
              const SizedBox(width: 3),
              Text(
                plan.hasInfinite ? '∞' : formatDuration(plan.totalDuration),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                  // "∞" to gần bằng icon đồng hồ cát (16px).
                  fontSize: plan.hasInfinite ? 18 : null,
                  height: plan.hasInfinite ? 1 : null,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Ô cuối lưới để tạo session mới.
class AddSessionCard extends StatefulWidget {
  const AddSessionCard({super.key});

  @override
  State<AddSessionCard> createState() => _AddSessionCardState();
}

class _AddSessionCardState extends State<AddSessionCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_cardRadius),
          border: Border.all(
            color: _hovered ? scheme.outline : scheme.outlineVariant,
            width: 1.2,
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          borderRadius: BorderRadius.circular(_cardRadius),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const PresetEditorScreen(),
              ),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedRotation(
                    turns: _hovered ? 0.25 : 0,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    child: Icon(
                      Icons.add_rounded,
                      size: 40,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'New session',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Thanh ngang chia đoạn theo thời lượng từng bước (một vòng), màu theo pha.
class _StepsBar extends StatelessWidget {
  const _StepsBar({required this.entry});

  final PresetEntry entry;

  @override
  Widget build(BuildContext context) {
    final cyt = CytTheme.of(context);
    final steps = entry.plan.steps;
    // Bước vô hạn vẽ dài bằng bước có giờ dài nhất (hoặc 25 phút).
    final longest = steps
        .where((s) => !s.infinite)
        .fold(0, (m, s) => s.duration.inSeconds > m ? s.duration.inSeconds : m);
    final infiniteFlex = longest > 0 ? longest : 25 * 60;
    return SizedBox(
      height: 8,
      child: Row(
        children: [
          for (final (i, step) in steps.indexed) ...[
            if (i > 0) const SizedBox(width: 3),
            Expanded(
              // flex tối thiểu 1 để bước rất ngắn vẫn nhìn thấy.
              flex: step.infinite
                  ? infiniteFlex
                  : step.duration.inSeconds.clamp(1, 1 << 20),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: cyt.colorFor(step.phase),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
