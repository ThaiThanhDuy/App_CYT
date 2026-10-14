import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../data/app_db.dart';

/// Định dạng file sao lưu.
const backupFormat = 'cyt-backup';
const backupVersion = 1;

/// File không phải bản sao lưu hợp lệ của app.
class BackupFormatException implements Exception {
  const BackupFormatException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Số lượng từng loại dữ liệu trong một bản sao lưu.
typedef BackupSummary = ({int sessions, int blocks, int history, int settings});

/// Xuất / nạp toàn bộ cấu hình app ra một file JSON: cài đặt
/// (SharedPreferences), các session, block lịch và lịch sử focus.
class BackupService {
  BackupService(this._db, this._prefs);

  final AppDatabase _db;
  final SharedPreferences _prefs;

  /// Toàn bộ dữ liệu dưới dạng JSON (thụt lề cho dễ đọc).
  Future<String> exportJson() async {
    final settings = <String, Object?>{};
    for (final key in _prefs.getKeys()) {
      final value = _prefs.get(key);
      // Ghi kèm kiểu để nạp lại đúng (JSON không phân biệt int / double).
      final type = switch (value) {
        bool() => 'bool',
        int() => 'int',
        double() => 'double',
        String() => 'string',
        List() => 'list',
        _ => null,
      };
      if (type != null) settings[key] = {'type': type, 'value': value};
    }
    final data = {
      'format': backupFormat,
      'version': backupVersion,
      'schema': _db.schemaVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'settings': settings,
      'presets': [
        for (final r in await _db.select(_db.presets).get()) r.toJson(),
      ],
      'taskBlocks': [
        for (final r in await _db.select(_db.taskBlocks).get()) r.toJson(),
      ],
      'completedSessions': [
        for (final r in await _db.select(_db.completedSessions).get())
          r.toJson(),
      ],
    };
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  /// Đọc và kiểm tra file; ném [BackupFormatException] nếu không hợp lệ.
  static Map<String, Object?> parse(String text) {
    final Object? data;
    try {
      data = jsonDecode(text);
    } on FormatException {
      throw const BackupFormatException('This file is not valid JSON');
    }
    if (data is! Map<String, Object?> || data['format'] != backupFormat) {
      throw const BackupFormatException('This is not a CYT backup file');
    }
    final version = data['version'];
    if (version is! int || version > backupVersion) {
      throw const BackupFormatException(
        'This backup was made by a newer version of the app',
      );
    }
    return data;
  }

  static List<Map<String, Object?>> _rows(
    Map<String, Object?> data,
    String k,
  ) => [
    for (final r in (data[k] as List?) ?? const []) r as Map<String, Object?>,
  ];

  /// Tóm tắt nội dung để hỏi lại trước khi nạp.
  static BackupSummary summarize(Map<String, Object?> data) => (
    sessions: _rows(data, 'presets').length,
    blocks: _rows(data, 'taskBlocks').length,
    history: _rows(data, 'completedSessions').length,
    settings: ((data['settings'] as Map?) ?? const {}).length,
  );

  /// Thay toàn bộ dữ liệu hiện tại bằng nội dung bản sao lưu [data] (đã qua
  /// [parse]). Giữ nguyên id để block / lịch sử vẫn trỏ đúng session.
  Future<void> restore(Map<String, Object?> data) async {
    final presets = [
      for (final r in _rows(data, 'presets')) Preset.fromJson(r),
    ];
    final blocks = [
      for (final r in _rows(data, 'taskBlocks')) TaskBlockRow.fromJson(r),
    ];
    final history = [
      for (final r in _rows(data, 'completedSessions'))
        CompletedSession.fromJson(r),
    ];

    await _db.transaction(() async {
      // Xoá bảng con trước (khoá ngoại trỏ tới presets).
      await _db.delete(_db.completedSessions).go();
      await _db.delete(_db.taskBlocks).go();
      await _db.delete(_db.presets).go();
      await _db.batch((b) {
        b.insertAll(_db.presets, presets);
        b.insertAll(_db.taskBlocks, blocks);
        b.insertAll(_db.completedSessions, history);
      });
    });

    final settings = (data['settings'] as Map?) ?? const {};
    await _prefs.clear();
    for (final MapEntry(:key, :value) in settings.entries) {
      if (value is! Map) continue;
      final v = value['value'];
      switch ((value['type'], v)) {
        case ('bool', final bool b):
          await _prefs.setBool(key as String, b);
        case ('int', final num n):
          await _prefs.setInt(key as String, n.toInt());
        case ('double', final num n):
          await _prefs.setDouble(key as String, n.toDouble());
        case ('string', final String s):
          await _prefs.setString(key as String, s);
        case ('list', final List l):
          await _prefs.setStringList(key as String, [for (final e in l) '$e']);
      }
    }
  }
}
