// Định dạng gói theme (theme dạng plugin).
//
// Một gói theme là một thư mục (hoặc file .zip chứa thư mục đó) gồm
// `theme.json` và các file đi kèm. Gói chỉ chứa DỮ LIỆU — app không tải hay
// chạy code từ gói (App Store cấm). Ví dụ `theme.json`:
//
// {
//   "id": "traffic-light",            // bắt buộc: [a-z0-9][a-z0-9_-]{0,63}
//   "name": "Traffic Light",          // bắt buộc
//   "version": 1,
//   "brightness": "dark",             // "dark" | "light"
//   "colors": {                       // "#RRGGBB" hoặc "#AARRGGBB"
//     "background": "#000000", "foreground": "#FFFFFF",
//     "focus": "#2BFF6B", "rest": "#FF3030",
//     "warning": "#FFC400"            // 10% thời gian cuối mỗi bước
//   },
//   "radius": 12,                     // bo góc nút / ô nhập (px)
//   "font": { "family": "monospace", "file": "fonts/x.ttf" },  // tuỳ chọn
//   "led": { "style": "solid"|"dots"|"scanlines",
//            "infinity": "chain"|"sync",   // hiệu ứng ∞ cho bước vô hạn
//            "shape": "beveled"|"rect", "offOpacity": 0.07,
//            "glow": 1.0, "slant": 0.08 },
//   "heatmap": { "empty": "#262626", "low": "#0E4429", "high": "#39D353" },
//   "sounds": { "focusEnd": "chime", "restEnd": "sounds/x.wav",
//               "complete": "complete" },  // key có sẵn hoặc file trong gói
//   "renderer": { "type": "led7", "asset": "models/clock.glb",
//                 "options": {} }   // type khác "led7" dành cho giai đoạn sau
// }
//
// Mọi đường dẫn đều tương đối so với thư mục gói và không được thoát ra
// ngoài (không "..", không tuyệt đối).

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../alerts/domain/sound_ref.dart';
import '../../timer/presentation/led_timer_display.dart';

class ThemeFormatException implements Exception {
  const ThemeFormatException(this.message);
  final String message;

  @override
  String toString() => 'Invalid theme: $message';
}

/// Nơi chứa file của một gói theme (asset kèm app hoặc thư mục đã cài).
abstract interface class ThemeSource {
  bool get isBundled;

  /// Mô tả vị trí (để hiển thị / debug).
  String get location;

  Future<Uint8List> readBytes(String relativePath);

  SoundRef soundRef(String relativePath);

  /// Đường dẫn file thật trên đĩa; null nếu là asset (renderer 3D cần).
  String? filePath(String relativePath);
}

/// Chuẩn hoá đường dẫn tương đối trong gói; null nếu không an toàn.
String? normalizeThemePath(String raw) {
  if (raw.isEmpty || raw.contains('\\') || raw.contains('\x00')) return null;
  if (p.posix.isAbsolute(raw) || raw.contains(':')) return null;
  final normalized = p.posix.normalize(raw);
  if (normalized == '.' || normalized == '..' || normalized.startsWith('../')) {
    return null;
  }
  return normalized;
}

final _idPattern = RegExp(r'^[a-z0-9][a-z0-9_-]{0,63}$');

/// Màu heatmap tuỳ chỉnh: ô trống, ít phiên nhất, nhiều phiên nhất.
@immutable
class HeatmapPalette {
  const HeatmapPalette({
    required this.empty,
    required this.low,
    required this.high,
  });

  final Color empty;
  final Color low;
  final Color high;

  static HeatmapPalette? lerp(HeatmapPalette? a, HeatmapPalette? b, double t) {
    if (a == null || b == null) return t < 0.5 ? a : b;
    return HeatmapPalette(
      empty: Color.lerp(a.empty, b.empty, t)!,
      low: Color.lerp(a.low, b.low, t)!,
      high: Color.lerp(a.high, b.high, t)!,
    );
  }
}

/// Âm thanh theo sự kiện: key có sẵn ([SoundKeys]) hoặc file trong gói.
@immutable
class ThemeSounds {
  const ThemeSounds({this.focusEnd, this.restEnd, this.complete});

  final String? focusEnd;
  final String? restEnd;
  final String? complete;
}

