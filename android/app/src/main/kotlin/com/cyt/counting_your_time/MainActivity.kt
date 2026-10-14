package com.cyt.counting_your_time

import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Điều khiển màn hình cho chế độ tiết kiệm pin: giữ sáng + độ sáng
        // riêng của cửa sổ app (không đổi cài đặt hệ thống).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "cyt/screen")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "keepOn" -> {
                        if (call.arguments as Boolean) {
                            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        } else {
                            window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        }
                        result.success(null)
                    }
                    "setBrightness" -> {
                        // < 0 = theo hệ thống.
                        val value = (call.arguments as Number).toFloat()
                        val attrs = window.attributes
                        attrs.screenBrightness =
                            if (value < 0) WindowManager.LayoutParams.BRIGHTNESS_OVERRIDE_NONE
                            else value.coerceIn(0.01f, 1f)
                        window.attributes = attrs
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
