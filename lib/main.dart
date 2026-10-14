import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'app/app_restarter.dart';
import 'data/app_db.dart';
import 'data/data_providers.dart';
import 'features/alerts/application/alert_providers.dart';
import 'features/alerts/data/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Điện thoại: chỉ chạy nằm ngang (khớp với AndroidManifest / Info.plist).
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS)) {
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }
  final prefs = await SharedPreferences.getInstance();
  final notifications = NotificationService();
  await notifications.init();
  // DB mở một lần cho cả vòng đời app: dựng lại app (sau khi nạp bản sao
  // lưu) không mở thêm kết nối mới tới cùng file.
  final db = AppDatabase();
  runApp(
    AppRestarter(
      builder: (key) => ProviderScope(
        key: key,
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          notificationServiceProvider.overrideWithValue(notifications),
          appDatabaseProvider.overrideWithValue(db),
        ],
        child: const CytApp(),
      ),
    ),
  );
}
