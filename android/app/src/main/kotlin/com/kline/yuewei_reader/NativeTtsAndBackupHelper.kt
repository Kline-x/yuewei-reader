package com.kline.yuewei_reader

import android.app.Activity
import android.content.Intent
import android.media.AudioAttributes
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.OpenableColumns
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.nio.ByteBuffer
import java.nio.charset.CharacterCodingException
import java.nio.charset.CodingErrorAction
import java.util.Locale
import java.util.concurrent.ExecutorService

/**
 * Android 原生 TTS 语音合成与文本备份导入导出辅助器
 */
class NativeTtsAndBackupHelper(
    private val activity: Activity,
    private val ioExecutor: ExecutorService,
    private val channelProvider: () -> MethodChannel?
) {
    companion object {
        const val EXPORT_TEXT_REQUEST_CODE = 9502
        const val PICK_TEXT_REQUEST_CODE = 9503
        private const val MAX_TEXT_FILE_BYTES = 30 * 1024 * 1024 // 30MB 上限防 OOM
    }

    private data class PendingSpeak(
        val text: String,
        val utteranceId: String,
        val rate: Float,
        val result: MethodChannel.Result
    )

    private val mainHandler = Handler(Looper.getMainLooper())
    private var tts: TextToSpeech? = null
    // 0: 未初始化, 1: 初始化中, 2: 就绪可用, -1: 不可用
    private var ttsInitState: Int = 0
    private var initEpoch: Int = 0
    private var pendingSpeak: PendingSpeak? = null
    private val pendingAvailChecks = mutableListOf<MethodChannel.Result>()

    @Volatile
    private var isShutdown: Boolean = false

    @Volatile
    private var activeUtteranceId: String? = null

    private var pendingExportResult: MethodChannel.Result? = null
    private var pendingExportContent: String? = null
    private var pendingExportFallbackName: String = "yuewei_backup.json"
    private var pendingPickTextResult: MethodChannel.Result? = null

    val isBusy: Boolean
        get() = pendingExportResult != null || pendingPickTextResult != null

    fun ttsIsAvailable(result: MethodChannel.Result) {
        if (isShutdown) {
            result.success(false)
            return
        }
        mainHandler.post {
            if (isShutdown) {
                result.success(false)
                return@post
            }
            when (ttsInitState) {
                2 -> result.success(true)
                -1 -> {
                    resetFailedTts()
                    enqueueAvailabilityCheck(result)
                    ensureTtsInitialized()
                }
                else -> {
                    enqueueAvailabilityCheck(result)
                    ensureTtsInitialized()
                }
            }
        }
    }

    private fun enqueueAvailabilityCheck(result: MethodChannel.Result) {
        pendingAvailChecks.add(result)
        mainHandler.postDelayed({
            if (!isShutdown && pendingAvailChecks.remove(result)) {
                result.success(ttsInitState == 2)
            }
        }, 3000L)
    }

    fun ttsSpeak(
        text: String,
        utteranceId: String,
        rate: Float,
        result: MethodChannel.Result
    ) {
        if (isShutdown || text.isBlank() || utteranceId.isBlank()) {
            result.success(false)
            return
        }
        mainHandler.post {
            if (isShutdown) {
                result.success(false)
                return@post
            }
            if (ttsInitState == 2 && tts != null) {
                performSpeak(text, utteranceId, rate, result)
                return@post
            }
            if (ttsInitState == -1) {
                resetFailedTts()
            }
            // 初始化未完成时缓存最新待播请求，防止首句被吞
            enqueuePendingSpeak(text, utteranceId, rate, result)
        }
    }

    private fun enqueuePendingSpeak(
        text: String,
        utteranceId: String,
        rate: Float,
        result: MethodChannel.Result
    ) {
        pendingSpeak?.result?.success(false)
        val req = PendingSpeak(text, utteranceId, rate, result)
        pendingSpeak = req
        ensureTtsInitialized()
        mainHandler.postDelayed({
            if (!isShutdown && pendingSpeak === req) {
                pendingSpeak = null
                req.result.success(false)
            }
        }, 4000L)
    }

    fun ttsStop(result: MethodChannel.Result) {
        if (isShutdown) {
            result.success(false)
            return
        }
        mainHandler.post {
            activeUtteranceId = null
            pendingSpeak?.result?.success(false)
            pendingSpeak = null
            val engine = tts
            if (engine != null) {
                val stopped = try {
                    engine.stop() == TextToSpeech.SUCCESS
                } catch (_: Exception) {
                    false
                }
                if (!stopped) {
                    resetFailedTts()
                }
            }
            result.success(true)
        }
    }

    private fun resetFailedTts() {
        initEpoch++
        try {
            tts?.stop()
            tts?.shutdown()
        } catch (_: Exception) {
        }
        tts = null
        ttsInitState = 0
    }

    private fun ensureTtsInitialized() {
        if (isShutdown || ttsInitState != 0) return
        ttsInitState = 1
        val epoch = ++initEpoch
        try {
            lateinit var engine: TextToSpeech
            engine = TextToSpeech(activity.applicationContext) { status ->
                mainHandler.post {
                    if (isShutdown || epoch != initEpoch) {
                        try {
                            engine.stop()
                            engine.shutdown()
                        } catch (_: Exception) {
                        }
                        return@post
                    }
                    onTtsInitCompleted(status, epoch)
                }
            }
            engine.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
                override fun onStart(utteranceId: String?) {}

                override fun onDone(utteranceId: String?) {
                    if (utteranceId.isNullOrEmpty()) return
                    mainHandler.post {
                        if (!isShutdown && utteranceId == activeUtteranceId) {
                            activeUtteranceId = null
                            channelProvider()?.invokeMethod(
                                "onTtsDone",
                                mapOf("utteranceId" to utteranceId)
                            )
                        }
                    }
                }

                @Deprecated("Deprecated in Java")
                override fun onError(utteranceId: String?) {
                    dispatchTtsError(utteranceId, "语音朗读失败")
                }

                override fun onError(utteranceId: String?, errorCode: Int) {
                    dispatchTtsError(utteranceId, "语音朗读失败($errorCode)")
                }
            })
            tts = engine
        } catch (_: Exception) {
            onTtsInitCompleted(TextToSpeech.ERROR, epoch)
        }
    }

    private fun dispatchTtsError(utteranceId: String?, message: String) {
        if (utteranceId.isNullOrEmpty()) return
        mainHandler.post {
            if (!isShutdown && utteranceId == activeUtteranceId) {
                activeUtteranceId = null
                channelProvider()?.invokeMethod(
                    "onTtsError",
                    mapOf("utteranceId" to utteranceId, "message" to message)
                )
            }
        }
    }

    private fun onTtsInitCompleted(status: Int, epoch: Int) {
        if (isShutdown || epoch != initEpoch) return
        val engine = tts
        if (status == TextToSpeech.SUCCESS && engine != null) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                engine.setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_MEDIA)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                        .build()
                )
            }
            // 中文 Locale 回退链：zh_CN -> CHINESE -> 系统默认
            var langStatus = engine.setLanguage(Locale.SIMPLIFIED_CHINESE)
            if (langStatus == TextToSpeech.LANG_MISSING_DATA ||
                langStatus == TextToSpeech.LANG_NOT_SUPPORTED
            ) {
                langStatus = engine.setLanguage(Locale.CHINESE)
            }
            if (langStatus == TextToSpeech.LANG_MISSING_DATA ||
                langStatus == TextToSpeech.LANG_NOT_SUPPORTED
            ) {
                langStatus = engine.setLanguage(Locale.getDefault())
            }
            ttsInitState = if (
                langStatus == TextToSpeech.LANG_MISSING_DATA ||
                langStatus == TextToSpeech.LANG_NOT_SUPPORTED
            ) -1 else 2
        } else {
            ttsInitState = -1
        }
        if (ttsInitState == -1) {
            try {
                engine?.stop()
                engine?.shutdown()
            } catch (_: Exception) {
            }
            tts = null
        }

        val checks = pendingAvailChecks.toList()
        pendingAvailChecks.clear()
        val available = ttsInitState == 2
        for (check in checks) {
            check.success(available)
        }

        val queued = pendingSpeak
        pendingSpeak = null
        if (queued != null) {
            if (available) {
                performSpeak(
                    queued.text,
                    queued.utteranceId,
                    queued.rate,
                    queued.result,
                    allowRetry = false
                )
            } else {
                queued.result.success(false)
            }
        }
    }

    private fun performSpeak(
        text: String,
        utteranceId: String,
        rate: Float,
        result: MethodChannel.Result,
        allowRetry: Boolean = true
    ) {
        val engine = tts
        if (isShutdown || engine == null) {
            result.success(false)
            return
        }
        val maxLen = TextToSpeech.getMaxSpeechInputLength()
        val safeText = if (maxLen > 0 && text.length > maxLen) text.substring(0, maxLen) else text
        val clampedRate = rate.coerceIn(0.5f, 2.5f)
        activeUtteranceId = utteranceId
        val code = try {
            engine.setSpeechRate(clampedRate)
            engine.speak(safeText, TextToSpeech.QUEUE_FLUSH, null, utteranceId)
        } catch (_: Exception) {
            TextToSpeech.ERROR
        }
        if (code != TextToSpeech.SUCCESS) {
            activeUtteranceId = null
            if (allowRetry) {
                // 系统冻结 TTS 引发 Binder 失效时清理僵尸引用并重连自动重播一次
                resetFailedTts()
                enqueuePendingSpeak(text, utteranceId, rate, result)
                return
            }
            result.success(false)
        } else {
            result.success(true)
        }
    }

    fun exportTextFile(
        fileName: String,
        content: String,
        isHostBusy: Boolean,
        result: MethodChannel.Result
    ) {
        if (isHostBusy || isBusy) {
            result.error("PICKER_BUSY", "已有文件选择请求正在进行", null)
            return
        }
        val safeTitle = fileName.trim().ifEmpty { "yuewei_backup.json" }
        val mime = if (safeTitle.lowercase(Locale.ROOT).endsWith(".txt")) {
            "text/plain"
        } else {
            "application/json"
        }
        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = mime
            putExtra(Intent.EXTRA_TITLE, safeTitle)
        }
        pendingExportResult = result
        pendingExportContent = content
        pendingExportFallbackName = safeTitle
        try {
            @Suppress("DEPRECATION")
            activity.startActivityForResult(intent, EXPORT_TEXT_REQUEST_CODE)
        } catch (e: Exception) {
            pendingExportResult = null
            pendingExportContent = null
            result.error("PICKER_UNAVAILABLE", e.message ?: "无法打开文件保存器", null)
        }
    }

    fun pickAndReadTextFile(isHostBusy: Boolean, result: MethodChannel.Result) {
        if (isHostBusy || isBusy) {
            result.error("PICKER_BUSY", "已有文件选择请求正在进行", null)
            return
        }
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "*/*"
            putExtra(
                Intent.EXTRA_MIME_TYPES,
                arrayOf(
                    "application/json",
                    "text/json",
                    "text/plain",
                    "application/octet-stream"
                )
            )
        }
        pendingPickTextResult = result
        try {
            @Suppress("DEPRECATION")
            activity.startActivityForResult(intent, PICK_TEXT_REQUEST_CODE)
        } catch (e: Exception) {
            pendingPickTextResult = null
            result.error("PICKER_UNAVAILABLE", e.message ?: "无法打开文档选择器", null)
        }
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        return when (requestCode) {
            EXPORT_TEXT_REQUEST_CODE -> {
                handleExportActivityResult(resultCode, data)
                true
            }
            PICK_TEXT_REQUEST_CODE -> {
                handlePickTextActivityResult(resultCode, data)
                true
            }
            else -> false
        }
    }

    private fun handleExportActivityResult(resultCode: Int, data: Intent?) {
        val pending = pendingExportResult
        val content = pendingExportContent
        val fallbackName = pendingExportFallbackName
        pendingExportResult = null
        pendingExportContent = null
        if (pending == null) return

        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null || content == null) {
            pending.success(null)
            return
        }

        ioExecutor.execute {
            try {
                val outStream = try {
                    activity.contentResolver.openOutputStream(uri, "wt")
                } catch (_: Exception) {
                    activity.contentResolver.openOutputStream(uri)
                } ?: throw IllegalStateException("无法打开目标文件输出流")

                outStream.use { out ->
                    out.write(content.toByteArray(Charsets.UTF_8))
                    out.flush()
                }
                val displayName = resolveDisplayName(uri, fallbackName)
                activity.runOnUiThread {
                    if (!isShutdown && !activity.isFinishing && !activity.isDestroyed) {
                        pending.success(displayName)
                    }
                }
            } catch (e: Exception) {
                activity.runOnUiThread {
                    if (!isShutdown && !activity.isFinishing && !activity.isDestroyed) {
                        pending.error("EXPORT_FAILED", e.message ?: "写入导出文件失败", null)
                    }
                }
            }
        }
    }

    private fun handlePickTextActivityResult(resultCode: Int, data: Intent?) {
        val pending = pendingPickTextResult
        pendingPickTextResult = null
        if (pending == null) return

        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            pending.success(null)
            return
        }

        ioExecutor.execute {
            try {
                val knownSize = resolveFileSize(uri)
                if (knownSize > MAX_TEXT_FILE_BYTES) {
                    throw IllegalArgumentException("文件体积超过 30MB 安全上限")
                }
                val bytes = activity.contentResolver.openInputStream(uri)?.use { input ->
                    val bos = ByteArrayOutputStream()
                    val buffer = ByteArray(16 * 1024)
                    var total = 0
                    while (true) {
                        val count = input.read(buffer)
                        if (count <= 0) break
                        total += count
                        if (total > MAX_TEXT_FILE_BYTES) {
                            throw IllegalArgumentException("文件体积超过 30MB 安全上限")
                        }
                        bos.write(buffer, 0, count)
                    }
                    bos.toByteArray()
                } ?: throw IllegalStateException("无法打开选中文件输入流")

                var text = try {
                    Charsets.UTF_8.newDecoder()
                        .onMalformedInput(CodingErrorAction.REPORT)
                        .onUnmappableCharacter(CodingErrorAction.REPORT)
                        .decode(ByteBuffer.wrap(bytes))
                        .toString()
                } catch (_: CharacterCodingException) {
                    throw IllegalArgumentException("文件非有效 UTF-8 文本格式")
                }
                if (text.startsWith("\uFEFF")) {
                    text = text.substring(1)
                }
                val displayName = resolveDisplayName(uri, "imported.json")
                val payload = mapOf(
                    "name" to displayName,
                    "content" to text
                )
                activity.runOnUiThread {
                    if (!isShutdown && !activity.isFinishing && !activity.isDestroyed) {
                        pending.success(payload)
                    }
                }
            } catch (e: Exception) {
                activity.runOnUiThread {
                    if (!isShutdown && !activity.isFinishing && !activity.isDestroyed) {
                        pending.error("READ_FAILED", e.message ?: "读取文本文件失败", null)
                    }
                }
            }
        }
    }

    private fun resolveDisplayName(uri: Uri, fallback: String): String {
        activity.contentResolver.query(
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
        return if (!seg.isNullOrEmpty()) seg else fallback
    }

    private fun resolveFileSize(uri: Uri): Long {
        activity.contentResolver.query(
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

    fun shutdown() {
        isShutdown = true
        initEpoch++
        mainHandler.removeCallbacksAndMessages(null)
        activeUtteranceId = null
        pendingSpeak?.result?.success(false)
        pendingSpeak = null
        val checks = pendingAvailChecks.toList()
        pendingAvailChecks.clear()
        for (check in checks) {
            check.success(false)
        }
        pendingExportResult?.success(null)
        pendingExportResult = null
        pendingExportContent = null
        pendingPickTextResult?.success(null)
        pendingPickTextResult = null
        try {
            tts?.stop()
            tts?.shutdown()
        } catch (_: Exception) {
        }
        tts = null
        ttsInitState = 0
    }
}
