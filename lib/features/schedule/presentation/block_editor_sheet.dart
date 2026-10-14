import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../presets/application/preset_providers.dart';
import '../../presets/domain/plan_summary.dart';
import '../../presets/presentation/preset_editor_screen.dart';
import '../../themes/presentation/cyt_theme.dart';
import '../../timer/domain/timer_plan.dart';
import '../application/schedule_providers.dart';
import '../domain/task_block.dart';
import 'block_colors.dart';
import 'dial_time_picker.dart';
import 'duplicate_dialog.dart';

const _monthShort = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];
const _weekdayShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// Thời lượng chọn nhanh (phút).
const _quickDurations = [25, 50, 60, 90, 120];

/// Mở form tạo block mới (ngày [day], bắt đầu lúc [startMinute] nếu có)
/// hoặc sửa [block].
Future<void> showBlockEditor(
  BuildContext context, {
  DateTime? day,
  int? startMinute,
  TaskBlock? block,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
  ),
  builder: (_) =>
      _BlockEditor(day: day, startMinute: startMinute, block: block),
);

class _BlockEditor extends ConsumerStatefulWidget {
  const _BlockEditor({this.day, this.startMinute, this.block});

  final DateTime? day;
  final int? startMinute;
  final TaskBlock? block;

  @override
  ConsumerState<_BlockEditor> createState() => _BlockEditorState();
}

