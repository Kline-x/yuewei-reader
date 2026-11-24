package com.kline.yuewei_reader

import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.OpenableColumns
import android.view.KeyEvent
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.Executors

/**
 * 阅微 Android 原生宿主桥梁
 * 严格践行受控音量键拦截：默认放行系统调音，仅阅读界面主动开启后才捕获上下键。
 */
class MainActivity : FlutterActivity() {
    private val channelName = "com.kline.yuewei/host_bridge"
    private val pickBookRequestCode = 9501
    private var hostChannel: MethodChannel? = null
    private var pendingFilePickerResult: MethodChannel.Result? = null
    private val ioExecutor = Executors.newSingleThreadExecutor()

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

                "pickLocalBookFile" -> {
                    if (pendingFilePickerResult != null) {
                        result.error("PICKER_BUSY", "已有文件选择请求正在进行", null)
                        return@setMethodCallHandler
                    }
                    val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = "*/*"
                        putExtra(
                            Intent.EXTRA_MIME_TYPES,
                            arrayOf(
                                "text/plain",
                                "application/epub+zip",
                                "application/octet-stream"
                            )
                        )
                    }
                    pendingFilePickerResult = result
                    try {
                        @Suppress("DEPRECATION")
                        startActivityForResult(intent, pickBookRequestCode)
                    } catch (e: Exception) {
                        pendingFilePickerResult = null
                        result.error("PICKER_UNAVAILABLE", e.message ?: "无法打开文档选择器", null)
                    }
                }

                else -> result.notImplemented()
            }
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode != pickBookRequestCode) {
            @Suppress("DEPRECATION")
            super.onActivityResult(requestCode, resultCode, data)
            return
        }
        val pending = pendingFilePickerResult
        pendingFilePickerResult = null
        if (pending == null) return

        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            pending.success(null)
            return
        }

        ioExecutor.execute {
            try {
                val displayName = resolveDisplayName(uri)
                val targetDir = File(cacheDir, "picked_books").apply { mkdirs() }
                val safeName = sanitizePickedFileName(displayName, uri)
                val destFile = File(targetDir, "${System.currentTimeMillis()}_$safeName")
                val targetPrefix = targetDir.canonicalPath.trimEnd(File.separatorChar) + File.separator
                if (!destFile.canonicalPath.startsWith(targetPrefix)) {
                    throw SecurityException("非法目标文件路径")
                }
                contentResolver.openInputStream(uri)?.use { input ->
                    FileOutputStream(destFile).use { output ->
                        val buffer = ByteArray(16 * 1024)
                        while (true) {
                            val count = input.read(buffer)
                            if (count <= 0) break
                            output.write(buffer, 0, count)
                        }
                        output.flush()
                    }
                } ?: throw IllegalStateException("无法打开选中文件输入流")

                val payload = mapOf(
                    "path" to destFile.absolutePath,
                    "name" to displayName,
                    "size" to destFile.length()
                )
                runOnUiThread { pending.success(payload) }
            } catch (e: Exception) {
                runOnUiThread {
                    pending.error("COPY_FAILED", e.message ?: "读取选中文件失败", null)
                }
            }
        }
    }

    private fun resolveDisplayName(uri: Uri): String {
        contentResolver.query(
            uri,
            arrayOf(OpenableColumns.DISPLAY_NAME),
            null,
            null,
            null
        )?.use { cursor ->
            if (cursor.moveToFirst()) {
                val idx = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (idx >= 0) {
                    val name = cursor.getString(idx)?.trim()
                    if (!name.isNullOrEmpty()) return name
                }
            }
        }
        val seg = uri.lastPathSegment?.substringAfterLast('/')?.trim()
        return if (!seg.isNullOrEmpty()) seg else "book_${System.currentTimeMillis()}.txt"
    }

    private fun sanitizePickedFileName(rawName: String, uri: Uri): String {
        val base = rawName.substringAfterLast('/').substringAfterLast('\\').trim()
        var safe = base.replace(Regex("[^a-zA-Z0-9._\\-\\u4E00-\\u9FFF]"), "_")
            .replace(Regex("^\\.+"), "")
        if (safe.isEmpty()) safe = "book"
        if (!safe.contains('.')) {
            val mime = contentResolver.getType(uri)?.lowercase() ?: ""
            if (mime.contains("epub")) {
                safe += ".epub"
            } else if (mime.contains("text")) {
                safe += ".txt"
            }
        }
        return safe
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
        pendingFilePickerResult?.success(null)
        pendingFilePickerResult = null
        ioExecutor.shutdownNow()
        super.onDestroy()
    }
}
