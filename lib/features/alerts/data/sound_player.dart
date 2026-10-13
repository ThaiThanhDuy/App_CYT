import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import '../domain/sound_ref.dart';

/// Phát âm thanh báo hết giờ.
abstract interface class SoundPlayer {
  Future<void> play(SoundRef sound);
  Future<void> dispose();
}

/// Phát asset hoặc file bằng audioplayers (Android, iOS, Linux qua GStreamer).
class AudioSoundPlayer implements SoundPlayer {
  // Tạo lười: chỉ khởi tạo plugin khi thực sự cần phát.
  AudioPlayer? _player;

  @override
  Future<void> play(SoundRef sound) async {
    try {
      final player = _player ??= AudioPlayer()
        // Prefix rỗng: dùng đường dẫn asset đầy đủ (assets/...).
        ..audioCache = AudioCache(prefix: '')
        ..setReleaseMode(ReleaseMode.stop);
      await player.stop();
      await player.play(switch (sound) {
        AssetSoundRef(:final assetPath) => AssetSource(assetPath),
        FileSoundRef(:final path) => DeviceFileSource(path),
      });
    } catch (e) {
      // Thiếu codec/plugin âm thanh hay file hỏng không được làm hỏng timer.
      debugPrint('Không phát được âm thanh $sound: $e');
    }
  }

  @override
  Future<void> dispose() async => _player?.dispose();
}
