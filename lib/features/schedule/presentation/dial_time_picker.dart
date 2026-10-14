import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Chọn giờ bằng mặt đồng hồ tròn 24h: vòng trong 00–11, vòng ngoài 12–23;
/// chọn giờ xong tự chuyển sang chọn phút (vòng 00, 05, … 55, kéo được tới
/// từng phút). Cũng gõ số thẳng vào hai ô giờ / phút được. Trả về số phút
/// trong ngày (0–1439), hoặc null nếu huỷ.
Future<int?> showDialTimePicker(
  BuildContext context, {
  required String title,
  required int initialMinutes,
}) => showDialog<int>(
  context: context,
  builder: (_) =>
      _DialTimePicker(title: title, initialMinutes: initialMinutes % (24 * 60)),
);

enum _Mode { hour, minute }

class _DialTimePicker extends StatefulWidget {
  const _DialTimePicker({required this.title, required this.initialMinutes});

  final String title;
  final int initialMinutes;

  @override
  State<_DialTimePicker> createState() => _DialTimePickerState();
}

class _DialTimePickerState extends State<_DialTimePicker> {
  late int _hour = widget.initialMinutes ~/ 60;
  late int _minute = widget.initialMinutes % 60;
  _Mode _mode = _Mode.hour;

  // Ô nhập giờ / phút bằng bàn phím, luôn khớp với mặt đồng hồ.
  late final _hourText = TextEditingController(text: _two(_hour));
  late final _minuteText = TextEditingController(text: _two(_minute));
  final _hourFocus = FocusNode();
  final _minuteFocus = FocusNode();
  bool _hourInvalid = false;
  bool _minuteInvalid = false;

  static String _two(int v) => v.toString().padLeft(2, '0');

  @override
  void initState() {
    super.initState();
    _hourFocus.addListener(() => _onFocus(_hourFocus, _hourText, _Mode.hour));
    _minuteFocus.addListener(
      () => _onFocus(_minuteFocus, _minuteText, _Mode.minute),
    );
  }

  /// Vào ô: chọn hết số để gõ đè + đổi mặt đồng hồ. Rời ô: chuẩn hoá 2 số.
  void _onFocus(FocusNode node, TextEditingController text, _Mode mode) {
    // Hộp thoại đã đóng (focus rời ô sau khi gỡ widget) thì bỏ qua.
    if (!mounted) return;
    if (node.hasFocus) {
      setState(() => _mode = mode);
      text.selection = TextSelection(
        baseOffset: 0,
        extentOffset: text.text.length,
      );
    } else {
      setState(() {
        _hourInvalid = false;
        _minuteInvalid = false;
        _syncText();
      });
    }
  }

  /// Đưa giá trị hiện tại vào hai ô (sau khi chọn trên mặt đồng hồ).
  void _syncText() {
    if (!_hourFocus.hasFocus) _hourText.text = _two(_hour);
    if (!_minuteFocus.hasFocus) _minuteText.text = _two(_minute);
  }

  void _onHourTyped(String s) {
    final v = int.tryParse(s);
    setState(() {
      _hourInvalid = v == null || v > 23;
      if (!_hourInvalid) _hour = v!;
    });
    // Gõ đủ 2 số hợp lệ → sang ô phút.
    if (!_hourInvalid && s.length == 2) _minuteFocus.requestFocus();
  }

  void _onMinuteTyped(String s) {
    final v = int.tryParse(s);
    setState(() {
      _minuteInvalid = v == null || v > 59;
      if (!_minuteInvalid) _minute = v!;
    });
  }

  void _submit() => Navigator.pop(context, _hour * 60 + _minute);

  @override
  void dispose() {
    _hourText.dispose();
    _minuteText.dispose();
    _hourFocus.dispose();
    _minuteFocus.dispose();
    super.dispose();
  }

