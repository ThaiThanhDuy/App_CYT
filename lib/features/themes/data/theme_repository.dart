import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../domain/theme_package.dart';
import 'theme_sources.dart';

/// Giới hạn kích thước để một gói lỗi/độc không làm đầy bộ nhớ.
const int maxThemeZipBytes = 50 * 1024 * 1024;
const int maxThemeUnpackedBytes = 150 * 1024 * 1024;

/// Nạp theme kèm sẵn + theme đã cài; cài / gỡ theme người dùng.
///
/// Theme cài được giải nén vào `<app documents>/themes/<id>/`.
class ThemeRepository {
  ThemeRepository({required this.installRoot, AssetBundle? bundle})
    : _bundle = bundle ?? rootBundle;

  /// Thư mục gốc chứa `themes/` (app documents).
  final Future<Directory> Function() installRoot;
  final AssetBundle _bundle;

  static const _manifestFile = 'theme.json';

  /// Tất cả theme hợp lệ: kèm sẵn trước, đã cài sau. Gói lỗi bị bỏ qua.
  Future<List<ThemePackage>> loadAll() async {
    final bundled = await _loadBundled();
    final ids = {for (final t in bundled) t.id};
    final installed = [
      for (final t in await _loadInstalled())
        if (!ids.contains(t.id)) t,
    ];
    return [...bundled, ...installed];
  }

  Future<List<ThemePackage>> _loadBundled() async {
    final manifest = await AssetManifest.loadFromAssetBundle(_bundle);
    final paths =
        manifest
            .listAssets()
            .where(
              (a) =>
                  a.startsWith('assets/themes/') && a.endsWith(_manifestFile),
            )
            .toList()
          ..sort();
    final result = <ThemePackage>[];
    for (final path in paths) {
      final source = BundledThemeSource(p.posix.dirname(path), bundle: _bundle);
      final theme = await _tryLoad(source);
      if (theme != null) result.add(theme);
    }
    return result;
  }

  Future<List<ThemePackage>> _loadInstalled() async {
    final root = await _themesDir();
    if (!root.existsSync()) return const [];
    final dirs = root.listSync().whereType<Directory>().where(
      (d) => !p.basename(d.path).startsWith('.'),
    );
    final result = <ThemePackage>[];
    for (final dir in dirs) {
      final theme = await _tryLoad(DirectoryThemeSource(dir.path));
      if (theme != null) result.add(theme);
    }
    result.sort((a, b) => a.name.compareTo(b.name));
    return result;
  }

  Future<ThemePackage?> _tryLoad(ThemeSource source) async {
    try {
      return await _load(source);
    } catch (e) {
      debugPrint('Bỏ qua theme ở ${source.location}: $e');
      return null;
    }
  }

  Future<ThemePackage> _load(ThemeSource source) async {
    final bytes = await source.readBytes(_manifestFile);
    final theme = ThemePackage.fromJson(jsonDecode(utf8.decode(bytes)), source);
    return _loadFont(theme);
  }

