import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_restarter.dart';
import '../../../data/data_providers.dart';
import '../data/backup_service.dart';

/// Mục "Backup" trong Cài đặt: xuất / nạp toàn bộ cấu hình ra file JSON để
/// chuyển sang máy khác hoặc cài lại app.
class BackupSection extends ConsumerStatefulWidget {
  const BackupSection({super.key});

  @override
  ConsumerState<BackupSection> createState() => _BackupSectionState();
}

class _BackupSectionState extends ConsumerState<BackupSection> {
  bool _busy = false;

  BackupService get _service => BackupService(
    ref.read(appDatabaseProvider),
    ref.read(sharedPreferencesProvider),
  );

  void _snack(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  Future<void> _export() async {
    setState(() => _busy = true);
    try {
      final json = await _service.exportJson();
      final now = DateTime.now();
      String two(int v) => v.toString().padLeft(2, '0');
      final saved = await FilePicker.saveFile(
        dialogTitle: 'Save backup',
        fileName:
            'cyt-backup-${now.year}-${two(now.month)}-${two(now.day)}.json',
        bytes: utf8.encode(json),
        mimeType: 'application/json',
        type: FileType.custom,
        allowedExtensions: const ['json'],
      );
      if (saved != null) _snack('Backup saved');
    } catch (e) {
      _snack('Could not export: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    try {
      final file = await FilePicker.pickFile(
        dialogTitle: 'Choose a backup file (.json)',
        type: FileType.custom,
        allowedExtensions: const ['json'],
      );
      if (file == null || !mounted) return;
      final data = BackupService.parse(utf8.decode(await file.readAsBytes()));
      final s = BackupService.summarize(data);
      if (!mounted) return;
      final ok = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: const Text('Restore backup?'),
          content: Text(
            'This replaces everything on this device with the backup:\n\n'
            '• ${s.sessions} sessions\n'
            '• ${s.blocks} schedule blocks\n'
            '• ${s.history} focus records\n'
            '• ${s.settings} settings\n\n'
            'A running timer will be stopped.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialog, true),
              style: FilledButton.styleFrom(shape: const StadiumBorder()),
              child: const Text('Restore'),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
      setState(() => _busy = true);
      await _service.restore(data);
      if (!mounted) return;
      // Dựng lại app để mọi màn đọc cài đặt / dữ liệu mới.
      AppRestarter.restart(context);
    } on BackupFormatException catch (e) {
      _snack(e.message);
    } catch (e) {
      _snack('Could not import: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
          child: Text('BACKUP', style: Theme.of(context).textTheme.labelSmall),
        ),
        ListTile(
          leading: const Icon(Icons.upload_file_outlined),
          title: const Text('Export'),
          subtitle: const Text(
            'Save sessions, schedule, history and settings to a file',
          ),
          enabled: !_busy,
          onTap: _export,
        ),
        ListTile(
          leading: const Icon(Icons.download_outlined),
          title: const Text('Import'),
          subtitle: const Text('Restore from a backup file'),
          enabled: !_busy,
          onTap: _import,
          trailing: _busy
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : null,
        ),
      ],
    );
  }
}
