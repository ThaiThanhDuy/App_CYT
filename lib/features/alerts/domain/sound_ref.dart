/// Tham chiếu tới một file âm thanh để phát.
sealed class SoundRef {
  const SoundRef();
}

/// Âm thanh nằm trong asset bundle, [assetPath] là đường dẫn đầy đủ
/// (ví dụ `assets/sounds/chime.wav`).
class AssetSoundRef extends SoundRef {
  const AssetSoundRef(this.assetPath);
  final String assetPath;
}

/// Âm thanh là file trên đĩa (theme người dùng cài).
class FileSoundRef extends SoundRef {
  const FileSoundRef(this.path);
  final String path;
}

/// Âm thanh có sẵn trong app, tương ứng `assets/sounds/<key>.wav`.
abstract final class SoundKeys {
  static const chime = 'chime';
  static const bell = 'bell';
  static const complete = 'complete';

  static const all = [chime, bell, complete];

  static SoundRef ref(String key) => AssetSoundRef('assets/sounds/$key.wav');
}
