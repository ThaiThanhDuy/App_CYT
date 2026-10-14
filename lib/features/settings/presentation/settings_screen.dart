import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../app/widgets/smooth_progress.dart';

import '../../backup/presentation/backup_section.dart';
import '../../power/application/screen_control.dart';
import '../../power/presentation/power_saver.dart';
import '../../themes/application/theme_providers.dart';
import '../../themes/presentation/cyt_theme.dart';
import '../../themes/presentation/themes_screen.dart';
import '../../timer/presentation/led_timer_display.dart';

/// Cài đặt chung (mở từ icon bánh răng ở màn chính).
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(themeSelectionProvider);
    final themes = ref.watch(themesProvider).value ?? const [];
    final themeName = selection == systemThemeId
        ? 'Follow system'
        : themes.where((t) => t.id == selection).firstOrNull?.name ?? selection;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            children: [
              ListTile(
                leading: const Icon(Icons.palette_outlined),
                title: const Text('Appearance'),
                subtitle: Text(themeName),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(builder: (_) => const ThemesScreen()),
                ),
              ),
              const _ColorsSection(),
              const _DigitStyleSection(),
              const _InfinityStyleSection(),
              const _ProgressStyleSection(),
              const _BatterySaverTile(),
              const Divider(),
              const BackupSection(),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('About'),
                onTap: () => showDialog<void>(
                  context: context,
                  builder: (_) => const _AboutDialog(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tiết kiệm pin: màn đồng hồ tối sau 5 phút không chạm, sáng lại khi chạm
/// hoặc khi chuyển focus ↔ break.
class _BatterySaverTile extends ConsumerWidget {
  const _BatterySaverTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(batterySaverProvider);
    return SwitchListTile(
      secondary: const Icon(Icons.battery_saver_outlined),
      title: const Text('Battery saver'),
      subtitle: Text(
        'Clock screens dim after ${powerSaverIdle.inMinutes} min without '
        'touch. Tap to wake; lights up when focus and break switch.',
      ),
      value: enabled,
      onChanged: (v) => ref.read(batterySaverProvider.notifier).set(v),
    );
  }
}

/// Chọn kiểu chữ số: nét liền / chấm LED / sọc ngang.
class _DigitStyleSection extends ConsumerWidget {
  const _DigitStyleSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(digitStyleProvider);
    final notifier = ref.read(digitStyleProvider.notifier);
    final cyt = CytTheme.of(context);
    final themeStyle = cyt.package.led;

    Widget option(LedDigitStyle style) {
      final isSelected = selected == style;
      return ListTile(
        onTap: () => notifier.select(style),
        leading: Icon(
          isSelected
              ? Icons.radio_button_checked
              : Icons.radio_button_unchecked,
        ),
        title: Text(style.label),
        trailing: SizedBox(
          width: 148,
          height: 56,
          child: LedTimerDisplay(
            remaining: const Duration(minutes: 25),
            color: cyt.focus,
            style: themeStyle.copyWith(digitStyle: style),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
          child: Text(
            'DIGIT STYLE',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ),
        for (final style in LedDigitStyle.values) option(style),
        const Divider(),
      ],
    );
  }
}

/// Chọn kiểu hiệu ứng ∞ cho bước vô hạn, có xem trước chạy động.
class _InfinityStyleSection extends ConsumerWidget {
  const _InfinityStyleSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(infinityStyleProvider);
    final notifier = ref.read(infinityStyleProvider.notifier);
    final cyt = CytTheme.of(context);

    Widget option(LedInfinityStyle style) {
      final isSelected = selected == style;
      return ListTile(
        onTap: () => notifier.select(style),
        leading: Icon(
          isSelected
              ? Icons.radio_button_checked
              : Icons.radio_button_unchecked,
        ),
        title: Text(style.label),
        subtitle: switch (style) {
          LedInfinityStyle.chain => const Text(
            'One line runs through all 4 digits',
          ),
          LedInfinityStyle.sync => const Text(
            'All 4 digits trace the 8 together',
          ),
        },
        trailing: SizedBox(
          width: 148,
          height: 56,
          child: LedTimerDisplay(
            remaining: Duration.zero,
            color: cyt.focus,
            infinite: true,
            // Giữ kiểu chữ số đang dùng, chỉ đổi kiểu hiệu ứng.
            style: cyt.led.copyWith(infinityStyle: style),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
          child: Text(
            'INFINITY ANIMATION (∞)',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ),
        for (final style in LedInfinityStyle.values) option(style),
        const Divider(),
      ],
    );
  }
}

/// Chọn kiểu thanh tiến trình (màn đồng hồ, chế độ zen), có xem trước.
class _ProgressStyleSection extends ConsumerWidget {
  const _ProgressStyleSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(progressStyleProvider);
    final notifier = ref.read(progressStyleProvider.notifier);
    final theme = Theme.of(context);
    final cyt = CytTheme.of(context);

    Widget option(ProgressStyle style) => ListTile(
      onTap: () => notifier.select(style),
      leading: Icon(
        selected == style
            ? Icons.radio_button_checked
            : Icons.radio_button_unchecked,
      ),
      title: Text(style.label),
      trailing: SizedBox(
        width: 148,
        height: 56,
        child: Center(
          child: SmoothProgress(
            value: 0.6,
            color: cyt.focus,
            height: 4,
            trackColor: theme.colorScheme.surfaceContainerHigh,
            style: style,
            barHeight: 28,
            animate: true,
          ),
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
          child: Text('PROGRESS BAR', style: theme.textTheme.labelSmall),
        ),
        for (final style in ProgressStyle.values) option(style),
        const Divider(),
      ],
    );
  }
}

/// Màu gợi ý: hàng trên sáng (hợp nền tối), hàng dưới đậm (hợp nền sáng).
const _palette = [
  Color(0xFF2BFF6B), // xanh lá (mặc định focus)
  Color(0xFF00E5A0),
  Color(0xFF00E5FF),
  Color(0xFF2F80FF),
  Color(0xFF9B5CFF),
  Color(0xFFFF4FA3),
  Color(0xFFFF3030), // đỏ (mặc định break)
  Color(0xFFFF7A1A),
  Color(0xFFFFC400), // vàng (mặc định ending soon)
  Color(0xFFFFFFFF),
  Color(0xFF0A9F3E),
  Color(0xFF00897B),
  Color(0xFF0277BD),
  Color(0xFF1E4FD8),
  Color(0xFF6A3FD6),
  Color(0xFFC2185B),
  Color(0xFFE02424),
  Color(0xFFD9560B),
  Color(0xFFD99A00),
  Color(0xFF111111),
];

String _hex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

/// Chọn màu Focus / Break / Ending soon (ghi đè màu của theme).
class _ColorsSection extends ConsumerWidget {
  const _ColorsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overrides = ref.watch(colorOverridesProvider);
    final notifier = ref.read(colorOverridesProvider.notifier);
    // Màu đang áp dụng (đã gộp lựa chọn) và màu mặc định của theme.
    final cyt = CytTheme.of(context);
    final defaults = cyt.package;
    final theme = Theme.of(context);
    final anyCustom =
        overrides.focus != null ||
        overrides.rest != null ||
        overrides.warning != null;

    Widget row(ClockColorKind kind) {
      final (current, custom, fallback) = switch (kind) {
        ClockColorKind.focus => (cyt.focus, overrides.focus, defaults.focus),
        ClockColorKind.rest => (cyt.rest, overrides.rest, defaults.rest),
        ClockColorKind.warning => (
          cyt.warning,
          overrides.warning,
          defaults.warning,
        ),
      };
      return ListTile(
        onTap: () async {
          final result = await showDialog<_ColorChoice>(
            context: context,
            builder: (_) => _ColorPickerDialog(
              title: '${kind.label} color',
              initial: current,
              defaultColor: fallback,
            ),
          );
          if (result != null) await notifier.set(kind, result.color);
        },
        title: Text(kind.label),
        subtitle: Text(custom == null ? 'Default' : _hex(custom)),
        trailing: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: current,
            shape: BoxShape.circle,
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 12, 0),
          child: Row(
            children: [
              Text('COLORS', style: theme.textTheme.labelSmall),
              const Spacer(),
              // Đưa cả 3 màu về mặc định (xanh / đỏ / vàng của theme).
              TextButton(
                onPressed: anyCustom
                    ? () async {
                        for (final kind in ClockColorKind.values) {
                          await notifier.set(kind, null);
                        }
                      }
                    : null,
                child: const Text('Reset'),
              ),
            ],
          ),
        ),
        for (final kind in ClockColorKind.values) row(kind),
      ],
    );
  }
}

