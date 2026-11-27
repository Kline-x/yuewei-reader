package com.kline.yuewei_reader

import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
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
    companion object {
        private const val MAX_FONT_FILE_BYTES = 30L * 1024L * 1024L
        private val mainHandler = Handler(Looper.getMainLooper())

        @Volatile
        private var activeBridgeToken: Any? = null

        @Volatile
        private var mediaCommandBridge: ((String) -> Unit)? = null

        fun registerMediaCommandBridge(token: Any, listener: (String) -> Unit) {
            activeBridgeToken = token
            mediaCommandBridge = listener
        }

        fun unregisterMediaCommandBridge(token: Any) {
            if (activeBridgeToken === token) {
                activeBridgeToken = null
                mediaCommandBridge = null
            }
        }

        fun dispatchMediaCommand(action: String) {
            mainHandler.post {
                mediaCommandBridge?.invoke(action)
            }
        }
    }

    private val channelName = "com.kline.yuewei/host_bridge"
    private val pickBookRequestCode = 9501
    private val pickFontRequestCode = 9504
    private var hostChannel: MethodChannel? = null
    private val bridgeToken = Any()
    private var pendingFilePickerResult: MethodChannel.Result? = null
    private var pendingFontPickerResult: MethodChannel.Result? = null
    private val ioExecutor = Executors.newSingleThreadExecutor()
    private var ttsAndBackupHelper: NativeTtsAndBackupHelper? = null
    private var appUpdateHelper: NativeAppUpdateHelper? = null

    @Volatile
    private var volumeKeyInterceptEnabled: Boolean = false

    private fun isAnyPickerBusy(helper: NativeTtsAndBackupHelper?): Boolean {
        return pendingFilePickerResult != null ||
            pendingFontPickerResult != null ||
            (helper?.isBusy == true)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        hostChannel = channel
        ttsAndBackupHelper?.shutdown()
        appUpdateHelper?.shutdown()
        val helper = NativeTtsAndBackupHelper(this, ioExecutor) { hostChannel }
        val updateHelper = NativeAppUpdateHelper(this, ioExecutor)
        ttsAndBackupHelper = helper
        appUpdateHelper = updateHelper

        registerMediaCommandBridge(bridgeToken) { action ->
            if (hostChannel === channel && !isFinishing && !isDestroyed) {
                channel.invokeMethod("onMediaCommand", mapOf("action" to action))
            }
        }

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
                    if (isAnyPickerBusy(helper)) {
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

                "pickFontFile" -> {
                    if (isAnyPickerBusy(helper)) {
                        result.error("PICKER_BUSY", "已有文件选择请求正在进行", null)
                        return@setMethodCallHandler
                    }
                    val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = "*/*"
                        putExtra(
                            Intent.EXTRA_MIME_TYPES,
                            arrayOf(
                                "font/ttf",
                                "font/otf",
                                "font/sfnt",
                                "application/x-font-ttf",
                                "application/x-font-opentype",
                                "application/font-sfnt",
                                "application/octet-stream"
                            )
                        )
                    }
                    pendingFontPickerResult = result
                    try {
                        @Suppress("DEPRECATION")
                        startActivityForResult(intent, pickFontRequestCode)
                    } catch (e: Exception) {
                        pendingFontPickerResult = null
                        result.error("PICKER_UNAVAILABLE", e.message ?: "无法打开字体选择器", null)
                    }
                }

                "ttsSpeak" -> {
                    val text = call.argument<String>("text") ?: ""
                    val utteranceId = call.argument<String>("utteranceId") ?: ""
                    val rate = call.argument<Number>("rate")?.toFloat() ?: 1.0f
                    helper.ttsSpeak(text, utteranceId, rate, result)
                }

                "ttsStop" -> helper.ttsStop(result)

                "ttsIsAvailable" -> helper.ttsIsAvailable(result)

                "updateMediaSession" -> {
                    val bookTitle = call.argument<String>("bookTitle") ?: ""
                    val author = call.argument<String>("author") ?: ""
                    val chapterTitle = call.argument<String>("chapterTitle") ?: ""
                    val isPlaying = call.argument<Boolean>("isPlaying") == true
                    val canPrev = call.argument<Boolean>("canPrev") == true
                    val canNext = call.argument<Boolean>("canNext") == true
                    val ok = TtsForegroundService.startOrUpdate(
                        context = this,
                        bookTitle = bookTitle,
                        author = author,
                        chapterTitle = chapterTitle,
                        isPlaying = isPlaying,
                        canPrev = canPrev,
                        canNext = canNext
                    )
                    result.success(ok)
                }

                "clearMediaSession" -> {
                    result.success(TtsForegroundService.stop(this))
                }

                "exportTextFile" -> {
                    val fileName = call.argument<String>("fileName") ?: "yuewei_backup.json"
                    val content = call.argument<String>("content") ?: ""
                    helper.exportTextFile(
                        fileName = fileName,
                        content = content,
                        isHostBusy = pendingFilePickerResult != null || pendingFontPickerResult != null,
                        result = result
                    )
                }

                "pickAndReadTextFile" -> {
                    helper.pickAndReadTextFile(
                        isHostBusy = pendingFilePickerResult != null || pendingFontPickerResult != null,
                        result = result
                    )
                }

                "installApk" -> {
                    val filePath = call.argument<String>("filePath") ?: ""
                    val expectedSha256 = call.argument<String>("expectedSha256")
                    updateHelper.installApk(
                        filePath = filePath,
                        expectedSha256 = expectedSha256,
                        result = result
                    )
                }

                "openExternalUrl" -> {
                    val url = call.argument<String>("url") ?: ""
                    updateHelper.openExternalUrl(url, result)
                }

                else -> result.notImplemented()
            }
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (ttsAndBackupHelper?.onActivityResult(requestCode, resultCode, data) == true) {
            return
        }
        when (requestCode) {
            pickBookRequestCode -> {
                val pending = pendingFilePickerResult
                pendingFilePickerResult = null
                if (pending != null) {
                    copyPickedUriToCache(
                        resultCode = resultCode,
                        data = data,
                        pending = pending,
                        targetSubDir = "picked_books",
                        maxBytes = null,
                        isFontPicker = false
                    )
                }
            }
            pickFontRequestCode -> {
                val pending = pendingFontPickerResult
                pendingFontPickerResult = null
                if (pending != null) {
                    copyPickedUriToCache(
                        resultCode = resultCode,
                        data = data,
                        pending = pending,
                        targetSubDir = "picked_fonts",
                        maxBytes = MAX_FONT_FILE_BYTES,
                        isFontPicker = true
                    )
                }
            }
            else -> {
                @Suppress("DEPRECATION")
                super.onActivityResult(requestCode, resultCode, data)
            }
        }
    }

    private fun copyPickedUriToCache(
        resultCode: Int,
        data: Intent?,
        pending: MethodChannel.Result,
        targetSubDir: String,
        maxBytes: Long?,
        isFontPicker: Boolean
    ) {
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            pending.success(null)
            return
        }

        ioExecutor.execute {
            var destFile: File? = null
            try {
                if (maxBytes != null) {
                    val knownSize = resolveFileSize(uri)
                    if (knownSize > maxBytes) {
                        throw IllegalArgumentException("字体文件体积超过 30MB 安全上限")
                    }
                }
                val displayName = resolveDisplayName(uri, isFontPicker)
                val targetDir = File(cacheDir, targetSubDir).apply { mkdirs() }
                val safeName = sanitizePickedFileName(displayName, uri, isFontPicker)
                val candidate = File(targetDir, "${System.currentTimeMillis()}_$safeName")
                val targetPrefix =
                    targetDir.canonicalPath.trimEnd(File.separatorChar) + File.separator
                if (!candidate.canonicalPath.startsWith(targetPrefix)) {
                    throw SecurityException("非法目标文件路径")
                }
                destFile = candidate
                contentResolver.openInputStream(uri)?.use { input ->
                    FileOutputStream(candidate).use { output ->
                        val buffer = ByteArray(16 * 1024)
                        var total = 0L
                        while (true) {
                            val count = input.read(buffer)
                            if (count <= 0) break
                            total += count
                            if (maxBytes != null && total > maxBytes) {
                                throw IllegalArgumentException("字体文件体积超过 30MB 安全上限")
                            }
                            output.write(buffer, 0, count)
                        }
                        output.flush()
                    }
                } ?: throw IllegalStateException("无法打开选中文件输入流")

                val payload = mapOf(
                    "path" to candidate.absolutePath,
                    "name" to displayName,
                    "size" to candidate.length()
                )
                runOnUiThread {
                    if (!isFinishing && !isDestroyed) pending.success(payload)
                }
            } catch (e: Exception) {
                try {
                    if (destFile?.exists() == true) {
                        destFile.delete()
                    }
                } catch (_: Exception) {
                }
                runOnUiThread {
                    if (!isFinishing && !isDestroyed) {
                        pending.error("COPY_FAILED", e.message ?: "读取选中文件失败", null)
                    }
                }
            }
        }
    }

    private fun resolveDisplayName(uri: Uri, isFontPicker: Boolean): String {
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
        if (!seg.isNullOrEmpty()) return seg
        return if (isFontPicker) {
            "font_${System.currentTimeMillis()}.ttf"
        } else {
            "book_${System.currentTimeMillis()}.txt"
        }
    }

    private fun resolveFileSize(uri: Uri): Long {
        contentResolver.query(
            uri,
            arrayOf(OpenableColumns.SIZE),
            null,
            null,
            null
        )?.use { cursor ->
            if (cursor.moveToFirst()) {
                val idx = cursor.getColumnIndex(OpenableColumns.SIZE)
                if (idx >= 0 && !cursor.isNull(idx)) {
                    return cursor.getLong(idx)
                }
            }
        }
        return -1L
    }

    private fun sanitizePickedFileName(
        rawName: String,
        uri: Uri,
        isFontPicker: Boolean
    ): String {
        val base = rawName.substringAfterLast('/').substringAfterLast('\\').trim()
        var safe = base.replace(Regex("[^a-zA-Z0-9._\\-\\u4E00-\\u9FFF]"), "_")
            .replace(Regex("^\\.+"), "")
        if (safe.isEmpty()) {
            safe = if (isFontPicker) "font" else "book"
        }
        if (!safe.contains('.')) {
            val mime = contentResolver.getType(uri)?.lowercase() ?: ""
            if (isFontPicker) {
                safe += if (mime.contains("otf") || mime.contains("opentype")) {
                    ".otf"
                } else {
                    ".ttf"
                }
            } else {
                if (mime.contains("epub")) {
                    safe += ".epub"
                } else if (mime.contains("text")) {
                    safe += ".txt"
                }
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

    override fun onKeyUp(keyCode: Int, event: KeyEvent?): Boolean {
        if (volumeKeyInterceptEnabled &&
            (keyCode == KeyEvent.KEYCODE_VOLUME_DOWN || keyCode == KeyEvent.KEYCODE_VOLUME_UP)
        ) {
            return true
        }
        return super.onKeyUp(keyCode, event)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        volumeKeyInterceptEnabled = false
        unregisterMediaCommandBridge(bridgeToken)
        pendingFilePickerResult?.success(null)
        pendingFilePickerResult = null
        pendingFontPickerResult?.success(null)
        pendingFontPickerResult = null
        hostChannel?.setMethodCallHandler(null)
        hostChannel = null
        ttsAndBackupHelper?.shutdown()
        ttsAndBackupHelper = null
        appUpdateHelper?.shutdown()
        appUpdateHelper = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun onDestroy() {
        volumeKeyInterceptEnabled = false
        unregisterMediaCommandBridge(bridgeToken)
        pendingFilePickerResult?.success(null)
        pendingFilePickerResult = null
        pendingFontPickerResult?.success(null)
        pendingFontPickerResult = null
        ttsAndBackupHelper?.shutdown()
        ttsAndBackupHelper = null
        appUpdateHelper?.shutdown()
        appUpdateHelper = null
        ioExecutor.shutdownNow()
        super.onDestroy()
    }
}
