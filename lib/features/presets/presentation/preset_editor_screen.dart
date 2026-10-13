import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/data_providers.dart';
import '../../themes/presentation/cyt_theme.dart';
import '../../timer/domain/timer_phase.dart';
import '../../timer/domain/timer_plan.dart';
import '../../timer/presentation/confirm_interrupt.dart';
import '../application/preset_providers.dart';
import '../domain/plan_summary.dart';
import 'delete_session.dart';

const int _maxMinutes = 999;
const int _maxRepeat = 99;

/// Bản nháp một bước đang sửa. [key] giữ ổn định khi kéo thả sắp xếp.
class _StepDraft {
  _StepDraft(
    this.phase,
    int minutes, {
    this.sound,
    this.infinite = false,
    String? label,
  }) : minutes = TextEditingController(text: '$minutes'),
       name = TextEditingController(text: label ?? '');

  final Key key = UniqueKey();
  TimerPhase phase;

  /// Bước không giới hạn thời gian (ô tích "Vô hạn"); bỏ qua ô phút.
  bool infinite;

  /// Âm thanh của bước gốc, giữ nguyên khi lưu (chỉnh ở M5).
  final String? sound;
  final TextEditingController minutes;

  /// Tên riêng của bước; để trống = tên mặc định của pha (Focus / Break).
  final TextEditingController name;

  String? get label {
    final text = name.text.trim();
    return text.isEmpty ? null : text;
  }

  void dispose() {
    minutes.dispose();
    name.dispose();
  }

  int? get parsedMinutes {
    final m = int.tryParse(minutes.text);
    return m != null && m >= 1 && m <= _maxMinutes ? m : null;
  }

  bool get isValid => infinite || parsedMinutes != null;
}

/// Tạo mới ([initial] = null) hoặc sửa một preset.
class PresetEditorScreen extends ConsumerStatefulWidget {
  const PresetEditorScreen({super.key, this.initial});

  final TimerPlan? initial;

  @override
  ConsumerState<PresetEditorScreen> createState() => _PresetEditorScreenState();
}