/// Kết quả hộp chọn màu: [color] null = quay về mặc định.
typedef _ColorChoice = ({Color? color});

class _ColorPickerDialog extends StatefulWidget {
  const _ColorPickerDialog({
    required this.title,
    required this.initial,
    required this.defaultColor,
  });

  final String title;
  final Color initial;
  final Color defaultColor;

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  late Color _color = widget.initial;
  late final _hexField = TextEditingController(text: _hex(widget.initial));
  bool _hexValid = true;

  @override
  void dispose() {
    _hexField.dispose();
    super.dispose();
  }

  void _pick(Color c) => setState(() {
    _color = c;
    _hexValid = true;
    _hexField.text = _hex(c);
  });

  void _onHex(String text) {
    final m = RegExp(r'^#?([0-9a-fA-F]{6})$').firstMatch(text.trim());
    setState(() {
      _hexValid = m != null;
      if (m != null) _color = Color(0xFF000000 | int.parse(m[1]!, radix: 16));
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Xem trước bằng đúng kiểu chữ số đang dùng.
            Container(
              height: 72,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: LedTimerDisplay(
                  remaining: const Duration(minutes: 25),
                  color: _color,
                  style: CytTheme.of(context).led,
                  colorTransition: const Duration(milliseconds: 250),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final c in _palette)
                  _Swatch(
                    color: c,
                    selected: c.toARGB32() == _color.toARGB32(),
                    onTap: () => _pick(c),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _hexField,
              onChanged: _onHex,
              inputFormatters: [LengthLimitingTextInputFormatter(7)],
              decoration: InputDecoration(
                labelText: 'Hex',
                hintText: '#RRGGBB',
                errorText: _hexValid ? null : 'Use #RRGGBB',
                isDense: true,
              ),
            ),
          ],
        ),
      ),
      actions: [
        // Về màu mặc định (xanh / đỏ / vàng của theme).
        TextButton(
          onPressed: () => Navigator.pop(context, (color: null)),
          child: Text('Reset', style: TextStyle(color: widget.defaultColor)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _hexValid
              ? () => Navigator.pop(context, (color: _color))
              : null,
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkResponse(
      onTap: onTap,
      radius: 22,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? scheme.onSurface : scheme.outlineVariant,
            width: selected ? 2.5 : 1,
          ),
        ),
      ),
    );
  }
}

