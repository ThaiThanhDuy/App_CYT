import 'package:flutter/material.dart';

import '../../timer/domain/timer_phase.dart';
import '../../timer/presentation/led_timer_display.dart';
import '../domain/builtin_themes.dart';
import '../domain/theme_package.dart';

/// Phần riêng của CYT gắn vào [ThemeData]: màu pha, kiểu LED, heatmap,
/// renderer. Nội suy được nên MaterialApp đổi theme mượt.
@immutable
class CytTheme extends ThemeExtension<CytTheme> {
  const CytTheme({
    required this.package,
    required this.focus,
    required this.rest,
    required this.warning,
    required this.led,
    this.heatmap,
  });

  factory CytTheme.fromPackage(ThemePackage package) => CytTheme(
    package: package,
    focus: package.focus,
    rest: package.rest,
    warning: package.warning,
    led: package.led,
    heatmap: package.heatmap,
  );

  /// Gói đang áp dụng (cho renderer: spec + nguồn asset).
  final ThemePackage package;
  final Color focus;
  final Color rest;

  /// Màu "đèn vàng" cho 10% thời gian cuối mỗi bước.
  final Color warning;
  final LedStyle led;
  final HeatmapPalette? heatmap;

  static final fallback = CytTheme.fromPackage(BuiltinThemes.trafficLight);

  static CytTheme of(BuildContext context) =>
      Theme.of(context).extension<CytTheme>() ?? fallback;

  Color colorFor(TimerPhase phase) => switch (phase) {
    TimerPhase.focus => focus,
    TimerPhase.rest => rest,
  };

  /// Màu đồng hồ: vàng khi sắp hết bước ([ending]), còn lại theo pha.
  Color clockColor(TimerPhase phase, {required bool ending}) =>
      ending ? warning : colorFor(phase);

  @override
  CytTheme copyWith({
    ThemePackage? package,
    Color? focus,
    Color? rest,
    Color? warning,
    LedStyle? led,
    HeatmapPalette? heatmap,
  }) => CytTheme(
    package: package ?? this.package,
    focus: focus ?? this.focus,
    rest: rest ?? this.rest,
    warning: warning ?? this.warning,
    led: led ?? this.led,
    heatmap: heatmap ?? this.heatmap,
  );

