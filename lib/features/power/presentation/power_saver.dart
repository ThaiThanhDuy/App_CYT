import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../timer/application/timer_providers.dart';
import '../application/screen_control.dart';

/// Không chạm bao lâu thì làm tối màn hình.
const Duration powerSaverIdle = Duration(minutes: 5);

/// Độ sáng khi tối (0–1) và độ phủ đen trong app: mờ nhưng vẫn đọc được
/// số (0.01 + phủ 85% gần như tắt hẳn màn hình).
const double _dimBrightness = 0.12;
const double _dimOverlay = 0.45;

/// Bọc màn đồng hồ: khi bật tiết kiệm pin thì giữ màn hình không tắt hẳn
/// nhưng làm tối sau [powerSaverIdle] không chạm; chạm / bấm phím hoặc
/// chuyển focus ↔ break thì sáng lại. Lần chạm đánh thức không bấm vào nút.
class PowerSaver extends ConsumerStatefulWidget {
  const PowerSaver({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<PowerSaver> createState() => _PowerSaverState();
}

class _PowerSaverState extends ConsumerState<PowerSaver> {
  /// Số màn đang giữ sáng: màn mới mở trước khi màn cũ đóng (vd. đồng hồ
  /// đếm giờ → đồng hồ treo tường) nên chỉ nhả khi không còn màn nào.
  static int _holders = 0;

  Timer? _idle;
  bool _dimmed = false;
  bool _active = false;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
    _setActive(ref.read(batterySaverProvider));
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    _idle?.cancel();
    if (_dimmed) unawaited(ScreenControl.setBrightness(null));
    if (_active) _release();
    super.dispose();
  }

  /// Bật / tắt chế độ (lúc vào màn hoặc khi đổi trong cài đặt).
  void _setActive(bool active) {
    if (active == _active) return;
    _active = active;
    if (active) {
      if (_holders++ == 0) unawaited(ScreenControl.keepOn(true));
    } else {
      _release();
    }
    if (active) {
      _wake();
    } else {
      _idle?.cancel();
      if (_dimmed) {
        unawaited(ScreenControl.setBrightness(null));
        if (mounted) setState(() => _dimmed = false);
      }
    }
  }

  void _release() {
    if (--_holders == 0) unawaited(ScreenControl.keepOn(false));
  }

  /// Sáng lại (nếu đang tối) và đếm lại từ đầu.
  void _wake() {
    if (!_active) return;
    _idle?.cancel();
    _idle = Timer(powerSaverIdle, _dim);
    if (_dimmed) {
      unawaited(ScreenControl.setBrightness(null));
      setState(() => _dimmed = false);
    }
  }

  void _dim() {
    if (!mounted || !_active) return;
    unawaited(ScreenControl.setBrightness(_dimBrightness));
    setState(() => _dimmed = true);
  }

  bool _onKey(KeyEvent event) {
    if (event is KeyDownEvent) _wake();
    // Không chặn phím: phím vẫn tới các phím tắt của màn (F, Space…).
    return false;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(batterySaverProvider, (_, active) => _setActive(active));
    // Chuyển focus ↔ break: sáng lên cho thấy đã đổi pha.
    ref.listen(
      timerControllerProvider.select((s) => s.phase),
      (_, _) => _wake(),
    );

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _wake(),
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          // Đang tối: chạm đầu tiên chỉ để đánh thức.
          AbsorbPointer(absorbing: _dimmed, child: widget.child),
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedOpacity(
                duration: Duration(milliseconds: _dimmed ? 1200 : 250),
                opacity: _dimmed ? _dimOverlay : 0,
                child: const ColoredBox(color: Colors.black),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
