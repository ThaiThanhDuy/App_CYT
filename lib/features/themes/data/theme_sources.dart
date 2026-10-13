import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../../alerts/domain/sound_ref.dart';
import '../domain/theme_package.dart';

/// Theme kèm sẵn trong app: `assets/themes/<thư mục>/`.
class BundledThemeSource implements ThemeSource {
  BundledThemeSource(this.basePath, {AssetBundle? bundle})
    : _bundle = bundle ?? rootBundle;

  /// Ví dụ `assets/themes/traffic_light`.
  final String basePath;
  final AssetBundle _bundle;

  @override
  bool get isBundled => true;

  @override
  String get location => basePath;

  @override
  Future<Uint8List> readBytes(String relativePath) async {
    final data = await _bundle.load('$basePath/$relativePath');
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }

  @override
  SoundRef soundRef(String relativePath) =>
      AssetSoundRef('$basePath/$relativePath');

  @override
  String? filePath(String relativePath) => null;
}

/// Theme người dùng đã cài: một thư mục trên đĩa.
class DirectoryThemeSource implements ThemeSource {
  DirectoryThemeSource(this.dirPath);

  final String dirPath;

  @override
  bool get isBundled => false;

  @override
  String get location => dirPath;

  @override
  Future<Uint8List> readBytes(String relativePath) =>
      File(p.join(dirPath, relativePath)).readAsBytes();

  @override
  SoundRef soundRef(String relativePath) =>
      FileSoundRef(p.join(dirPath, relativePath));

  @override
  String? filePath(String relativePath) => p.join(dirPath, relativePath);
}
