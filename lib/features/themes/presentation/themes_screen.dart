import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../timer/domain/timer_phase.dart';
import '../../timer/presentation/renderers/timer_renderer.dart';
import '../../timer/domain/timer_engine.dart';
import '../application/theme_providers.dart';
import '../domain/builtin_themes.dart';
import '../domain/theme_package.dart';
import 'cyt_theme.dart';

enum _ImportKind { zip, folder }

/// Chọn / nhập / gỡ gói theme.
class ThemesScreen extends ConsumerStatefulWidget {
  const ThemesScreen({super.key});

  @override
  ConsumerState<ThemesScreen> createState() => _ThemesScreenState();
}

class _ThemesScreenState extends ConsumerState<ThemesScreen> {
  bool _busy = false;

  void _snack(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  Future<void> _import(_ImportKind kind) async {
    final repo = ref.read(themeRepositoryProvider);
    try {
      final path = switch (kind) {
        _ImportKind.zip => (await FilePicker.pickFile(
          dialogTitle: 'Choose a theme file (.zip)',
          type: FileType.custom,
          allowedExtensions: const ['zip'],
        ))?.path,
        _ImportKind.folder => await FilePicker.getDirectoryPath(
          dialogTitle: 'Choose a theme folder (with theme.json)',
        ),
      };
      if (path == null) return;
      setState(() => _busy = true);
      final theme = switch (kind) {
        _ImportKind.zip => await repo.installFromZip(path),
        _ImportKind.folder => await repo.installFromDirectory(path),
      };
      ref.invalidate(themesProvider);
      await ref.read(themesProvider.future);
      await ref.read(themeSelectionProvider.notifier).select(theme.id);
      _snack('Installed and applied "${theme.name}"');
    } on ThemeFormatException catch (e) {
      _snack(e.toString());
    } catch (e) {
      _snack('Could not import theme: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _uninstall(ThemePackage theme) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove theme?'),
        content: Text('"${theme.name}" will be removed from this device.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(themeRepositoryProvider).uninstall(theme);
      ref.invalidate(themesProvider);
    } catch (e) {
      _snack('Could not remove: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final themesAsync = ref.watch(themesProvider);
    final selection = ref.watch(themeSelectionProvider);
    final notifier = ref.read(themeSelectionProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Appearance'),
        actions: [
          PopupMenuButton<_ImportKind>(
            tooltip: 'Import theme',
            enabled: !_busy,
            icon: const Icon(Icons.file_download_outlined),
            onSelected: _import,
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: _ImportKind.zip,
                child: Text('Import from .zip file'),
              ),
              PopupMenuItem(
                value: _ImportKind.folder,
                child: Text('Import from folder'),
              ),
            ],
          ),
        ],
        bottom: _busy
            ? const PreferredSize(
                preferredSize: Size.fromHeight(2),
                child: LinearProgressIndicator(minHeight: 2),
              )
            : null,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: switch (themesAsync) {
            AsyncError(:final error) => Center(child: Text('Error: $error')),
            AsyncData(value: final themes) => ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _SystemTile(
                  selected: selection == systemThemeId,
                  onTap: () => notifier.select(systemThemeId),
                ),
                const Divider(),
                for (final theme in themes)
                  _ThemeTile(
                    theme: theme,
                    selected: selection == theme.id,
                    onTap: () => notifier.select(theme.id),
                    onUninstall: theme.source.isBundled
                        ? null
                        : () => _uninstall(theme),
                  ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 32),
                  child: Text(
                    'A theme is a data package (theme.json + images, sounds, '
                    'models…) as a folder or .zip. The app never runs code '
                    'from themes.',
                  ),
                ),
              ],
            ),
            _ => const Center(child: CircularProgressIndicator()),
          },
        ),
      ),
    );
  }
}

class _SystemTile extends StatelessWidget {
  const _SystemTile({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
      ),
      title: const Text('Follow system'),
      subtitle: Text(
        'Light: ${BuiltinThemes.paper.name} · Dark: '
        '${BuiltinThemes.trafficLight.name}',
      ),
      trailing: const Icon(Icons.brightness_auto_outlined),
    );
  }
}

class _ThemeTile extends StatelessWidget {
  const _ThemeTile({
    required this.theme,
    required this.selected,
    required this.onTap,
    this.onUninstall,
  });

  final ThemePackage theme;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onUninstall;

  @override
  Widget build(BuildContext context) {
    final unsupported = !TimerRendererRegistry.supports(theme.renderer.type);
    final details = [
      if (theme.source.isBundled) 'Built-in' else 'Installed',
      if (theme.brightness == Brightness.dark) 'Dark' else 'Light',
      if (unsupported)
        'Renderer "${theme.renderer.type}" not supported yet → LED',
    ].join(' · ');
    return ListTile(
      onTap: onTap,
      leading: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
      ),
      title: Text(theme.name),
      subtitle: Text(details),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ThemePreview(theme: theme),
          if (onUninstall != null)
            IconButton(
              tooltip: 'Remove theme',
              onPressed: onUninstall,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
    );
  }
}

/// Ô xem trước nhỏ: nền theme + đồng hồ "25:00" vẽ bằng renderer của theme.
class _ThemePreview extends StatelessWidget {
  const _ThemePreview({required this.theme});

  final ThemePackage theme;

  @override
  Widget build(BuildContext context) {
    final data = buildThemeData(theme);
    return Theme(
      data: data,
      child: Container(
        width: 148,
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: theme.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: TimerView(
                state: const TimerVisualState(
                  remaining: Duration(minutes: 25),
                  phase: TimerPhase.focus,
                  status: TimerStatus.idle,
                  progress: 0,
                  colonOn: true,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: theme.rest,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
