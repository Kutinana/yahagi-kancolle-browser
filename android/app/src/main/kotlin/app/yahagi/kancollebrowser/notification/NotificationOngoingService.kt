package app.yahagi.kancollebrowser.notification

import android.app.Notification
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper

class NotificationOngoingService : Service() {
    companion object {
        const val ACTION_START = "app.yahagi.kancollebrowser.notification.START_ONGOING"
        const val ACTION_STOP = "app.yahagi.kancollebrowser.notification.STOP_ONGOING"

        @Volatile
        private var currentItems: List<Map<String, Any>> = emptyList()
        @Volatile
        private var showProgress: Boolean = true
        @Volatile
        private var showPercent: Boolean = true
        @Volatile
        private var showCountdown: Boolean = true

        fun start(
            context: Context,
            items: List<Map<String, Any>>,
            showProgress: Boolean,
            showPercent: Boolean,
            showCountdown: Boolean,
        ) {
            currentItems = items
            this.showProgress = showProgress
            this.showPercent = showPercent
            this.showCountdown = showCountdown

            val intent = Intent(context, NotificationOngoingService::class.java).apply {
                action = ACTION_START
            }
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(intent)
                } else {
                    context.startService(intent)
                }
            } catch (e: Exception) {
                // Fallback to direct notification if background service start is restricted
                AppNotificationManager.updateOngoingProgress(
                    context,
                    items,
                    showProgress,
                    showPercent,
                    showCountdown,
                )
            }
        }

        fun stop(context: Context) {
            currentItems = emptyList()
            val intent = Intent(context, NotificationOngoingService::class.java).apply {
                action = ACTION_STOP
            }
            try {
                context.startService(intent)
            } catch (_: Exception) {}
            AppNotificationManager.cancelOngoingProgress(context)
        }
    }

    private val handler = Handler(Looper.getMainLooper())
    private val tickRunnable = object : Runnable {
        override fun run() {
            updateNotification()
            handler.postDelayed(this, 1000)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP || currentItems.isEmpty()) {
            stopOngoing()
            return START_NOT_STICKY
        }

        val notification = AppNotificationManager.buildOngoingNotification(
            this,
            currentItems,
            showProgress,
            showPercent,
            showCountdown,
        )
        if (notification != null) {
            startForeground(AppNotificationManager.ONGOING_NOTIFICATION_ID, notification)
        } else {
            stopOngoing()
            return START_NOT_STICKY
        }

        handler.removeCallbacks(tickRunnable)
        handler.postDelayed(tickRunnable, 1000)
        return START_STICKY
    }

    private fun updateNotification() {
        if (currentItems.isEmpty()) {
            stopOngoing()
            return
        }

        // Recalculate remaining seconds against wall clock
        val now = System.currentTimeMillis()
        var hasActive = false
        val updatedItems = currentItems.map { item ->
            val targetMs = (item["targetEpochMs"] as? Number)?.toLong()
                ?: (now + ((item["remainingSeconds"] as? Number)?.toLong() ?: 0L) * 1000L)
            val totalSec = (item["totalDurationSec"] as? Number)?.toInt() ?: 3600
            val remainingSec = ((targetMs - now) / 1000L).toInt().coerceAtLeast(0)
            val pct = if (totalSec > 0) {
                (1.0 - (remainingSec.toDouble() / totalSec)).coerceIn(0.0, 1.0)
            } else {
                1.0
            }
            if (remainingSec > 0) {
                hasActive = true
            }
            val mutable = HashMap(item)
            mutable["remainingSeconds"] = remainingSec
            mutable["progress"] = pct
            mutable
        }
        currentItems = updatedItems

        if (!hasActive) {
            stopOngoing()
            return
        }

        val notification = AppNotificationManager.buildOngoingNotification(
            this,
            updatedItems,
            showProgress,
            showPercent,
            showCountdown,
        )
        if (notification != null) {
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
            notificationManager?.notify(AppNotificationManager.ONGOING_NOTIFICATION_ID, notification)
        } else {
            stopOngoing()
        }
    }

    private fun stopOngoing() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
        notificationManager?.cancel(AppNotificationManager.ONGOING_NOTIFICATION_ID)
        stopSelf()
    }

    override fun onDestroy() {
        super.onDestroy()
        handler.removeCallbacks(tickRunnable)
    }
}