/// Cách vẽ đồng hồ. Hiện chỉ có "led7"; các loại khác (rive, lottie,
/// model3d...) sẽ đăng ký renderer ở giai đoạn sau.
@immutable
class RendererSpec {
  const RendererSpec({this.type = led7, this.asset, this.options = const {}});

  static const led7 = 'led7';

  final String type;

  /// File chính của renderer trong gói (ví dụ `models/clock.glb`).
  final String? asset;
  final Map<String, Object?> options;
}

@immutable
class ThemePackage {
  const ThemePackage({
    required this.id,
    required this.name,
    required this.source,
    this.version = 1,
    this.brightness = Brightness.dark,
    this.background = const Color(0xFF000000),
    this.foreground = const Color(0xFFFFFFFF),
    this.focus = const Color(0xFF2BFF6B),
    this.rest = const Color(0xFFFF3030),
    this.warning = const Color(0xFFFFC400),
    this.radius = 12,
    this.fontFamily,
    this.fontFile,
    this.led = const LedStyle(),
    this.heatmap,
    this.sounds = const ThemeSounds(),
    this.renderer = const RendererSpec(),
  });

  final String id;
  final String name;
  final int version;
  final ThemeSource source;
  final Brightness brightness;
  final Color background;
  final Color foreground;
  final Color focus;
  final Color rest;

  /// Màu "đèn vàng": 10% thời gian cuối của bước, báo sắp đổi pha.
  final Color warning;
  final double radius;

  /// Họ font dùng cho ThemeData (sau khi nạp [fontFile] nếu có).
  final String? fontFamily;
  final String? fontFile;
  final LedStyle led;
  final HeatmapPalette? heatmap;
  final ThemeSounds sounds;
  final RendererSpec renderer;

  ThemePackage withFontFamily(String? family) => ThemePackage(
    id: id,
    name: name,
    source: source,
    version: version,
    brightness: brightness,
    background: background,
    foreground: foreground,
    focus: focus,
    rest: rest,
    warning: warning,
    radius: radius,
    fontFamily: family,
    fontFile: fontFile,
    led: led,
    heatmap: heatmap,
    sounds: sounds,
    renderer: renderer,
  );

  /// Âm thanh từ một giá trị trong `sounds`: key có sẵn hoặc file trong gói.
  SoundRef? resolveSound(String? spec) {
    if (spec == null) return null;
    if (SoundKeys.all.contains(spec)) return SoundKeys.ref(spec);
    final rel = normalizeThemePath(spec);
    return rel == null ? null : source.soundRef(rel);
  }

