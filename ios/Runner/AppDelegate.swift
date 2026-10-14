import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Cho phép flutter_local_notifications hiện thông báo khi app đang mở.
    UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  /// Độ sáng trước khi làm tối (iOS chỉnh độ sáng toàn máy nên phải trả lại).
  private var savedBrightness: CGFloat?

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    // Điều khiển màn hình cho chế độ tiết kiệm pin.
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "CytScreen") else {
      return
    }
    let channel = FlutterMethodChannel(name: "cyt/screen", binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "keepOn":
        UIApplication.shared.isIdleTimerDisabled = (call.arguments as? Bool) ?? false
        result(nil)
      case "setBrightness":
        let value = (call.arguments as? Double) ?? -1
        if value < 0 {
          // Trả lại độ sáng cũ.
          if let saved = self?.savedBrightness {
            UIScreen.main.brightness = saved
            self?.savedBrightness = nil
          }
        } else {
          if self?.savedBrightness == nil {
            self?.savedBrightness = UIScreen.main.brightness
          }
          UIScreen.main.brightness = CGFloat(value)
        }
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