  /// Chọn theo vị trí chạm/kéo trên mặt đồng hồ.
  void _pick(Offset local, double size, {required bool done}) {
    final center = Offset(size / 2, size / 2);
    final d = local - center;
    // Góc tính từ đỉnh (12 giờ), theo chiều kim đồng hồ, 0–2π.
    final angle = (math.atan2(d.dx, -d.dy) + 2 * math.pi) % (2 * math.pi);
    // Đang gõ trong ô thì bỏ focus để số trong ô theo mặt đồng hồ.
    FocusScope.of(context).unfocus();
    setState(() {
      if (_mode == _Mode.hour) {
        final index = (angle / (2 * math.pi) * 12).round() % 12;
        final r = size / 2;
        // Gần tâm hơn đường giữa hai vòng → vòng trong (00–11).
        final inner =
            d.distance <
            r * (_DialPainter.innerRing + _DialPainter.outerRing) / 2;
        _hour = inner ? index : 12 + index;
        _hourInvalid = false;
        if (done) _mode = _Mode.minute;
      } else {
        _minute = (angle / (2 * math.pi) * 60).round() % 60;
        _minuteInvalid = false;
      }
      _syncText();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    Widget field({
      required TextEditingController controller,
      required FocusNode focus,
      required _Mode mode,
      required bool invalid,
      required ValueChanged<String> onChanged,
    }) {
      final active = _mode == mode;
      final fg = active ? scheme.surface : scheme.onSurface;
      return SizedBox(
        width: 96,
        child: TextField(
          controller: controller,
          focusNode: focus,
          onChanged: onChanged,
          onSubmitted: (_) => _submit(),
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 2,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          cursorColor: fg,
          style: theme.textTheme.displaySmall?.copyWith(
            color: fg,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
          decoration: InputDecoration(
            counterText: '',
            filled: true,
            fillColor: active
                ? scheme.onSurface
                : scheme.surfaceContainerHighest,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            // Số không hợp lệ (giờ > 23, phút > 59): viền đỏ.
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: invalid
                  ? BorderSide(color: scheme.error, width: 2)
                  : BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: invalid
                  ? BorderSide(color: scheme.error, width: 2)
                  : BorderSide.none,
            ),
          ),
        ),
      );
    }

    const dialSize = 280.0;
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              field(
                controller: _hourText,
                focus: _hourFocus,
                mode: _Mode.hour,
                invalid: _hourInvalid,
                onChanged: _onHourTyped,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(':', style: theme.textTheme.displaySmall),
              ),
              field(
                controller: _minuteText,
                focus: _minuteFocus,
                mode: _Mode.minute,
                invalid: _minuteInvalid,
                onChanged: _onMinuteTyped,
              ),
            ],
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onPanDown: (e) => _pick(e.localPosition, dialSize, done: false),
            onPanUpdate: (e) => _pick(e.localPosition, dialSize, done: false),
            onPanEnd: (_) {
              if (_mode == _Mode.hour) setState(() => _mode = _Mode.minute);
            },
            onTapUp: (e) => _pick(e.localPosition, dialSize, done: true),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: CustomPaint(
                key: ValueKey(_mode),
                size: const Size.square(dialSize),
                painter: _DialPainter(
                  mode: _mode,
                  hour: _hour,
                  minute: _minute,
                  face: scheme.surfaceContainerHighest,
                  text: scheme.onSurface,
                  muted: scheme.onSurfaceVariant,
                  selector: scheme.onSurface,
                  onSelector: scheme.surface,
                  textStyle: theme.textTheme.bodyLarge!,
                ),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          style: FilledButton.styleFrom(shape: const StadiumBorder()),
          child: const Text('OK'),
        ),
      ],
    );
  }
}

class _DialPainter extends CustomPainter {
  _DialPainter({
    required this.mode,
    required this.hour,
    required this.minute,
    required this.face,
    required this.text,
    required this.muted,
    required this.selector,
    required this.onSelector,
    required this.textStyle,
  });

  /// Bán kính hai vòng số (tỉ lệ theo bán kính mặt đồng hồ).
  static const double outerRing = 0.83;
  static const double innerRing = 0.54;

  /// Bán kính vòng tròn chọn — nhỏ hơn khoảng cách giữa các số nên không đè.
  static const double _selectorRadius = 17;

  final _Mode mode;
  final int hour;
  final int minute;
  final Color face;
  final Color text;
  final Color muted;
  final Color selector;
  final Color onSelector;
  final TextStyle textStyle;

  Offset _at(Offset c, double radius, double turns) => Offset(
    c.dx + radius * math.sin(2 * math.pi * turns),
    c.dy - radius * math.cos(2 * math.pi * turns),
  );

  void _label(Canvas canvas, Offset at, String s, Color color, double size) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: textStyle.copyWith(
          color: color,
          fontSize: size,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, at - Offset(tp.width / 2, tp.height / 2));
    tp.dispose();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    canvas.drawCircle(c, r, Paint()..color = face);

    // Vị trí kim chọn.
    final (selRadius, selTurns) = switch (mode) {
      _Mode.hour => (r * (hour < 12 ? innerRing : outerRing), (hour % 12) / 12),
      _Mode.minute => (r * outerRing, minute / 60),
    };
    final sel = _at(c, selRadius, selTurns);
    final paint = Paint()..color = selector;
    canvas.drawCircle(c, 4, paint);
    canvas.drawLine(c, sel, paint..strokeWidth = 2);
    canvas.drawCircle(sel, _selectorRadius, paint);

    bool isSelected(Offset at) => (at - sel).distance < 1;

    if (mode == _Mode.hour) {
      for (var i = 0; i < 12; i++) {
        // Vòng ngoài 12–23, vòng trong 00–11.
        final outer = _at(c, r * outerRing, i / 12);
        final inner = _at(c, r * innerRing, i / 12);
        _label(
          canvas,
          outer,
          '${12 + i}',
          isSelected(outer) ? onSelector : text,
          16,
        );
        _label(
          canvas,
          inner,
          i.toString().padLeft(2, '0'),
          isSelected(inner) ? onSelector : muted,
          14,
        );
      }
    } else {
      for (var i = 0; i < 12; i++) {
        final at = _at(c, r * outerRing, i / 12);
        _label(
          canvas,
          at,
          (i * 5).toString().padLeft(2, '0'),
          isSelected(at) ? onSelector : text,
          16,
        );
      }
      // Phút lẻ (không chia hết cho 5): chấm nhỏ ở giữa vòng chọn.
      if (minute % 5 != 0) {
        canvas.drawCircle(sel, 3, Paint()..color = onSelector);
      }
    }
  }

  @override
  bool shouldRepaint(_DialPainter old) =>
      old.mode != mode ||
      old.hour != hour ||
      old.minute != minute ||
      old.face != face ||
      old.selector != selector;
}
