package com.kline.yuewei_reader

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.security.MessageDigest
import java.util.Locale
import java.util.concurrent.ExecutorService

/**
 * Android 应用内在线更新与外链跳转原生辅助器
 * 负责后台校验 APK 文件完整性（SHA-256）、未知来源安装权限检查、FileProvider 安全调起安装器及外链校验跳转。
 */
class NativeAppUpdateHelper(
    private val activity: Activity,
    private val ioExecutor: ExecutorService
) {
    companion object {
        private const val UPDATES_SUBDIR = "yuewei_updates"
        private const val APK_MIME_TYPE = "application/vnd.android.package-archive"
    }

    @Volatile
    private var isShutdown: Boolean = false

    fun installApk(
        filePath: String,
        expectedSha256: String?,
        result: MethodChannel.Result
    ) {
        if (isShutdown) {
            result.success("FAILED:宿主已释放")
            return
        }
        val cleanPath = filePath.trim()
        if (cleanPath.isEmpty()) {
            result.success("FAILED:安装包路径为空")
            return
        }

        ioExecutor.execute {
            try {
                val updatesDir = File(activity.cacheDir, UPDATES_SUBDIR)
                val apkFile = File(cleanPath)
                if (!apkFile.exists() || !apkFile.isFile || apkFile.length() <= 0L) {
                    deliverSuccess(result, "FAILED:安装包文件不存在或为空")
                    return@execute
                }
                val allowedPrefix =
                    updatesDir.canonicalPath.trimEnd(File.separatorChar) + File.separator
                if (!apkFile.canonicalPath.startsWith(allowedPrefix)) {
                    deliverSuccess(result, "FAILED:安装包路径不在安全更新目录内")
                    return@execute
                }

                val expected = expectedSha256?.trim()?.lowercase(Locale.ROOT)
                if (!expected.isNullOrEmpty()) {
                    val actual = computeFileSha256(apkFile)
                    if (actual != expected) {
                        deliverSuccess(result, "HASH_MISMATCH")
                        return@execute
                    }
                }

                activity.runOnUiThread {
                    if (isShutdown || activity.isFinishing || activity.isDestroyed) return@runOnUiThread
                    launchSystemInstaller(apkFile, result)
                }
            } catch (e: Exception) {
                deliverSuccess(result, "FAILED:${e.message ?: e.javaClass.simpleName}")
            }
        }
    }

    fun openExternalUrl(rawUrl: String, result: MethodChannel.Result) {
        if (isShutdown) {
            result.success(false)
            return
        }
        val trimmed = rawUrl.trim()
        val uri = try {
            Uri.parse(trimmed)
        } catch (_: Exception) {
            null
        }
        val scheme = uri?.scheme?.lowercase(Locale.ROOT)
        if (uri == null || (scheme != "http" && scheme != "https") || uri.host.isNullOrBlank()) {
            result.success(false)
            return
        }

        activity.runOnUiThread {
            if (isShutdown || activity.isFinishing || activity.isDestroyed) {
                result.success(false)
                return@runOnUiThread
            }
            try {
                val intent = Intent(Intent.ACTION_VIEW, uri).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                activity.startActivity(intent)
                result.success(true)
            } catch (_: Exception) {
                result.success(false)
            }
        }
    }

    fun shutdown() {
        isShutdown = true
    }

    private fun launchSystemInstaller(apkFile: File, result: MethodChannel.Result) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
                !activity.packageManager.canRequestPackageInstalls()
            ) {
                val settingsIntent = Intent(
                    Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                    Uri.parse("package:${activity.packageName}")
                ).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                try {
                    activity.startActivity(settingsIntent)
                } catch (_: Exception) {
                    val fallbackIntent = Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    activity.startActivity(fallbackIntent)
                }
                result.success("NEED_INSTALL_PERMISSION")
                return
            }

            val authority = "${activity.packageName}.fileprovider"
            val apkUri = FileProvider.getUriForFile(activity, authority, apkFile)
            val installIntent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(apkUri, APK_MIME_TYPE)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            activity.startActivity(installIntent)
            result.success("STARTED")
        } catch (e: Exception) {
            result.success("FAILED:${e.message ?: e.javaClass.simpleName}")
        }
    }

    private fun computeFileSha256(file: File): String {
        val digest = MessageDigest.getInstance("SHA-256")
        val buffer = ByteArray(16 * 1024)
        FileInputStream(file).use { input ->
            while (true) {
                val count = input.read(buffer)
                if (count <= 0) break
                digest.update(buffer, 0, count)
            }
        }
        return digest.digest().joinToString("") { "%02x".format(it) }
    }

    private fun deliverSuccess(result: MethodChannel.Result, status: String) {
        activity.runOnUiThread {
            if (!isShutdown && !activity.isFinishing && !activity.isDestroyed) {
                result.success(status)
            }
        }
    }
}
