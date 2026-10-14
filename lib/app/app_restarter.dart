import 'package:flutter/widgets.dart';

/// Dựng lại toàn bộ app (ProviderScope mới → mọi provider đọc lại cài đặt
/// và dữ liệu), dùng sau khi nạp bản sao lưu.
class AppRestarter extends StatefulWidget {
  const AppRestarter({super.key, required this.builder});

  /// Dựng cây app với [key]; đổi key là dựng lại từ đầu.
  final Widget Function(Key key) builder;

  static void restart(BuildContext context) =>
      context.findAncestorStateOfType<_AppRestarterState>()?.restart();

  @override
  State<AppRestarter> createState() => _AppRestarterState();
}

class _AppRestarterState extends State<AppRestarter> {
  Key _key = UniqueKey();

  void restart() => setState(() => _key = UniqueKey());

  @override
  Widget build(BuildContext context) => widget.builder(_key);
}