class _PresetEditorScreenState extends ConsumerState<PresetEditorScreen> {
  late final TextEditingController _name;
  late final List<_StepDraft> _steps;
  late int _repeat;
  String? _nameError;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final plan = widget.initial;
    _name = TextEditingController(text: plan?.name ?? '');
    // Bước có giây lẻ được làm tròn lên phút (editor chỉ sửa theo phút).
    _steps = [
      for (final s in plan?.steps ?? TimerPlan.pomodoro.steps)
        _StepDraft(
          s.phase,
          // Bước vô hạn: điền sẵn số phút mặc định để bỏ tích là dùng được.
          s.infinite
              ? (s.phase == TimerPhase.focus ? 25 : 5)
              : (s.duration.inSeconds / 60).ceil().clamp(1, _maxMinutes),
          sound: s.sound,
          infinite: s.infinite,
          label: s.label,
        ),
    ];
    _repeat = plan?.repeat ?? TimerPlan.pomodoro.repeat;
  }

  @override
  void dispose() {
    _name.dispose();
    for (final s in _steps) {
      s.dispose();
    }
    super.dispose();
  }

  /// Plan dựng từ form, hoặc null nếu còn ô phút không hợp lệ.
  TimerPlan? _buildPlan() {
    final steps = <TimerStep>[];
    for (final draft in _steps) {
      if (draft.infinite) {
        steps.add(
          TimerStep.infinite(
            draft.phase,
            sound: draft.sound,
            label: draft.label,
          ),
        );
        continue;
      }
      final m = draft.parsedMinutes;
      if (m == null) return null;
      steps.add(
        TimerStep(
          phase: draft.phase,
          duration: Duration(minutes: m),
          sound: draft.sound,
          label: draft.label,
        ),
      );
    }
    return TimerPlan(
      id: widget.initial?.id,
      name: _name.text.trim(),
      steps: steps,
      repeat: _repeat,
    );
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    setState(() => _nameError = name.isEmpty ? 'Enter a session name' : null);
    final plan = _buildPlan();
    if (name.isEmpty) return;
    if (plan == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Each step must be 1–999 minutes, or tick ∞'),
        ),
      );
      return;
    }
    final initial = widget.initial;
    if (initial != null && plan == initial) {
      Navigator.pop(context);
      return;
    }
    // Sửa preset đang dùng sẽ tạo engine mới → hỏi nếu đang chạy.
    final editingActive =
        initial != null && initial.id == ref.read(activePlanProvider).id;
    if (editingActive && !await confirmInterruptTimer(context, ref)) return;

    setState(() => _saving = true);
    final repo = ref.read(presetRepositoryProvider);
    try {
      if (initial == null) {
        await repo.create(plan);
      } else {
        await repo.update(plan);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not save: $e')));
    }
  }

  /// Lưu bản sao từ nội dung đang sửa (chưa lưu cũng được) rồi đóng.
  Future<void> _duplicate() async {
    final plan = _buildPlan();
    final name = _name.text.trim();
    if (plan == null || name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fix the invalid fields before duplicating'),
        ),
      );
      return;
    }
    await ref
        .read(presetRepositoryProvider)
        .create(plan.copyWith(name: '$name (copy)'));
    if (mounted) Navigator.pop(context);
  }

  /// Xoá kèm Undo (không hỏi lại). Chỉ hỏi khi session đang chạy, vì xoá nó
  /// sẽ đặt lại timer.
  Future<void> _delete() async {
    final initial = widget.initial!;
    final isActive = initial.id == ref.read(activePlanProvider).id;
    if (isActive && !await confirmInterruptTimer(context, ref)) return;
    if (!mounted) return;
    deleteSessionWithUndo(context, initial);
    Navigator.pop(context);
  }

  void _addStep(TimerPhase phase) => setState(
    () => _steps.add(_StepDraft(phase, phase == TimerPhase.focus ? 25 : 5)),
  );

  void _removeStep(int index) {
    setState(() => _steps.removeAt(index).dispose());
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final preview = _buildPlan();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.initial == null ? 'New session' : 'Edit session'),
        actions: [
          // Nhân bản / Xoá chỉ có khi sửa session đã có.
          if (widget.initial != null) ...[
            IconButton(
              tooltip: 'Duplicate',
              onPressed: _saving ? null : _duplicate,
              icon: const Icon(Icons.content_copy_rounded),
            ),
            IconButton(
              tooltip: 'Delete',
              // Luôn giữ ít nhất 1 session.
              onPressed:
                  _saving ||
                      (ref.watch(visiblePresetsProvider).value?.length ?? 0) <=
                          1
                  ? null
                  : _delete,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          ],
          IconButton(
            tooltip: 'Save',
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 48),
            children: [
              // Tên lớn, không viền — như tiêu đề của session.
              TextField(
                controller: _name,
                autofocus: widget.initial == null,
                textCapitalization: TextCapitalization.sentences,
                style: textTheme.headlineMedium,
                decoration: InputDecoration(
                  hintText: 'Session name',
                  errorText: _nameError,
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
              const SizedBox(height: 24),
              Text('STEPS', style: textTheme.labelSmall),
              const SizedBox(height: 10),
              ReorderableListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                onReorderItem: (from, to) =>
                    setState(() => _steps.insert(to, _steps.removeAt(from))),
                children: [
                  for (var i = 0; i < _steps.length; i++)
                    _StepRow(
                      key: _steps[i].key,
                      index: i,
                      draft: _steps[i],
                      canRemove: _steps.length > 1,
                      onChanged: () => setState(() {}),
                      onRemove: () => _removeStep(i),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final phase in TimerPhase.values)
                    OutlinedButton.icon(
                      onPressed: () => _addStep(phase),
                      style: OutlinedButton.styleFrom(
                        shape: const StadiumBorder(),
                      ),
                      icon: const Icon(Icons.add_rounded),
                      label: Text(phase.label),
                    ),
                ],
              ),
              const SizedBox(height: 36),
              Text('REPEAT', style: textTheme.labelSmall),
              const SizedBox(height: 6),
              Row(
                children: [
                  IconButton.outlined(
                    tooltip: 'Fewer rounds',
                    onPressed: _repeat > 1
                        ? () => setState(() => _repeat--)
                        : null,
                    icon: const Icon(Icons.remove_rounded),
                  ),
                  SizedBox(
                    width: 96,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      transitionBuilder: (child, a) =>
                          FadeTransition(opacity: a, child: child),
                      child: Text(
                        '× $_repeat',
                        key: ValueKey(_repeat),
                        textAlign: TextAlign.center,
                        style: textTheme.displaySmall,
                      ),
                    ),
                  ),
                  IconButton.outlined(
                    tooltip: 'More rounds',
                    onPressed: _repeat < _maxRepeat
                        ? () => setState(() => _repeat++)
                        : null,
                    icon: const Icon(Icons.add_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 36),
              // Tóm tắt lớn ở cuối: đổi ngay khi sửa.
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: preview == null
                    ? Text('Some steps are invalid', style: textTheme.bodyLarge)
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('TOTAL', style: textTheme.labelSmall),
                          const SizedBox(height: 4),
                          Text(
                            describeTotal(preview),
                            style: textTheme.headlineMedium,
                          ),
                          Text(
                            describeSteps(preview),
                            style: textTheme.bodyMedium,
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    super.key,
    required this.index,
    required this.draft,
    required this.canRemove,
    required this.onChanged,
    required this.onRemove,
  });

  final int index;
  final _StepDraft draft;
  final bool canRemove;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surfaceContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        clipBehavior: Clip.antiAlias,
        padding: const EdgeInsets.fromLTRB(0, 6, 4, 6),
        child: Row(
          children: [
            // Vạch màu theo pha ở mép trái; đổi màu mượt khi đổi pha.
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 4,
              height: 36,
              margin: const EdgeInsets.only(left: 10),
              decoration: BoxDecoration(
                color: CytTheme.of(context).colorFor(draft.phase),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ReorderableDragStartListener(
              index: index,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(
                  Icons.drag_indicator_rounded,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            // Nút đổi pha: chấm màu của pha hiện tại.
            Tooltip(
              message: draft.phase == TimerPhase.focus
                  ? 'Switch to Break'
                  : 'Switch to Focus',
              child: InkResponse(
                radius: 18,
                onTap: () {
                  draft.phase = draft.phase == TimerPhase.focus
                      ? TimerPhase.rest
                      : TimerPhase.focus;
                  onChanged();
                },
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: CytTheme.of(context).colorFor(draft.phase),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            // Tên bước: để trống thì dùng tên mặc định (hiện dạng gợi ý).
            Expanded(
              child: TextField(
                controller: draft.name,
                onChanged: (_) => onChanged(),
                inputFormatters: [LengthLimitingTextInputFormatter(24)],
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: draft.phase.label,
                  hintStyle: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface.withValues(alpha: 0.55),
                  ),
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 104,
              child: TextField(
                controller: draft.minutes,
                enabled: !draft.infinite,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(3),
                ],
                textAlign: TextAlign.end,
                onChanged: (_) => onChanged(),
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
                decoration: InputDecoration(
                  isDense: true,
                  // Lề trong nhỏ để số và hậu tố không đè lên nhau.
                  contentPadding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                  suffixText: ' min',
                  suffixStyle: TextStyle(color: scheme.onSurfaceVariant),
                  errorText: draft.isValid ? null : '1–999',
                  fillColor: scheme.surfaceContainerHighest,
                ),
              ),
            ),
            // Ô tích "Vô hạn": bước chạy tới khi bấm Xong / Bỏ qua.
            Tooltip(
              message: 'Infinite — runs until you press Done',
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  draft.infinite = !draft.infinite;
                  onChanged();
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Checkbox(
                      value: draft.infinite,
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onChanged: (v) {
                        draft.infinite = v ?? false;
                        onChanged();
                      },
                    ),
                    const Text('∞', style: TextStyle(fontSize: 18)),
                    const SizedBox(width: 4),
                  ],
                ),
              ),
            ),
            IconButton(
              tooltip: 'Remove step',
              visualDensity: VisualDensity.compact,
              onPressed: canRemove ? onRemove : null,
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
      ),
    );
  }
}
