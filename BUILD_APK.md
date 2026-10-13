# Build file APK để cài đặt

Hướng dẫn tạo file APK của **Counting Your Time (CYT)** có kèm version trong tên,
ví dụ `CYT_v1.0.0.apk`, để chép sang điện thoại Android và cài trực tiếp.

## TL;DR

```bash
scripts/build_apk.sh
# → dist/CYT_v1.0.0.apk
```

---

## 1. Chuẩn bị (làm một lần)

| Cần có | Kiểm tra |
| --- | --- |
| Flutter SDK | `flutter --version` |
| Android SDK + licenses đã chấp nhận | `flutter doctor` (mục *Android toolchain* có ✓) |

Nếu `flutter` không có trong `PATH`, script tự tìm ở `~/development/flutter/bin/flutter`.
Hoặc chỉ định rõ:

```bash
FLUTTER=/đường/dẫn/flutter/bin/flutter scripts/build_apk.sh
```

Chấp nhận licenses Android (nếu `flutter doctor` báo thiếu):

```bash
flutter doctor --android-licenses
```

## 2. Đặt version

Version lấy từ dòng `version` trong `pubspec.yaml`:

```yaml
version: 1.0.0+1
#        │     └─ build number (versionCode) — số nguyên, phải TĂNG mỗi lần phát hành
#        └─────── version name — hiện cho người dùng, dùng để đặt tên file APK
```

Mỗi lần ra bản mới, tăng **cả hai** phần, ví dụ `1.0.0+1` → `1.1.0+2`.
Android chỉ cho cài đè khi `versionCode` (số sau dấu `+`) lớn hơn hoặc bằng bản đang cài.

## 3. Build

### Một file chạy trên mọi máy (khuyên dùng)

```bash
scripts/build_apk.sh
```

Kết quả: `dist/CYT_v1.0.0.apk`.

### Tách theo kiến trúc CPU (file nhỏ hơn)

```bash
scripts/build_apk.sh --split
```

Kết quả:

| File | Dùng cho |
| --- | --- |
| `dist/CYT_v1.0.0_arm64-v8a.apk` | Hầu hết điện thoại Android hiện nay |
| `dist/CYT_v1.0.0_armeabi-v7a.apk` | Máy Android 32-bit đời cũ |
| `dist/CYT_v1.0.0_x86_64.apk` | Emulator / máy x86 |

Không chắc máy thuộc loại nào thì dùng bản chung ở trên.

Cuối mỗi lần build, script in kích thước và mã SHA-256 của file để đối chiếu khi
gửi cho người khác.

## 4. Ký APK (khuyên dùng khi phát cho người khác)

**Mặc định APK được ký bằng khoá debug.** Cài thử thì không sao, nhưng khoá debug
khác nhau giữa các máy build. Vì vậy APK build ở máy khác **không cài đè** được lên
bản cũ, người dùng phải gỡ app (mất dữ liệu) rồi cài lại.

Để mọi bản build cùng một chữ ký, tạo khoá release **một lần**.

### 4.1. Tạo keystore

```bash
keytool -genkey -v -keystore ~/cyt-release.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias cyt
```

### 4.2. Khai báo cho Gradle

Tạo file `android/key.properties`:

```properties
storeFile=/home/<user>/cyt-release.jks
storePassword=<mật khẩu keystore>
keyAlias=cyt
keyPassword=<mật khẩu khoá>
```

Khi có file này, `scripts/build_apk.sh` tự ký bằng khoá release (script in ra dòng
*"Ký bằng khoá release"*). Cấu hình nằm ở `android/app/build.gradle.kts`.

> ⚠️ **Giữ kỹ** file `.jks` và mật khẩu. Mất khoá thì không phát hành được bản cập
> nhật cài đè lên bản cũ nữa. `key.properties`, `*.jks` và `*.keystore` đã nằm
> trong `.gitignore`, **không commit** chúng lên git.

## 5. Cài lên điện thoại

**Cách 1: qua USB** (bật *USB debugging* trong *Developer options*):

```bash
adb install -r dist/CYT_v1.0.0.apk
```

`-r` để cài đè, giữ nguyên dữ liệu.

**Cách 2: chép file:** gửi `CYT_v1.0.0.apk` sang máy (cáp, Drive, Telegram…), mở
file và chọn *Cài đặt*. Lần đầu Android sẽ hỏi cho phép *cài ứng dụng không rõ
nguồn gốc* từ ứng dụng dùng để mở file.

## 6. Lỗi thường gặp

| Hiện tượng | Cách xử lý |
| --- | --- |
| `App not installed` / *xung đột gói* khi cài đè | Bản cũ được ký bằng khoá khác (thường là khoá debug của máy khác). Gỡ bản cũ rồi cài lại, và dùng khoá release (mục 4) cho các bản sau. |
| Android báo *đã cài bản mới hơn* | Build number (số sau `+`) nhỏ hơn bản đang cài. Tăng nó trong `pubspec.yaml` rồi build lại. |
| `Some Android licenses not accepted` | `flutter doctor --android-licenses` |
| Build lần đầu rất lâu | Bình thường: Gradle tải dependency lần đầu (vài phút), các lần sau nhanh hơn. |

## 7. Ghi chú

- File APK nằm trong `dist/`, thư mục này không được commit lên git.
- Màn *Settings → About* tự đọc version từ bản build (dòng `version` trong
  `pubspec.yaml`), không cần sửa tay khi tăng version.