const _appName = 'Counting Your Time';
const _author = 'hnp.';

/// Hộp thoại About: icon app, version (đọc từ bản build) và tác giả.
class _AboutDialog extends StatelessWidget {
  const _AboutDialog();

  static Widget _appIcon(double size) => ClipRRect(
    borderRadius: BorderRadius.circular(size * 0.22),
    child: Image.asset(
      'assets/icon/app_icon_256.png',
      width: size,
      height: size,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        // version trong pubspec.yaml, vd. "1.0.0".
        final version = snapshot.data?.version;
        final versionLabel = version == null ? '…' : 'v$version';
        return AlertDialog(
          title: Row(
            children: [
              _appIcon(44),
              const SizedBox(width: 14),
              const Expanded(child: Text(_appName)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AboutRow(
                icon: Icons.description_outlined,
                text: versionLabel,
                tooltip: 'Version',
              ),
              const SizedBox(height: 10),
              const _AboutRow(
                icon: Icons.person_outline_rounded,
                text: 'Made by $_author',
                tooltip: 'Author',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => showLicensePage(
                context: context,
                applicationName: _appName,
                applicationVersion: version == null ? null : versionLabel,
                applicationIcon: Padding(
                  padding: const EdgeInsets.all(8),
                  child: _appIcon(56),
                ),
              ),
              child: const Text('View licenses'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
          contentTextStyle: theme.textTheme.bodyLarge,
        );
      },
    );
  }
}

class _AboutRow extends StatelessWidget {
  const _AboutRow({
    required this.icon,
    required this.text,
    required this.tooltip,
  });

  final IconData icon;
  final String text;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      children: [
        Tooltip(
          message: tooltip,
          child: Icon(icon, size: 20, color: muted),
        ),
        const SizedBox(width: 12),
        Text(text),
      ],
    );
  }
}
