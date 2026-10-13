#!/usr/bin/env bash
# Build APK release và đặt tên theo version trong pubspec.yaml:
#   dist/CYT_v<version>.apk                 (mặc định, 1 file chạy mọi máy)
#   dist/CYT_v<version>_<abi>.apk           (với --split, mỗi kiến trúc 1 file nhỏ hơn)
#
# Cách dùng:
#   scripts/build_apk.sh            # build bản chung
#   scripts/build_apk.sh --split    # build tách theo ABI
#
# Đổi version: sửa dòng `version: x.y.z+n` trong pubspec.yaml trước khi chạy.
set -euo pipefail

cd "$(dirname "$0")/.."

# Tìm flutter: ưu tiên biến FLUTTER, rồi PATH, rồi ~/development/flutter.
FLUTTER="${FLUTTER:-}"
if [[ -z "$FLUTTER" ]]; then
  if command -v flutter >/dev/null 2>&1; then
    FLUTTER=flutter
  else
    FLUTTER="$HOME/development/flutter/bin/flutter"
  fi
fi

SPLIT=false
for arg in "$@"; do
  case "$arg" in
    --split) SPLIT=true ;;
    -h|--help) sed -n '2,11p' "$0"; exit 0 ;;
    *) echo "Tham số không hợp lệ: $arg" >&2; exit 1 ;;
  esac
done

# version: 1.0.0+1  →  NAME=1.0.0, BUILD=1
FULL_VERSION=$(grep -E '^version:' pubspec.yaml | head -1 | awk '{print $2}')
VERSION_NAME=${FULL_VERSION%%+*}
if [[ -z "$VERSION_NAME" ]]; then
  echo "Không đọc được version trong pubspec.yaml" >&2
  exit 1
fi

if [[ -f android/key.properties ]]; then
  echo "Ký bằng khoá release (android/key.properties)."
else
  echo "Không có android/key.properties → ký bằng khoá debug (chỉ nên dùng để cài thử)."
fi

echo "Build CYT v$FULL_VERSION ..."
OUT_DIR=build/app/outputs/flutter-apk
mkdir -p dist

if $SPLIT; then
  "$FLUTTER" build apk --release --split-per-abi
  for abi in arm64-v8a armeabi-v7a x86_64; do
    src="$OUT_DIR/app-$abi-release.apk"
    [[ -f "$src" ]] && cp "$src" "dist/CYT_v${VERSION_NAME}_${abi}.apk"
  done
else
  "$FLUTTER" build apk --release
  cp "$OUT_DIR/app-release.apk" "dist/CYT_v${VERSION_NAME}.apk"
fi

echo
echo "Xong. File trong dist/:"
(cd dist && ls -lh CYT_v"${VERSION_NAME}"*.apk && sha256sum CYT_v"${VERSION_NAME}"*.apk)
