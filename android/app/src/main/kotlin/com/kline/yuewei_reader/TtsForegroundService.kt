package com.kline.yuewei_reader

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.BitmapFactory
import android.graphics.drawable.Icon
import android.media.MediaMetadata
import android.media.session.MediaSession
import android.media.session.PlaybackState
import android.os.Build
import android.os.IBinder

/**
 * Android 原生 TTS 听书系统媒体控制与后台保活前台服务。
 * 纯基于 android.media.session.MediaSession 与 Notification.MediaStyle 构建，零额外依赖。
 */
class TtsForegroundService : Service() {
    companion object {
        private const val CHANNEL_ID = "yuewei_tts_playback"
        private const val CHANNEL_NAME = "听书后台播放控制"
        private const val NOTIF_ID = 9601

        private const val ACTION_UPDATE = "com.kline.yuewei.tts.ACTION_UPDATE"
        private const val ACTION_PLAY = "com.kline.yuewei.tts.ACTION_PLAY"
        private const val ACTION_PAUSE = "com.kline.yuewei.tts.ACTION_PAUSE"
        private const val ACTION_TOGGLE = "com.kline.yuewei.tts.ACTION_TOGGLE"
        private const val ACTION_NEXT = "com.kline.yuewei.tts.ACTION_NEXT"
        private const val ACTION_PREV = "com.kline.yuewei.tts.ACTION_PREV"
        private const val ACTION_STOP = "com.kline.yuewei.tts.ACTION_STOP"

        private const val EXTRA_BOOK_TITLE = "bookTitle"
        private const val EXTRA_AUTHOR = "author"
        private const val EXTRA_CHAPTER_TITLE = "chapterTitle"
        private const val EXTRA_IS_PLAYING = "isPlaying"
        private const val EXTRA_CAN_PREV = "canPrev"
        private const val EXTRA_CAN_NEXT = "canNext"

        private const val REQ_CONTENT = 9610
        private const val REQ_PREV = 9611
        private const val REQ_TOGGLE = 9612
        private const val REQ_NEXT = 9613
        private const val REQ_STOP = 9614
        private const val REQ_DELETE = 9615

        fun startOrUpdate(
            context: Context,
            bookTitle: String,
            author: String,
            chapterTitle: String,
            isPlaying: Boolean,
            canPrev: Boolean,
            canNext: Boolean
        ): Boolean {
            val appCtx = context.applicationContext
            val intent = Intent(appCtx, TtsForegroundService::class.java).apply {
                action = ACTION_UPDATE
                putExtra(EXTRA_BOOK_TITLE, bookTitle)
                putExtra(EXTRA_AUTHOR, author)
                putExtra(EXTRA_CHAPTER_TITLE, chapterTitle)
                putExtra(EXTRA_IS_PLAYING, isPlaying)
                putExtra(EXTRA_CAN_PREV, canPrev)
                putExtra(EXTRA_CAN_NEXT, canNext)
            }
            return try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    appCtx.startForegroundService(intent)
                } else {
                    appCtx.startService(intent)
                }
                true
            } catch (_: Exception) {
                // 兼容 Android 12+/14 后台启动前台服务限制或系统策略异常，防止闪退
                false
            }
        }

        fun stop(context: Context): Boolean {
            val appCtx = context.applicationContext
            return try {
                appCtx.stopService(Intent(appCtx, TtsForegroundService::class.java))
                true
            } catch (_: Exception) {
                false
            }
        }
    }

    private var mediaSession: MediaSession? = null
    private var hasEnteredForeground: Boolean = false
    private var lastBookTitle: String = "阅微听书"
    private var lastAuthor: String = ""
    private var lastChapterTitle: String = ""
    private var lastIsPlaying: Boolean = false
    private var lastCanPrev: Boolean = false
    private var lastCanNext: Boolean = false

    override fun onCreate() {
        super.onCreate()
        ensureNotificationChannel()
        ensureMediaSession()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_PLAY -> {
                ensureForegroundAliveIfNeeded()
                MainActivity.dispatchMediaCommand("play")
            }
            ACTION_PAUSE -> {
                ensureForegroundAliveIfNeeded()
                MainActivity.dispatchMediaCommand("pause")
            }
            ACTION_TOGGLE -> {
                ensureForegroundAliveIfNeeded()
                MainActivity.dispatchMediaCommand("toggle")
            }
            ACTION_NEXT -> {
                ensureForegroundAliveIfNeeded()
                MainActivity.dispatchMediaCommand("next")
            }
            ACTION_PREV -> {
                ensureForegroundAliveIfNeeded()
                MainActivity.dispatchMediaCommand("prev")
            }
            ACTION_STOP -> {
                MainActivity.dispatchMediaCommand("stop")
                stopForegroundAndSelf()
            }
            ACTION_UPDATE -> {
                val bookTitle = intent.getStringExtra(EXTRA_BOOK_TITLE)?.trim().orEmpty()
                val author = intent.getStringExtra(EXTRA_AUTHOR)?.trim().orEmpty()
                val chapterTitle = intent.getStringExtra(EXTRA_CHAPTER_TITLE)?.trim().orEmpty()
                lastBookTitle = bookTitle.ifEmpty { "阅微听书" }
                lastAuthor = author
                lastChapterTitle = chapterTitle
                lastIsPlaying = intent.getBooleanExtra(EXTRA_IS_PLAYING, true)
                lastCanPrev = intent.getBooleanExtra(EXTRA_CAN_PREV, false)
                lastCanNext = intent.getBooleanExtra(EXTRA_CAN_NEXT, false)
                updateSessionAndNotification()
            }
            else -> {
                if (!hasEnteredForeground) {
                    updateSessionAndNotification()
                    stopForegroundAndSelf()
                }
            }
        }
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        releaseMediaSession()
        if (hasEnteredForeground) {
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                    stopForeground(STOP_FOREGROUND_REMOVE)
                } else {
                    @Suppress("DEPRECATION")
                    stopForeground(true)
                }
            } catch (_: Exception) {
            }
            hasEnteredForeground = false
        }
        super.onDestroy()
    }

    private fun ensureNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java) ?: return
        if (manager.getNotificationChannel(CHANNEL_ID) != null) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            CHANNEL_NAME,
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = "用于系统锁屏与通知栏控制阅微语音朗读"
            setSound(null, null)
            enableVibration(false)
            setShowBadge(false)
        }
        manager.createNotificationChannel(channel)
    }

    private fun ensureMediaSession(): MediaSession {
        mediaSession?.let { return it }
        val session = MediaSession(this, "YueweiTtsMediaSession").apply {
            @Suppress("DEPRECATION")
            setFlags(
                MediaSession.FLAG_HANDLES_MEDIA_BUTTONS or
                    MediaSession.FLAG_HANDLES_TRANSPORT_CONTROLS
            )
            setCallback(object : MediaSession.Callback() {
                override fun onPlay() {
                    MainActivity.dispatchMediaCommand("play")
                }

                override fun onPause() {
                    MainActivity.dispatchMediaCommand("pause")
                }

                override fun onSkipToNext() {
                    MainActivity.dispatchMediaCommand("next")
                }

                override fun onSkipToPrevious() {
                    MainActivity.dispatchMediaCommand("prev")
                }

                override fun onStop() {
                    MainActivity.dispatchMediaCommand("stop")
                    stopForegroundAndSelf()
                }
            })
            isActive = true
        }
        mediaSession = session
        return session
    }

    private fun releaseMediaSession() {
        mediaSession?.let { session ->
            try {
                session.isActive = false
                session.setCallback(null)
                session.release()
            } catch (_: Exception) {
            }
        }
        mediaSession = null
    }

    private fun ensureForegroundAliveIfNeeded() {
        if (!hasEnteredForeground) {
            updateSessionAndNotification()
        }
    }

    private fun updateSessionAndNotification() {
        val session = ensureMediaSession()
        val displayChapter = lastChapterTitle.ifEmpty { lastBookTitle }
        val metadata = MediaMetadata.Builder()
            .putString(MediaMetadata.METADATA_KEY_TITLE, displayChapter)
            .putString(MediaMetadata.METADATA_KEY_ALBUM, lastBookTitle)
            .putString(
                MediaMetadata.METADATA_KEY_ARTIST,
                lastAuthor.ifEmpty { lastBookTitle }
            )
            .putString(MediaMetadata.METADATA_KEY_DISPLAY_TITLE, lastBookTitle)
            .putString(MediaMetadata.METADATA_KEY_DISPLAY_SUBTITLE, lastChapterTitle)
            .build()
        session.setMetadata(metadata)

        var allowedActions = PlaybackState.ACTION_PLAY or
            PlaybackState.ACTION_PAUSE or
            PlaybackState.ACTION_PLAY_PAUSE or
            PlaybackState.ACTION_STOP
        if (lastCanPrev) {
            allowedActions = allowedActions or PlaybackState.ACTION_SKIP_TO_PREVIOUS
        }
        if (lastCanNext) {
            allowedActions = allowedActions or PlaybackState.ACTION_SKIP_TO_NEXT
        }
        val stateCode = if (lastIsPlaying) {
            PlaybackState.STATE_PLAYING
        } else {
            PlaybackState.STATE_PAUSED
        }
        val state = PlaybackState.Builder()
            .setActions(allowedActions)
            .setState(
                stateCode,
                PlaybackState.PLAYBACK_POSITION_UNKNOWN,
                if (lastIsPlaying) 1.0f else 0.0f
            )
            .build()
        session.setPlaybackState(state)
        session.isActive = true

        val notification = buildMediaNotification(session)
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(
                    NOTIF_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK
                )
            } else {
                startForeground(NOTIF_ID, notification)
            }
            hasEnteredForeground = true
        } catch (_: Exception) {
            if (!hasEnteredForeground) {
                stopSelf()
            }
        }
    }

    private fun buildMediaNotification(session: MediaSession): Notification {
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this).setPriority(Notification.PRIORITY_LOW)
        }

        val largeIcon = try {
            BitmapFactory.decodeResource(resources, R.mipmap.ic_launcher_foreground)
        } catch (_: Exception) {
            null
        }

        builder
            .setSmallIcon(R.mipmap.ic_launcher_monochrome)
            .setContentTitle(lastBookTitle)
            .setContentText(lastChapterTitle.ifEmpty { "正在语音朗读" })
            .setOngoing(lastIsPlaying)
            .setOnlyAlertOnce(true)
            .setShowWhen(false)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setContentIntent(buildContentIntent())
            .setDeleteIntent(buildServiceIntent(ACTION_STOP, REQ_DELETE))

        if (lastAuthor.isNotEmpty()) {
            builder.setSubText(lastAuthor)
        }
        if (largeIcon != null) {
            builder.setLargeIcon(largeIcon)
        }

        val compactIndices = mutableListOf<Int>()
        var actionCount = 0
        if (lastCanPrev) {
            builder.addAction(
                buildAction(android.R.drawable.ic_media_previous, "上一节", ACTION_PREV, REQ_PREV)
            )
            compactIndices.add(actionCount)
            actionCount++
        }
        val toggleIcon = if (lastIsPlaying) {
            android.R.drawable.ic_media_pause
        } else {
            android.R.drawable.ic_media_play
        }
        val toggleTitle = if (lastIsPlaying) "暂停" else "继续"
        builder.addAction(buildAction(toggleIcon, toggleTitle, ACTION_TOGGLE, REQ_TOGGLE))
        compactIndices.add(actionCount)
        actionCount++

        if (lastCanNext) {
            builder.addAction(
                buildAction(android.R.drawable.ic_media_next, "下一节", ACTION_NEXT, REQ_NEXT)
            )
            compactIndices.add(actionCount)
        }
        builder.addAction(
            buildAction(android.R.drawable.ic_menu_close_clear_cancel, "关闭", ACTION_STOP, REQ_STOP)
        )

        val mediaStyle = Notification.MediaStyle()
            .setMediaSession(session.sessionToken)
        if (compactIndices.isNotEmpty()) {
            mediaStyle.setShowActionsInCompactView(*compactIndices.take(3).toIntArray())
        }
        builder.style = mediaStyle
        return builder.build()
    }

    private fun buildAction(
        iconRes: Int,
        title: String,
        action: String,
        requestCode: Int
    ): Notification.Action {
        val intent = buildServiceIntent(action, requestCode)
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Notification.Action.Builder(
                Icon.createWithResource(this, iconRes),
                title,
                intent
            ).build()
        } else {
            @Suppress("DEPRECATION")
            Notification.Action.Builder(iconRes, title, intent).build()
        }
    }

    private fun buildServiceIntent(action: String, requestCode: Int): PendingIntent {
        val intent = Intent(this, TtsForegroundService::class.java).apply {
            this.action = action
        }
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or pendingImmutableFlag()
        return PendingIntent.getService(this, requestCode, intent, flags)
    }

    private fun buildContentIntent(): PendingIntent {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
            ?: Intent(this, MainActivity::class.java)
        launchIntent.flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or pendingImmutableFlag()
        return PendingIntent.getActivity(this, REQ_CONTENT, launchIntent, flags)
    }

    private fun pendingImmutableFlag(): Int {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_IMMUTABLE
        } else {
            0
        }
    }

    private fun stopForegroundAndSelf() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                stopForeground(STOP_FOREGROUND_REMOVE)
            } else {
                @Suppress("DEPRECATION")
                stopForeground(true)
            }
        } catch (_: Exception) {
        }
        hasEnteredForeground = false
        releaseMediaSession()
        stopSelf()
    }
}
