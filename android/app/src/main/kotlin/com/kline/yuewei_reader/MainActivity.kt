package com.kline.yuewei_reader

import android.content.pm.PackageManager
import android.os.Build
import android.view.KeyEvent
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * 阅微 Android 原生宿主桥梁
 * 严格践行受控音量键拦截：默认放行系统调音，仅阅读界面主动开启后才捕获上下键。
 */
class MainActivity : FlutterActivity() {
    private val channelName = "com.kline.yuewei/host_bridge"
    private var hostChannel: MethodChannel? = null

    @Volatile
    private var volumeKeyInterceptEnabled: Boolean = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        hostChannel = channel
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getHostCapabilities" -> {
                    val pkgInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        packageManager.getPackageInfo(
                            packageName,
                            PackageManager.PackageInfoFlags.of(0)
                        )
                    } else {
                        @Suppress("DEPRECATION")
                        packageManager.getPackageInfo(packageName, 0)
                    }
                    val vCode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                        pkgInfo.longVersionCode.toInt()
                    } else {
                        @Suppress("DEPRECATION")
                        pkgInfo.versionCode
                    }
                    result.success(
                        mapOf(
                            "platform" to "android",
                            "supportsVolumeKeyPaging" to true,
                            "versionName" to (pkgInfo.versionName ?: "1.0.0"),
                            "versionCode" to vCode
                        )
                    )
                }

                "setVolumeKeyIntercept" -> {
                    volumeKeyInterceptEnabled = call.argument<Boolean>("enabled") == true
                    result.success(true)
                }

                "keepScreenOn" -> {
                    val enabled = call.argument<Boolean>("enabled") == true
                    runOnUiThread {
                        if (enabled) {
                            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        } else {
                            window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        }
                    }
                    result.success(true)
                }

                else -> result.notImplemented()
            }
        }
    }

    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        if (volumeKeyInterceptEnabled) {
            if (keyCode == KeyEvent.KEYCODE_VOLUME_DOWN) {
                hostChannel?.invokeMethod("onVolumeDown", null)
                return true
            }
            if (keyCode == KeyEvent.KEYCODE_VOLUME_UP) {
                hostChannel?.invokeMethod("onVolumeUp", null)
                return true
            }
        }
        return super.onKeyDown(keyCode, event)
    }

    override fun onDestroy() {
        volumeKeyInterceptEnabled = false
        super.onDestroy()
    }
}
