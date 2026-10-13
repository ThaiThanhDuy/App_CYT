import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../domain/alert_message.dart';

/// Một thông báo hẹn trước tại thời điểm [at] (giờ thật).
typedef ScheduledAlert = ({DateTime at, AlertMessage message});

/// Nội dung thông báo "đang chạy" của foreground service (Android).
/// Hệ thống tự vẽ đồng hồ: đếm ngược tới [at] (giờ thật lúc hết bước), hoặc
/// đếm lên từ [at] (lúc bắt đầu) nếu [countUp] — dùng cho bước vô hạn.
typedef OngoingTimer = ({String title, String body, DateTime at, bool countUp});

/// Bọc flutter_local_notifications, có kiểm tra nền tảng.
///
/// - Android / iOS: hẹn trước thông báo khi app vào nền ([scheduleAll]).
/// - Linux: không hỗ trợ hẹn giờ → app tự hiện ngay khi hết giờ ([showNow]).
/// - Nền tảng khác hoặc khởi tạo lỗi: mọi hàm thành no-op.
class NotificationService {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const _channelId = 'timer_end';
  static const _channelName = 'Timer finished';
  // Kênh Android quyết định âm thanh, nên session tắt chuông dùng kênh riêng.
  static const _silentChannelId = 'timer_end_silent';
  static const _silentChannelName = 'Timer finished (silent)';
  static const _ongoingChannelId = 'timer_running';
  static const _ongoingChannelName = 'Timer running';
  static const _nowId = 0;
  static const _ongoingId = 1;
  bool _ongoingActive = false;
  static const _scheduledBaseId = 100;

  static bool get _isMobile =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);
  static bool get _isLinux => !kIsWeb && Platform.isLinux;

  /// Nền tảng hẹn trước được thông báo (khi app ở nền vẫn báo đúng giờ).
  bool get supportsScheduling => _ready && _isMobile;

  /// Nền tảng cần app tự hiện thông báo lúc hết giờ.
  bool get showsImmediately => _ready && _isLinux;

  /// Có foreground service giữ app sống khi chạy nền (chỉ Android).
  /// iOS dùng Live Activities ở giai đoạn sau.
  bool get supportsOngoing => _ready && !kIsWeb && Platform.isAndroid;

  Future<void> init() async {
    if (!_isMobile && !_isLinux) return;
    try {
      tz_data.initializeTimeZones();
      // Quyền thông báo được xin khi người dùng bấm Bắt đầu lần đầu.
      const darwin = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestSoundPermission: false,
        requestBadgePermission: false,
      );
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: darwin,
          linux: LinuxInitializationSettings(defaultActionName: 'Open CYT'),
        ),
      );
      _ready = true;
    } catch (e) {
      debugPrint('Không khởi tạo được thông báo: $e');
    }
  }

  /// Xin quyền hiện thông báo (Android 13+, iOS). No-op ở Linux.
  Future<void> requestPermissions() async {
    if (!_ready) return;
    try {
      if (Platform.isAndroid) {
        await _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.requestNotificationsPermission();
      } else if (Platform.isIOS) {
        await _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >()
            ?.requestPermissions(alert: true, sound: true);
      }
    } catch (e) {
      debugPrint('Không xin được quyền thông báo: $e');
    }
  }

  NotificationDetails _details({required bool silent}) => NotificationDetails(
    android: AndroidNotificationDetails(
      silent ? _silentChannelId : _channelId,
      silent ? _silentChannelName : _channelName,
      channelDescription: 'Alerts when a focus or break phase ends',
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.alarm,
      playSound: !silent,
      silent: silent,
    ),
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBanner: true,
      presentSound: !silent,
      sound: silent ? null : 'default',
    ),
    // App tự phát âm thanh trên Linux, tránh kêu hai lần.
    linux: const LinuxNotificationDetails(suppressSound: true),
  );

  Future<void> showNow(AlertMessage message) async {
    if (!_ready) return;
    try {
      await _plugin.show(
        id: _nowId,
        title: message.title,
        body: message.body,
        notificationDetails: _details(silent: true),
      );
    } catch (e) {
      debugPrint('Không hiện được thông báo: $e');
    }
  }

  /// Thay toàn bộ thông báo hẹn trước bằng [alerts].
  /// [silent]: session đang chạy bị tắt chuông.
  Future<void> scheduleAll(
    List<ScheduledAlert> alerts, {
    bool silent = false,
  }) async {
    if (!supportsScheduling) return;
    try {
      await _plugin.cancelAllPendingNotifications();
      final mode = await _androidScheduleMode();
      for (final (i, alert) in alerts.indexed) {
        await _plugin.zonedSchedule(
          id: _scheduledBaseId + i,
          title: alert.message.title,
          body: alert.message.body,
          // Mốc tuyệt đối (UTC) nên không cần biết múi giờ máy.
          scheduledDate: tz.TZDateTime.from(alert.at.toUtc(), tz.UTC),
          notificationDetails: _details(silent: silent),
          androidScheduleMode: mode,
        );
      }
    } catch (e) {
      debugPrint('Không hẹn được thông báo: $e');
    }
  }

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  /// Bật (hoặc cập nhật) foreground service + thông báo đếm ngược.
  ///
  /// Service giữ tiến trình sống để engine tiếp tục chạy, phát âm thanh và
  /// chuyển pha khi màn hình tắt. Thông báo dùng chronometer nên đồng hồ
  /// vẫn đúng kể cả khi Dart tạm ngủ.
  Future<void> showOngoing(OngoingTimer timer) async {
    if (!supportsOngoing) return;
    try {
      await _android?.startForegroundService(
        id: _ongoingId,
        title: timer.title,
        body: timer.body,
        notificationDetails: AndroidNotificationDetails(
          _ongoingChannelId,
          _ongoingChannelName,
          channelDescription: 'Countdown while CYT runs in the background',
          importance: Importance.low,
          priority: Priority.low,
          ongoing: true,
          autoCancel: false,
          onlyAlertOnce: true,
          silent: true,
          category: AndroidNotificationCategory.stopwatch,
          showWhen: true,
          when: timer.at.millisecondsSinceEpoch,
          usesChronometer: true,
          chronometerCountDown: !timer.countUp,
        ),
        foregroundServiceTypes: const {
          AndroidServiceForegroundType.foregroundServiceTypeSpecialUse,
        },
      );
      _ongoingActive = true;
    } catch (e) {
      debugPrint('Không bật được foreground service: $e');
    }
  }

  Future<void> stopOngoing() async {
    if (!supportsOngoing || !_ongoingActive) return;
    try {
      await _android?.stopForegroundService();
      _ongoingActive = false;
    } catch (e) {
      debugPrint('Không tắt được foreground service: $e');
    }
  }

  Future<void> cancelScheduled() async {
    if (!supportsScheduling) return;
    try {
      await _plugin.cancelAllPendingNotifications();
    } catch (e) {
      debugPrint('Không huỷ được thông báo hẹn trước: $e');
    }
  }

  /// Dùng báo thức chính xác nếu được cấp quyền, không thì chấp nhận lệch
  /// vài phút (foreground service ở M7 sẽ xử lý triệt để).
  Future<AndroidScheduleMode> _androidScheduleMode() async {
    if (!Platform.isAndroid) return AndroidScheduleMode.exactAllowWhileIdle;
    final canExact = await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.canScheduleExactNotifications();
    return canExact == true
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
  }
}