  @override
  CytTheme lerp(covariant CytTheme? other, double t) {
    if (other == null) return this;
    return CytTheme(
      package: t < 0.5 ? package : other.package,
      focus: Color.lerp(focus, other.focus, t)!,
      rest: Color.lerp(rest, other.rest, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      led: LedStyle.lerp(led, other.led, t),
      heatmap: HeatmapPalette.lerp(heatmap, other.heatmap, t),
    );
  }
}

/// Dựng [ThemeData] từ một gói theme theo hướng tối giản: nền/chữ theo gói
/// (mặc định đen trắng), các lớp nền chỉ là pha trộn nền ↔ chữ, chữ số lớn
/// nét mảnh, chuyển trang dạng fade, bo góc theo gói, và gắn [CytTheme].
///
/// [digitStyle], [infinityStyle]: lựa chọn trong Cài đặt (ghi đè kiểu của
/// gói); null = giữ kiểu của gói (dùng cho ô xem trước theme).
///
/// [focus], [rest], [warning]: màu người dùng chọn; null = màu của gói.
ThemeData buildThemeData(
  ThemePackage package, {
  LedDigitStyle? digitStyle,
  LedInfinityStyle? infinityStyle,
  Color? focus,
  Color? rest,
  Color? warning,
}) {
  final background = package.background;
  final foreground = package.foreground;
  final dark = package.brightness == Brightness.dark;
  // Các tầng nền đơn sắc: càng "cao" càng nghiêng về màu chữ.
  Color tone(double t) => Color.lerp(background, foreground, t)!;

  final scheme =
      ColorScheme.fromSeed(
        seedColor: foreground,
        brightness: package.brightness,
        dynamicSchemeVariant: DynamicSchemeVariant.monochrome,
      ).copyWith(
        primary: foreground,
        onPrimary: background,
        secondary: foreground,
        onSecondary: background,
        surface: background,
        onSurface: foreground,
        onSurfaceVariant: tone(0.6),
        surfaceContainerLowest: tone(0.02),
        surfaceContainerLow: tone(dark ? 0.045 : 0.035),
        surfaceContainer: tone(dark ? 0.07 : 0.05),
        surfaceContainerHigh: tone(dark ? 0.1 : 0.075),
        surfaceContainerHighest: tone(dark ? 0.14 : 0.1),
        outline: tone(0.35),
        outlineVariant: tone(dark ? 0.16 : 0.12),
        inverseSurface: foreground,
        onInverseSurface: background,
      );

  final radius = BorderRadius.circular(package.radius);
  final shape = RoundedRectangleBorder(borderRadius: radius);
  final base = ThemeData(
    colorScheme: scheme,
    brightness: package.brightness,
    fontFamily: package.fontFamily,
  );
  // Số lớn nét mảnh, tiêu đề đậm vừa; khoảng chữ hơi khít cho cỡ lớn.
  final text = base.textTheme.copyWith(
    displayLarge: base.textTheme.displayLarge?.copyWith(
      fontWeight: FontWeight.w200,
      letterSpacing: -1.5,
    ),
    displayMedium: base.textTheme.displayMedium?.copyWith(
      fontWeight: FontWeight.w200,
      letterSpacing: -1,
    ),
    displaySmall: base.textTheme.displaySmall?.copyWith(
      fontWeight: FontWeight.w300,
      letterSpacing: -0.5,
    ),
    headlineMedium: base.textTheme.headlineMedium?.copyWith(
      fontWeight: FontWeight.w300,
    ),
    headlineSmall: base.textTheme.headlineSmall?.copyWith(
      fontWeight: FontWeight.w600,
      letterSpacing: -0.3,
    ),
    titleLarge: base.textTheme.titleLarge?.copyWith(
      fontWeight: FontWeight.w600,
      letterSpacing: -0.2,
    ),
    labelSmall: base.textTheme.labelSmall?.copyWith(
      letterSpacing: 1.2,
      color: scheme.onSurfaceVariant,
    ),
    bodySmall: base.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    ),
  );

  return base.copyWith(
    textTheme: text,
    scaffoldBackgroundColor: background,
    canvasColor: background,
    splashFactory: InkSparkle.splashFactory,
    pageTransitionsTheme: PageTransitionsTheme(
      builders: {
        for (final platform in TargetPlatform.values)
          platform: const FadeForwardsPageTransitionsBuilder(),
      },
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: background,
      foregroundColor: foreground,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: text.titleLarge?.copyWith(color: foreground),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: shape,
        minimumSize: const Size(64, 48),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        textStyle: text.labelLarge?.copyWith(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: shape,
        minimumSize: const Size(64, 48),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(shape: shape),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: foreground,
      foregroundColor: background,
      elevation: 0,
      highlightElevation: 0,
      shape: const StadiumBorder(),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainer,
      border: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: foreground, width: 1.2),
      ),
    ),
    dialogTheme: DialogThemeData(
      shape: shape,
      backgroundColor: scheme.surfaceContainerHigh,
    ),
    popupMenuTheme: PopupMenuThemeData(
      shape: shape,
      color: scheme.surfaceContainerHigh,
      elevation: 0,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: foreground,
      contentTextStyle: text.bodyMedium?.copyWith(color: background),
      shape: shape,
      elevation: 0,
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: scheme.inverseSurface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(6),
      ),
      textStyle: text.bodySmall?.copyWith(color: background),
      waitDuration: const Duration(milliseconds: 400),
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant,
      thickness: 0.6,
      space: 32,
    ),
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 20),
      minVerticalPadding: 12,
    ),
    checkboxTheme: CheckboxThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    ),
    extensions: [
      CytTheme.fromPackage(package).copyWith(
        focus: focus,
        rest: rest,
        warning: warning,
        led: package.led.copyWith(
          digitStyle: digitStyle,
          infinityStyle: infinityStyle,
        ),
      ),
    ],
  );
}
