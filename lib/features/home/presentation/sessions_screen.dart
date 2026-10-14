import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../presets/application/preset_providers.dart';
import 'home_screen.dart';
import 'session_grid.dart';

/// Trang riêng chứa lưới session (card Start, kéo để đổi thứ tự, ô tạo mới).
class SessionsScreen extends ConsumerWidget {
  const SessionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presetsAsync = ref.watch(visiblePresetsProvider);
    final textTheme = Theme.of(context).textTheme;
    final count = presetsAsync.value?.length;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Sessions'),
            if (count != null) ...[
              const SizedBox(width: 8),
              Text(
                '$count',
                style: textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Center(
              child: Text(
                'Long-press a card to reorder',
                style: textTheme.bodySmall,
              ),
            ),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final hPad = constraints.maxWidth >= 1000 ? 48.0 : 20.0;
          // Chừa chỗ cho thanh "đang chạy" nổi ở đáy.
          const bottomPad = 112.0;
          return CustomScrollView(
            slivers: [
              switch (presetsAsync) {
                AsyncError(:final error) => SliverPadding(
                  padding: EdgeInsets.all(hPad),
                  sliver: SliverToBoxAdapter(child: Text('Error: $error')),
                ),
                AsyncData(value: final presets) => SliverPadding(
                  padding: EdgeInsets.fromLTRB(hPad, 16, hPad, bottomPad),
                  sliver: SessionGrid(presets: presets),
                ),
                _ => const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(48),
                    child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
              },
            ],
          );
        },
      ),
      bottomNavigationBar: const RunningBar(),
      extendBody: true,
    );
  }
}
