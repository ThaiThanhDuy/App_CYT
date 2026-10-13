import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_db.dart';
import 'preset_repository.dart';
import 'session_repository.dart';

/// Database dùng chung. Test override bằng `AppDatabase(NativeDatabase.memory())`.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final sessionRepositoryProvider = Provider<SessionRepository>(
  (ref) => SessionRepository(ref.watch(appDatabaseProvider)),
);

final presetRepositoryProvider = Provider<PresetRepository>(
  (ref) => PresetRepository(ref.watch(appDatabaseProvider)),
);

/// Cài đặt nhỏ (preset đang chọn...). Được nạp trong `main()` rồi override,
/// để đọc đồng bộ được.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('Override trong main() / test'),
);
