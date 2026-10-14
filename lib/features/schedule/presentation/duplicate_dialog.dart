import 'package:flutter/material.dart';

import '../domain/duplicate_days.dart';
import '../domain/task_block.dart';

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

String _fmtDate(DateTime d) =>
    '${_weekdayShort[d.weekday - 1]}, ${_monthShort[d.month - 1]} ${d.day}';

/// Hộp chọn cách nhân bản [block]; trả về danh sách ngày đích, hoặc null nếu
/// huỷ.
Future<List<DateTime>?> showDuplicateDialog(
  BuildContext context, {
  required TaskBlock block,
}) => showDialog<List<DateTime>>(
  context: context,
  builder: (_) => _DuplicateDialog(block: block),
);

class _DuplicateDialog extends StatefulWidget {
  const _DuplicateDialog({required this.block});

  final TaskBlock block;

  @override
  State<_DuplicateDialog> createState() => _DuplicateDialogState();
}

class _DuplicateDialogState extends State<_DuplicateDialog> {
  DuplicateMode _mode = DuplicateMode.sameWeekday;
  int _weeks = 4;
  late DateTime _date = DateTime(
    widget.block.day.year,
    widget.block.day.month,
    widget.block.day.day + 1,
  );

  List<DateTime> get _days =>
      duplicateDays(_mode, widget.block.day, weeks: _weeks, date: _date);

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _date = picked;
        _mode = DuplicateMode.anotherDay;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final b = widget.block;
    final day = b.day;
    final lastOfMonth = DateTime(day.year, day.month + 1, 0);
    final days = _days;

    // Bộ đếm số tuần: − N +.
    Widget weeksStepper() => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: _weeks > 1 ? () => setState(() => _weeks--) : null,
          icon: const Icon(Icons.remove_rounded, size: 18),
        ),
        SizedBox(
          width: 28,
          child: Text(
            '$_weeks',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
          ),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: _weeks < 52 ? () => setState(() => _weeks++) : null,
          icon: const Icon(Icons.add_rounded, size: 18),
        ),
      ],
    );

    Widget option(
      DuplicateMode mode,
      String title,
      String subtitle, {
      Widget? trailing,
      VoidCallback? onTap,
    }) {
      final selected = _mode == mode;
      return ListTile(
        contentPadding: const EdgeInsets.only(left: 4, right: 0),
        leading: Icon(
          selected
              ? Icons.radio_button_checked_rounded
              : Icons.radio_button_unchecked_rounded,
          color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: trailing,
        onTap: onTap ?? () => setState(() => _mode = mode),
      );
    }

    return AlertDialog(
      title: Text('Duplicate “${b.title}”'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${formatMinuteOfDay(b.startMinute)} – '
                '${formatMinuteOfDay(b.endMinute)} · from ${_fmtDate(day)}',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              option(
                DuplicateMode.anotherDay,
                'Another day',
                _fmtDate(_date),
                onTap: _pickDate,
                trailing: IconButton(
                  tooltip: 'Pick a date',
                  onPressed: _pickDate,
                  icon: const Icon(Icons.event_outlined),
                ),
              ),
              option(
                DuplicateMode.restOfWeek,
                'Rest of this week',
                day.weekday == DateTime.sunday
                    ? 'Already the last day of the week'
                    : 'Until Sunday',
              ),
              option(
                DuplicateMode.sameWeekday,
                'Every ${_weekdayShort[day.weekday - 1]}',
                'For the next $_weeks week${_weeks == 1 ? '' : 's'}',
                trailing: _mode == DuplicateMode.sameWeekday
                    ? weeksStepper()
                    : null,
              ),
              option(
                DuplicateMode.restOfMonth,
                'Every day this month',
                'Until ${_fmtDate(lastOfMonth)}',
              ),
              option(
                DuplicateMode.weekdays,
                'Weekdays only',
                'Mon – Fri, next $_weeks week${_weeks == 1 ? '' : 's'}',
                trailing: _mode == DuplicateMode.weekdays
                    ? weeksStepper()
                    : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: days.isEmpty ? null : () => Navigator.pop(context, days),
          style: FilledButton.styleFrom(shape: const StadiumBorder()),
          child: Text(
            days.isEmpty
                ? 'Duplicate'
                : 'Create ${days.length} block${days.length == 1 ? '' : 's'}',
          ),
        ),
      ],
    );
  }
}
