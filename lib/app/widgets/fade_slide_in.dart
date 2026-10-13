import 'dart:async';

import 'package:flutter/material.dart';

/// Hiện dần + trượt nhẹ lên khi xuất hiện lần đầu.
///
/// [index] tạo độ trễ so le (mỗi phần tử chậm hơn phần tử trước [stagger])
/// để danh sách hiện lần lượt thay vì cùng lúc.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.index = 0,
    this.stagger = const Duration(milliseconds: 45),
    this.duration = const Duration(milliseconds: 420),
    this.offset = 16,
  });

  final Widget child;
  final int index;
  final Duration stagger;
  final Duration duration;

  /// Quãng trượt (px) từ dưới lên.
  final double offset;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  late final Animation<double> _t = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );
  Timer? _delay;

  @override
  void initState() {
    super.initState();
    // Giới hạn độ trễ để danh sách dài không phải chờ lâu.
    final delay = widget.stagger * widget.index.clamp(0, 10);
    if (delay == Duration.zero) {
      _controller.forward();
    } else {
      _delay = Timer(delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _delay?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _t,
    builder: (context, child) => Opacity(
      opacity: _t.value,
      child: Transform.translate(
        offset: Offset(0, widget.offset * (1 - _t.value)),
        child: child,
      ),
    ),
    child: widget.child,
  );
}
