import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/data_providers.dart';

/// Gọi phần native (Android/iOS) để giữ màn hình sáng và chỉnh độ sáng của
/// app. Nền tảng không hỗ trợ (Linux…) thì bỏ qua lặng lẽ.
abstract final class ScreenControl {
  static const _channel = MethodChannel('cyt/screen');

  /// Giữ màn hình không tự tắt khi [on].
  static Future<void> keepOn(bool on) => _call('keepOn', on);

  /// Độ sáng 0–1; null = trả về độ sáng hệ thống.
  static Future<void> setBrightness(double? value) =>
      _call('setBrightness', value ?? -1.0);

  static Future<void> _call(String method, Object arguments) async {
    try {
      await _channel.invokeMethod<void>(method, arguments);
    } on MissingPluginException {
      // Desktop: chỉ có lớp phủ tối trong app.
    } on PlatformException catch (e) {
      debugPrint('ScreenControl.$method: $e');
    }
  }
}

/// Chế độ tiết kiệm pin (lưu trong SharedPreferences, mặc định tắt).
final batterySaverProvider = NotifierProvider<BatterySaverNotifier, bool>(
  BatterySaverNotifier.new,
);

class BatterySaverNotifier extends Notifier<bool> {
  static const _key = 'batterySaver';

  @override
  bool build() => ref.watch(sharedPreferencesProvider).getBool(_key) ?? false;

  Future<void> set(bool enabled) async {
    state = enabled;
    await ref.read(sharedPreferencesProvider).setBool(_key, enabled);
  }
}
