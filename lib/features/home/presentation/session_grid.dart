import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/widgets/fade_slide_in.dart';
import '../../../data/data_providers.dart';
import '../../presets/domain/preset_entry.dart';
import '../../presets/presentation/session_card.dart';

/// Lưới card session (kèm ô "New session" ở cuối), nhấn giữ để kéo thả đổi
/// thứ tự. Thả ra thì lưu thứ tự mới vào DB.
class SessionGrid extends ConsumerStatefulWidget {
  const SessionGrid({super.key, required this.presets});

  final List<PresetEntry> presets;

  static const gridDelegate = SliverGridDelegateWithMaxCrossAxisExtent(
    maxCrossAxisExtent: 380,
    mainAxisExtent: 228,
    mainAxisSpacing: 16,
    crossAxisSpacing: 16,
  );

  @override
  ConsumerState<SessionGrid> createState() => _SessionGridState();
}

class _SessionGridState extends ConsumerState<SessionGrid> {
  /// Thứ tự tạm (id) trong lúc kéo và cho tới khi DB phát lại thứ tự mới,
  /// để lưới không giật về thứ tự cũ trong khoảnh khắc chờ.
  List<int>? _order;
  int? _draggingId;

  List<int> get _ids => [for (final e in widget.presets) e.id];

  @override
  void didUpdateWidget(SessionGrid old) {
    super.didUpdateWidget(old);
    // DB đã phản ánh thứ tự mới (hoặc danh sách đổi khác) → bỏ thứ tự tạm.
    final order = _order;
    if (_draggingId == null &&
        order != null &&
        (listEquals(order, _ids) || order.length != _ids.length)) {
      _order = null;
    }
  }

  List<PresetEntry> get _visible {
    final order = _order;
    if (order == null) return widget.presets;
    final byId = {for (final e in widget.presets) e.id: e};
    return [
      for (final id in order) ?byId[id],
      // Session mới thêm trong lúc kéo (hiếm) vẫn hiện ở cuối.
      for (final e in widget.presets)
        if (!order.contains(e.id)) e,
    ];
  }

  void _startDrag(int id) => setState(() {
    _draggingId = id;
    _order ??= _ids;
  });

  /// Kéo [draggedId] qua card [targetId]: chèn vào vị trí của card đó.
  void _moveOver(int draggedId, int targetId) {
    final order = [...?_order];
    final from = order.indexOf(draggedId);
    final to = order.indexOf(targetId);
    if (from < 0 || to < 0 || from == to) return;
    setState(() => _order = order..insert(to, order.removeAt(from)));
  }

  void _endDrag() {
    final order = _order;
    setState(() => _draggingId = null);
    if (order == null) return;
    if (listEquals(order, _ids)) {
      setState(() => _order = null);
    } else {
      ref.read(presetRepositoryProvider).reorder(order);
    }
  }

  @override
  Widget build(BuildContext context) {
    final presets = _visible;
    return SliverGrid(
      gridDelegate: SessionGrid.gridDelegate,
      delegate: SliverChildBuilderDelegate(
        (context, i) {
          if (i == presets.length) {
            return FadeSlideIn(
              key: const ValueKey('add'),
              index: i + 1,
              child: const AddSessionCard(),
            );
          }
          final entry = presets[i];
          return FadeSlideIn(
            key: ValueKey(entry.id),
            index: i + 1,
            child: _DraggableCard(
              entry: entry,
              dragging: entry.id == _draggingId,
              onDragStart: () => _startDrag(entry.id),
              onHover: (draggedId) => _moveOver(draggedId, entry.id),
              onDragEnd: _endDrag,
            ),
          );
        },
        childCount: presets.length + 1,
        // Giữ state (hiệu ứng, hover) của card khi đổi chỗ.
        findChildIndexCallback: (key) {
          final value = (key as ValueKey<Object>).value;
          if (value == 'add') return presets.length;
          final i = presets.indexWhere((e) => e.id == value);
          return i < 0 ? null : i;
        },
      ),
    );
  }
}

class _DraggableCard extends StatelessWidget {
  const _DraggableCard({
    required this.entry,
    required this.dragging,
    required this.onDragStart,
    required this.onHover,
    required this.onDragEnd,
  });

  final PresetEntry entry;
  final bool dragging;
  final VoidCallback onDragStart;
  final ValueChanged<int> onHover;
  final VoidCallback onDragEnd;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final card = SessionCard(entry: entry);
        return DragTarget<int>(
          onWillAcceptWithDetails: (details) {
            if (details.data != entry.id) onHover(details.data);
            return true;
          },
          builder: (context, candidates, rejected) => LongPressDraggable<int>(
            data: entry.id,
            hapticFeedbackOnStart: true,
            onDragStarted: onDragStart,
            onDragEnd: (_) => onDragEnd(),
            // Bản sao bám theo tay: cùng kích thước, phóng nhẹ, hơi trong.
            feedback: SizedBox(
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              child: Material(
                type: MaterialType.transparency,
                child: Transform.scale(
                  scale: 1.04,
                  child: Opacity(opacity: 0.92, child: card),
                ),
              ),
            ),
            // Chỗ cũ: ô mờ giữ vị trí.
            childWhenDragging: Opacity(opacity: 0.25, child: card),
            child: AnimatedOpacity(
              opacity: dragging ? 0.25 : 1,
              duration: const Duration(milliseconds: 150),
              child: card,
            ),
          ),
        );
      },
    );
  }
}