  /// Nạp font đi kèm gói (nếu có) dưới tên họ font riêng của theme.
  Future<ThemePackage> _loadFont(ThemePackage theme) async {
    final file = theme.fontFile;
    if (file == null) return theme;
    try {
      final family = 'cyt_theme_${theme.id}';
      final bytes = await theme.source.readBytes(file);
      await (FontLoader(
        family,
      )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
      return theme.withFontFamily(family);
    } catch (e) {
      debugPrint('Không nạp được font của theme ${theme.id}: $e');
      return theme;
    }
  }

  /// Cài từ file .zip. `theme.json` có thể ở gốc zip hoặc trong một thư mục
  /// con duy nhất (khi người dùng nén cả thư mục).
  Future<ThemePackage> installFromZip(String zipPath) async {
    final file = File(zipPath);
    if (await file.length() > maxThemeZipBytes) {
      throw const ThemeFormatException('zip file is too large (max 50MB)');
    }
    final archive = ZipDecoder().decodeBytes(await file.readAsBytes());
    final manifest =
        archive.files
            .where((f) => f.isFile && p.posix.basename(f.name) == _manifestFile)
            .toList()
          ..sort((a, b) => a.name.length.compareTo(b.name.length));
    if (manifest.isEmpty) {
      throw const ThemeFormatException('no theme.json found in the zip');
    }
    final prefix = p.posix.dirname(manifest.first.name);
    // Chỉ cho phép theme.json ở gốc hoặc sâu đúng một cấp.
    if (prefix != '.' && prefix.contains('/')) {
      throw const ThemeFormatException(
        'theme.json is nested too deep in the zip',
      );
    }

    final files = <String, Uint8List>{};
    var total = 0;
    for (final entry in archive.files.where((f) => f.isFile)) {
      final name = prefix == '.'
          ? entry.name
          : (entry.name.startsWith('$prefix/')
                ? entry.name.substring(prefix.length + 1)
                : null);
      if (name == null) continue;
      // Chống "zip slip": bỏ mọi đường dẫn thoát ra ngoài thư mục gói.
      final rel = normalizeThemePath(name);
      if (rel == null) {
        throw ThemeFormatException('invalid path in zip: $name');
      }
      total += entry.size;
      if (total > maxThemeUnpackedBytes) {
        throw const ThemeFormatException('unpacked theme is too large');
      }
      files[rel] = entry.content;
    }
    return _installFiles(files);
  }

  /// Cài từ một thư mục chứa `theme.json` (bỏ qua symlink).
  Future<ThemePackage> installFromDirectory(String dirPath) async {
    final dir = Directory(dirPath);
    if (!File(p.join(dirPath, _manifestFile)).existsSync()) {
      throw const ThemeFormatException('folder has no theme.json');
    }
    final files = <String, Uint8List>{};
    var total = 0;
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final rel = normalizeThemePath(
        p.split(p.relative(entity.path, from: dirPath)).join('/'),
      );
      if (rel == null) continue;
      total += await entity.length();
      if (total > maxThemeUnpackedBytes) {
        throw const ThemeFormatException('theme folder is too large');
      }
      files[rel] = await entity.readAsBytes();
    }
    return _installFiles(files);
  }

  /// Kiểm tra theme.json rồi ghi các file vào thư mục cài của theme.
  Future<ThemePackage> _installFiles(Map<String, Uint8List> files) async {
    final manifest = files[_manifestFile];
    if (manifest == null) {
      throw const ThemeFormatException('missing theme.json');
    }
    final Object? json;
    try {
      json = jsonDecode(utf8.decode(manifest));
    } on FormatException catch (e) {
      throw ThemeFormatException('theme.json is not valid JSON: $e');
    }

    final root = await _themesDir();
    // Parse trước với nguồn tạm để lấy id và báo lỗi sớm.
    final probe = ThemePackage.fromJson(json, DirectoryThemeSource(root.path));
    final bundledIds = {for (final t in await _loadBundled()) t.id};
    if (bundledIds.contains(probe.id)) {
      throw ThemeFormatException(
        'id "${probe.id}" is used by a built-in theme',
      );
    }

    // Ghi vào thư mục tạm rồi đổi tên, để không bao giờ còn gói ghi dở.
    final temp = Directory(
      p.join(root.path, '.tmp-${DateTime.now().microsecondsSinceEpoch}'),
    );
    try {
      for (final MapEntry(key: rel, value: bytes) in files.entries) {
        final out = File(p.joinAll([temp.path, ...rel.split('/')]));
        await out.parent.create(recursive: true);
        await out.writeAsBytes(bytes);
      }
      final target = Directory(p.join(root.path, probe.id));
      if (target.existsSync()) await target.delete(recursive: true);
      await temp.rename(target.path);
      return _load(DirectoryThemeSource(target.path));
    } finally {
      if (temp.existsSync()) await temp.delete(recursive: true);
    }
  }

  /// Gỡ theme đã cài. Theme kèm sẵn không gỡ được.
  Future<void> uninstall(ThemePackage theme) async {
    final source = theme.source;
    if (source is! DirectoryThemeSource) {
      throw StateError('Built-in themes cannot be removed');
    }
    final root = await _themesDir();
    // Chỉ xoá thư mục nằm đúng trong thư mục themes của app.
    if (!p.isWithin(root.path, source.dirPath)) {
      throw StateError('Unexpected theme path: ${source.dirPath}');
    }
    final dir = Directory(source.dirPath);
    if (dir.existsSync()) await dir.delete(recursive: true);
  }

  Future<Directory> _themesDir() async {
    final dir = Directory(p.join((await installRoot()).path, 'themes'));
    await dir.create(recursive: true);
    return dir;
  }
}
