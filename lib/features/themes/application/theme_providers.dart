import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../app/widgets/smooth_progress.dart';
import '../../../data/data_providers.dart';
import '../../timer/presentation/led_timer_display.dart';
import '../data/theme_repository.dart';
import '../domain/builtin_themes.dart';
import '../domain/theme_package.dart';

final themeRepositoryProvider = Provider<ThemeRepository>(
  (ref) => ThemeRepository(installRoot: getApplicationSupportDirectory),
);

/// Tất cả theme (kèm sẵn + đã cài). `ref.invalidate` sau khi cài / gỡ.
final themesProvider = FutureProvider<List<ThemePackage>>(
  (ref) => ref.watch(themeRepositoryProvider).loadAll(),
);

/// Giá trị chọn đặc biệt: theo sáng/tối của hệ thống
/// (sáng → "Giấy trắng", tối → "Traffic Light").
const String systemThemeId = 'system';

/// Theme đang chọn (id hoặc [systemThemeId]), lưu trong SharedPreferences.
final themeSelectionProvider = NotifierProvider<ThemeSelectionNotifier, String>(
  ThemeSelectionNotifier.new,
);

class ThemeSelectionNotifier extends Notifier<String> {
  static const _key = 'themeId';

  @override
  String build() =>
      ref.watch(sharedPreferencesProvider).getString(_key) ??
      BuiltinThemes.trafficLightId;

  Future<void> select(String id) async {
    state = id;
    await ref.read(sharedPreferencesProvider).setString(_key, id);
  }
}

/// Kiểu chữ số người dùng chọn trong Cài đặt (mặc định nét liền).
final digitStyleProvider = NotifierProvider<DigitStyleNotifier, LedDigitStyle>(
  DigitStyleNotifier.new,
);

class DigitStyleNotifier extends Notifier<LedDigitStyle> {
  static const _key = 'digitStyle';

  @override
  LedDigitStyle build() {
    final name = ref.watch(sharedPreferencesProvider).getString(_key);
    return LedDigitStyle.values.where((s) => s.name == name).firstOrNull ??
        LedDigitStyle.solid;
  }

  Future<void> select(LedDigitStyle style) async {
    state = style;
    await ref.read(sharedPreferencesProvider).setString(_key, style.name);
  }
}

/// Kiểu hiệu ứng ∞ người dùng chọn trong Cài đặt (mặc định nối tiếp).
final infinityStyleProvider =
    NotifierProvider<InfinityStyleNotifier, LedInfinityStyle>(
      InfinityStyleNotifier.new,
    );

class InfinityStyleNotifier extends Notifier<LedInfinityStyle> {
  static const _key = 'infinityStyle';

  @override
  LedInfinityStyle build() {
    final name = ref.watch(sharedPreferencesProvider).getString(_key);
    return LedInfinityStyle.values.where((s) => s.name == name).firstOrNull ??
        LedInfinityStyle.chain;
  }

  Future<void> select(LedInfinityStyle style) async {
    state = style;
    await ref.read(sharedPreferencesProvider).setString(_key, style.name);
  }
}

/// Kiểu thanh tiến trình ở màn đồng hồ (Cài đặt), mặc định đường thẳng.
final progressStyleProvider =
    NotifierProvider<ProgressStyleNotifier, ProgressStyle>(
      ProgressStyleNotifier.new,
    );

class ProgressStyleNotifier extends Notifier<ProgressStyle> {
  static const _key = 'progressStyle';

  @override
  ProgressStyle build() {
    final name = ref.watch(sharedPreferencesProvider).getString(_key);
    return ProgressStyle.values.where((s) => s.name == name).firstOrNull ??
        ProgressStyle.line;
  }

  Future<void> select(ProgressStyle style) async {
    state = style;
    await ref.read(sharedPreferencesProvider).setString(_key, style.name);
  }
}

/// Loại màu người dùng chỉnh được trong Cài đặt.
enum ClockColorKind {
  focus('Focus'),
  rest('Break'),
  warning('Ending soon');

  const ClockColorKind(this.label);
  final String label;
}

/// Màu người dùng chọn (ghi đè màu của theme); null = theo theme.
typedef ColorOverrides = ({Color? focus, Color? rest, Color? warning});

final colorOverridesProvider =
    NotifierProvider<ColorOverridesNotifier, ColorOverrides>(
      ColorOverridesNotifier.new,
    );

class ColorOverridesNotifier extends Notifier<ColorOverrides> {
  static String _key(ClockColorKind kind) => 'color_${kind.name}';

  @override
  ColorOverrides build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    Color? read(ClockColorKind kind) => switch (prefs.getInt(_key(kind))) {
      final v? => Color(v),
      null => null,
    };
    return (
      focus: read(ClockColorKind.focus),
      rest: read(ClockColorKind.rest),
      warning: read(ClockColorKind.warning),
    );
  }

  /// Đặt màu cho [kind]; [color] null = quay về màu của theme.
  Future<void> set(ClockColorKind kind, Color? color) async {
    state = (
      focus: kind == ClockColorKind.focus ? color : state.focus,
      rest: kind == ClockColorKind.rest ? color : state.rest,
      warning: kind == ClockColorKind.warning ? color : state.warning,
    );
    final prefs = ref.read(sharedPreferencesProvider);
    if (color == null) {
      await prefs.remove(_key(kind));
    } else {
      await prefs.setInt(_key(kind), color.toARGB32());
    }
  }
}

/// Kết quả chọn theme cho MaterialApp.
class ResolvedThemes {
  const ResolvedThemes({
    required this.light,
    required this.dark,
    required this.mode,
  });

  final ThemePackage light;
  final ThemePackage dark;
  final ThemeMode mode;

  /// Gói đang hiển thị khi hệ thống ở độ sáng [platform].
  ThemePackage current(Brightness platform) => switch (mode) {
    ThemeMode.light => light,
    ThemeMode.dark => dark,
    ThemeMode.system => platform == Brightness.dark ? dark : light,
  };
}

final resolvedThemesProvider = Provider<ResolvedThemes>((ref) {
  final themes = ref.watch(themesProvider).value ?? const <ThemePackage>[];
  final selection = ref.watch(themeSelectionProvider);

  ThemePackage byId(String id, ThemePackage fallback) =>
      themes.where((t) => t.id == id).firstOrNull ?? fallback;

  final dark = byId(BuiltinThemes.trafficLightId, BuiltinThemes.trafficLight);
  final light = byId(BuiltinThemes.paperId, BuiltinThemes.paper);
  if (selection == systemThemeId) {
    return ResolvedThemes(light: light, dark: dark, mode: ThemeMode.system);
  }
  // Theme đã chọn bị gỡ → quay về Traffic Light.
  final chosen = byId(selection, dark);
  return ResolvedThemes(
    light: chosen,
    dark: chosen,
    mode: chosen.brightness == Brightness.dark
        ? ThemeMode.dark
        : ThemeMode.light,
  );
});
