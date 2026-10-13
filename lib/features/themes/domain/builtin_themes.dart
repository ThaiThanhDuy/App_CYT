import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../alerts/domain/sound_ref.dart';
import '../../timer/presentation/led_timer_display.dart';
import 'theme_package.dart';

/// Bản Dart của 2 theme kèm sẵn, dùng khi gói trong assets chưa nạp xong
/// (khung hình đầu tiên, widget test). Giữ khớp với
/// `assets/themes/*/theme.json`.
abstract final class BuiltinThemes {
  static const trafficLightId = 'traffic-light';
  static const paperId = 'paper';

  static const trafficLight = ThemePackage(
    id: trafficLightId,
    name: 'Traffic Light',
    source: _BuiltinSource('assets/themes/traffic_light'),
    brightness: Brightness.dark,
    background: Color(0xFF000000),
    foreground: Color(0xFFFFFFFF),
    focus: Color(0xFF2BFF6B),
    rest: Color(0xFFFF3030),
  );

  static const paper = ThemePackage(
    id: paperId,
    name: 'Paper',
    source: _BuiltinSource('assets/themes/paper'),
    brightness: Brightness.light,
    background: Color(0xFFFFFFFF),
    foreground: Color(0xFF000000),
    // Đậm hơn bản gốc để đọc rõ trên nền trắng.
    focus: Color(0xFF0A9F3E),
    rest: Color(0xFFE02424),
    // Vàng đậm để đọc rõ trên nền trắng.
    warning: Color(0xFFD99A00),
    led: LedStyle(offOpacity: 0.08, glowStrength: 0),
  );
}

class _BuiltinSource implements ThemeSource {
  const _BuiltinSource(this.location);

  @override
  final String location;

  @override
  bool get isBundled => true;

  @override
  String? filePath(String relativePath) => null;

  @override
  Future<Uint8List> readBytes(String relativePath) =>
      throw UnsupportedError('Built-in themes have no bundled files');

  @override
  SoundRef soundRef(String relativePath) =>
      AssetSoundRef('$location/$relativePath');
}