class _BlockEditorState extends ConsumerState<_BlockEditor> {
  late final _title = TextEditingController(text: widget.block?.title ?? '');
  late DateTime _day;
  late int _start;
  late int _end;
  int? _presetId;
  int? _color;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final b = widget.block;
    if (b != null) {
      _day = b.day;
      _start = b.startMinute;
      _end = b.endMinute;
      _presetId = b.presetId;
      _color = b.color;
    } else {
      final now = DateTime.now();
      final d = widget.day ?? now;
      _day = DateTime(d.year, d.month, d.day);
      final isToday = _day == DateTime(now.year, now.month, now.day);
      // Mặc định: giờ được bấm trên lịch, giờ tròn kế tiếp (hôm nay) hoặc
      // 09:00; kéo dài 1 giờ.
      _start =
          widget.startMinute ??
          (isToday ? ((now.hour + 1) * 60).clamp(0, 23 * 60) : 9 * 60);
      _end = (_start + 60).clamp(0, 24 * 60);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _day = picked);
  }

  Future<void> _pickTime({required bool start}) async {
    final minutes = start ? _start : _end;
    // Mặt đồng hồ 24h tự vẽ: vòng trong 00–11, vòng ngoài 12–23.
    final value = await showDialTimePicker(
      context,
      title: start ? 'Start time' : 'End time',
      initialMinutes: minutes,
    );
    if (value == null) return;
    setState(() {
      _error = null;
      if (start) {
        // Dời giờ bắt đầu thì giữ nguyên thời lượng.
        final length = _end - _start;
        _start = value;
        _end = (_start + length).clamp(_start + 5, 24 * 60);
      } else {
        _end = value == 0 ? 24 * 60 : value; // 00:00 = hết ngày
      }
    });
  }

  void _setDuration(int minutes) => setState(() {
    _error = null;
    _end = (_start + minutes).clamp(0, 24 * 60);
  });

  /// Tạo session mới ngay từ form block (tên lấy theo tên block) rồi chọn
  /// luôn session đó.
  Future<void> _createSession() async {
    final title = _title.text.trim();
    final id = await Navigator.push<int>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            PresetEditorScreen(initialName: title.isEmpty ? null : title),
      ),
    );
    if (id != null && mounted) setState(() => _presetId = id);
  }

  /// Block dựng từ form, hoặc null (kèm báo lỗi) nếu chưa hợp lệ.
  TaskBlock? _validated() {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Give the block a name');
      return null;
    }
    if (_end <= _start) {
      setState(() => _error = 'End time must be after start time');
      return null;
    }
    return TaskBlock(
      id: widget.block?.id,
      title: title,
      day: _day,
      startMinute: _start,
      endMinute: _end,
      presetId: _presetId,
      color: _color,
    );
  }

  /// Lưu block (tạo mới hoặc cập nhật).
  Future<void> _persist(TaskBlock block) async {
    final repo = ref.read(taskBlockRepositoryProvider);
    if (block.id == null) {
      await repo.create(block);
    } else {
      await repo.update(block);
    }
  }

  Future<void> _save() async {
    final block = _validated();
    if (block == null) return;
    setState(() => _saving = true);
    await _persist(block);
    if (mounted) Navigator.pop(context);
  }

  /// Nhân bản: lưu block đang sửa, chọn cách nhân bản, tạo các bản sao.
  Future<void> _duplicate() async {
    final block = _validated();
    if (block == null) return;
    final days = await showDuplicateDialog(context, block: block);
    if (days == null || !mounted) return;
    setState(() => _saving = true);
    await _persist(block);
    final created = await ref
        .read(taskBlockRepositoryProvider)
        .createCopies(block, days);
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    final skipped = days.length - created;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Created $created block${created == 1 ? '' : 's'}'
          '${skipped > 0 ? ' · $skipped already existed' : ''}',
        ),
      ),
    );
  }

  Future<void> _delete() async {
    await ref.read(taskBlockRepositoryProvider).delete(widget.block!.id!);
    if (mounted) Navigator.pop(context);
  }

  /// Dòng gợi ý: session dài bao lâu so với block, hoặc null nếu không có
  /// gì để nói.
  Widget? _coverageHint(BuildContext context, TimerPlan? plan, int length) {
    if (plan == null || length <= 0) return null;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (icon, text, color) = switch (plan) {
      _ when plan.hasInfinite => (
        Icons.all_inclusive_rounded,
        'Session has no time limit',
        scheme.onSurfaceVariant,
      ),
      _ when plan.totalDuration.inMinutes < length => (
        Icons.schedule_rounded,
        'Session ${formatDuration(plan.totalDuration)} · then the clock '
            'for the remaining '
            '${formatDuration(Duration(minutes: length) - plan.totalDuration)}',
        scheme.onSurfaceVariant,
      ),
      _ when plan.totalDuration.inMinutes > length => (
        Icons.warning_amber_rounded,
        'Session (${formatDuration(plan.totalDuration)}) is longer than '
            'this block',
        CytTheme.of(context).warning,
      ),
      _ => (
        Icons.check_rounded,
        'Session fills the whole block',
        scheme.onSurfaceVariant,
      ),
    };
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = CytTheme.of(context).focus;
    final presets = ref.watch(visiblePresetsProvider).value ?? const [];
    // Session đã gắn nhưng bị xoá thì coi như chưa gắn.
    final selectedPreset = presets.any((p) => p.id == _presetId)
        ? _presetId
        : null;
    final length = _end - _start;

    Widget sectionLabel(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(text, style: theme.textTheme.labelSmall),
    );

    return Padding(
      // Đẩy form lên trên bàn phím.
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Tên lớn, không viền — như tiêu đề của block.
            TextField(
              controller: _title,
              autofocus: widget.block == null,
              textCapitalization: TextCapitalization.sentences,
              style: theme.textTheme.headlineSmall,
              decoration: const InputDecoration(
                hintText: 'What will you work on?',
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 4),
              ),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: ActionChip(
                avatar: const Icon(Icons.event_outlined, size: 18),
                label: Text(
                  '${_weekdayShort[_day.weekday - 1]}, '
                  '${_monthShort[_day.month - 1]} ${_day.day}',
                ),
                onPressed: _pickDate,
                shape: const StadiumBorder(),
              ),
            ),
            const SizedBox(height: 20),

            sectionLabel('TIME'),
            // Giờ bắt đầu → kết thúc: hai ô số lớn, giữa là thời lượng.
            Row(
              children: [
                Expanded(
                  child: _TimeBox(
                    label: 'Start',
                    minutes: _start,
                    onTap: () => _pickTime(start: true),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Column(
                    children: [
                      Icon(
                        Icons.arrow_forward_rounded,
                        color: scheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 2),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Text(
                          length > 0
                              ? formatDuration(Duration(minutes: length))
                              : '—',
                          key: ValueKey(length),
                          style: theme.textTheme.labelSmall,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _TimeBox(
                    label: 'End',
                    minutes: _end,
                    onTap: () => _pickTime(start: false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Chọn nhanh thời lượng.
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final m in _quickDurations)
                  ChoiceChip(
                    label: Text(formatDuration(Duration(minutes: m))),
                    selected: length == m,
                    showCheckmark: false,
                    shape: const StadiumBorder(),
                    onSelected: (_) => _setDuration(m),
                  ),
              ],
            ),
            const SizedBox(height: 24),

            sectionLabel('SESSION'),
            // Gắn session: bấm Start lúc đang trong block là chạy luôn.
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                // Thứ tự: New session → None → các session có sẵn.
                ActionChip(
                  avatar: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('New session'),
                  shape: const StadiumBorder(),
                  onPressed: _createSession,
                ),
                ChoiceChip(
                  label: const Text('None'),
                  selected: selectedPreset == null,
                  showCheckmark: false,
                  shape: const StadiumBorder(),
                  onSelected: (_) => setState(() => _presetId = null),
                ),
                for (final p in presets)
                  ChoiceChip(
                    avatar: Icon(
                      Icons.timer_outlined,
                      size: 16,
                      color: selectedPreset == p.id ? scheme.surface : null,
                    ),
                    label: Text('${p.plan.name} · ${describeSteps(p.plan)}'),
                    selected: selectedPreset == p.id,
                    showCheckmark: false,
                    selectedColor: accent,
                    labelStyle: TextStyle(
                      color: selectedPreset == p.id ? scheme.surface : null,
                    ),
                    shape: const StadiumBorder(),
                    onSelected: (_) => setState(() => _presetId = p.id),
                  ),
              ],
            ),
            // Session so với block: ngắn hơn thì phần còn lại hiện đồng hồ.
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              child:
                  _coverageHint(
                    context,
                    presets
                        .where((p) => p.id == selectedPreset)
                        .firstOrNull
                        ?.plan,
                    length,
                  ) ??
                  const SizedBox(width: double.infinity),
            ),

            const SizedBox(height: 24),

            sectionLabel('COLOR'),
            // Xám nhạt mặc định + bảng màu.
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _ColorDot(
                  color: defaultBlockColor(context),
                  selected: _color == null,
                  tooltip: 'Default',
                  onTap: () => setState(() => _color = null),
                ),
                for (final c in blockPalette)
                  _ColorDot(
                    color: Color(c),
                    selected: _color == c,
                    onTap: () => setState(() => _color = c),
                  ),
              ],
            ),

            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              child: _error == null
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(
                        _error!,
                        style: TextStyle(color: scheme.error),
                      ),
                    ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                if (widget.block != null)
                  IconButton(
                    tooltip: 'Delete',
                    onPressed: _saving ? null : _delete,
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
                IconButton(
                  tooltip: 'Duplicate',
                  onPressed: _saving ? null : _duplicate,
                  icon: const Icon(Icons.copy_all_rounded),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    shape: const StadiumBorder(),
                    minimumSize: const Size(110, 48),
                  ),
                  child: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Một chấm màu trong bảng màu block; đang chọn thì có vòng viền + dấu tích.
class _ColorDot extends StatelessWidget {
  const _ColorDot({
    required this.color,
    required this.selected,
    required this.onTap,
    this.tooltip,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dot = GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 36,
        height: 36,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? scheme.onSurface : Colors.transparent,
            width: 2,
          ),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: selected ? 1 : 0,
            child: const Icon(
              Icons.check_rounded,
              size: 18,
              color: Colors.black,
            ),
          ),
        ),
      ),
    );
    return tooltip == null ? dot : Tooltip(message: tooltip, child: dot);
  }
}

/// Ô giờ lớn, bấm để chọn giờ.
class _TimeBox extends StatelessWidget {
  const _TimeBox({
    required this.label,
    required this.minutes,
    required this.onTap,
  });

  final String label;
  final int minutes;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: scheme.surfaceContainer,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              Text(label, style: theme.textTheme.labelSmall),
              const SizedBox(height: 2),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Text(
                  formatMinuteOfDay(minutes),
                  key: ValueKey(minutes),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