  /// Đọc `theme.json` đã decode. Ném [ThemeFormatException] nếu sai.
  factory ThemePackage.fromJson(Object? json, ThemeSource source) {
    if (json is! Map<String, Object?>) {
      throw const ThemeFormatException('theme.json must be an object');
    }
    final id = json['id'];
    if (id is! String || !_idPattern.hasMatch(id)) {
      throw const ThemeFormatException('"id" is missing or malformed');
    }
    final name = json['name'];
    if (name is! String || name.trim().isEmpty) {
      throw const ThemeFormatException('"name" is missing');
    }
    final colors = _map(json['colors'], 'colors');
    final led = _map(json['led'], 'led');
    final font = _map(json['font'], 'font');
    final sounds = _map(json['sounds'], 'sounds');
    final renderer = _map(json['renderer'], 'renderer');
    final heatmap = json['heatmap'] == null
        ? null
        : _map(json['heatmap'], 'heatmap');

    const d = ThemePackage(id: '', name: '', source: _NoSource());
    const dl = LedStyle();
    final fontFile = _path(font['file'], 'font.file');
    return ThemePackage(
      id: id,
      name: name.trim(),
      source: source,
      version: _int(json['version'], 'version') ?? 1,
      brightness: switch (json['brightness']) {
        null || 'dark' => Brightness.dark,
        'light' => Brightness.light,
        final v => throw ThemeFormatException('"brightness" is invalid: $v'),
      },
      background: _color(colors['background'], 'background') ?? d.background,
      foreground: _color(colors['foreground'], 'foreground') ?? d.foreground,
      focus: _color(colors['focus'], 'focus') ?? d.focus,
      rest: _color(colors['rest'], 'rest') ?? d.rest,
      warning: _color(colors['warning'], 'warning') ?? d.warning,
      radius: _num(json['radius'], 'radius', 0, 48) ?? d.radius,
      fontFamily: _string(font['family'], 'font.family'),
      fontFile: fontFile,
      led: LedStyle(
        digitStyle: switch (led['style']) {
          null || 'solid' => LedDigitStyle.solid,
          'dots' => LedDigitStyle.dots,
          'scanlines' => LedDigitStyle.scanlines,
          final v => throw ThemeFormatException('"led.style" is invalid: $v'),
        },
        infinityStyle: switch (led['infinity']) {
          null || 'chain' => LedInfinityStyle.chain,
          'sync' => LedInfinityStyle.sync,
          final v => throw ThemeFormatException(
            '"led.infinity" is invalid: $v',
          ),
        },
        segmentShape: switch (led['shape']) {
          null || 'beveled' => LedSegmentShape.beveled,
          'rect' => LedSegmentShape.rect,
          final v => throw ThemeFormatException('"led.shape" is invalid: $v'),
        },
        offOpacity:
            _num(led['offOpacity'], 'offOpacity', 0, 1) ?? dl.offOpacity,
        glowStrength: _num(led['glow'], 'glow', 0, 3) ?? dl.glowStrength,
        slant: _num(led['slant'], 'slant', -0.5, 0.5) ?? dl.slant,
      ),
      heatmap: heatmap == null
          ? null
          : HeatmapPalette(
              empty: _required(_color(heatmap['empty'], 'heatmap.empty')),
              low: _required(_color(heatmap['low'], 'heatmap.low')),
              high: _required(_color(heatmap['high'], 'heatmap.high')),
            ),
      sounds: ThemeSounds(
        focusEnd: _soundSpec(sounds['focusEnd'], 'focusEnd'),
        restEnd: _soundSpec(sounds['restEnd'], 'restEnd'),
        complete: _soundSpec(sounds['complete'], 'complete'),
      ),
      renderer: RendererSpec(
        type: _string(renderer['type'], 'renderer.type') ?? RendererSpec.led7,
        asset: _path(renderer['asset'], 'renderer.asset'),
        options: renderer['options'] == null
            ? const {}
            : _map(renderer['options'], 'renderer.options'),
      ),
    );
  }

  static Map<String, Object?> _map(Object? v, String field) => switch (v) {
    null => const {},
    Map<String, Object?>() => v,
    _ => throw ThemeFormatException('"$field" must be an object'),
  };

  static String? _string(Object? v, String field) => switch (v) {
    null => null,
    String() => v,
    _ => throw ThemeFormatException('"$field" must be a string'),
  };

  static int? _int(Object? v, String field) => switch (v) {
    null => null,
    int() => v,
    _ => throw ThemeFormatException('"$field" must be an integer'),
  };

  static double? _num(Object? v, String field, double min, double max) {
    if (v == null) return null;
    if (v is! num || v < min || v > max) {
      throw ThemeFormatException('"$field" must be a number in [$min, $max]');
    }
    return v.toDouble();
  }

  static Color? _color(Object? v, String field) {
    if (v == null) return null;
    final match = v is String
        ? RegExp(r'^#([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$').firstMatch(v)
        : null;
    if (match == null) {
      throw ThemeFormatException(
        '"$field" must be a color #RRGGBB / #AARRGGBB',
      );
    }
    final hex = match.group(1)!;
    return Color(int.parse(hex.length == 6 ? 'FF$hex' : hex, radix: 16));
  }

  static String? _path(Object? v, String field) {
    final s = _string(v, field);
    if (s == null) return null;
    return normalizeThemePath(s) ??
        (throw ThemeFormatException('"$field" is not a valid path'));
  }

  static String? _soundSpec(Object? v, String field) {
    final s = _string(v, 'sounds.$field');
    if (s == null || SoundKeys.all.contains(s)) return s;
    return _path(s, 'sounds.$field');
  }

  static Color _required(Color? c) =>
      c ?? (throw const ThemeFormatException('"heatmap" is missing a color'));
}

/// Nguồn rỗng, chỉ dùng cho giá trị mặc định khi parse.
class _NoSource implements ThemeSource {
  const _NoSource();

  @override
  bool get isBundled => true;

  @override
  String get location => '';

  @override
  String? filePath(String relativePath) => null;

  @override
  Future<Uint8List> readBytes(String relativePath) =>
      throw UnsupportedError('no source');

  @override
  SoundRef soundRef(String relativePath) => throw UnsupportedError('no source');
}
