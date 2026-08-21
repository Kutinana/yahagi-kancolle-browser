package app.yahagi.kancollebrowser.notification

import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.content.ContextCompat

class NotificationProgressService : Service() {
    private val handler = Handler(Looper.getMainLooper())
    private val refreshRunnable = Runnable(::refreshAndSchedule)

    override fun onCreate() {
        super.onCreate()
        running = true
        AppNotificationManager.initChannels(this)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        handler.removeCallbacks(refreshRunnable)
        refreshAndSchedule()
        return START_STICKY
    }

    override fun onDestroy() {
        handler.removeCallbacks(refreshRunnable)
        running = false
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun refreshAndSchedule() {
        val snapshot = AppNotificationManager.loadSnapshot(this)
        val shouldShow = snapshot.presentation.enabled &&
            snapshot.presentation.ongoingLive &&
            snapshot.ongoingItems.isNotEmpty()
        if (!shouldShow) {
            stopForegroundCompat(removeNotification = true)
            getSystemService(NotificationManager::class.java)
                ?.cancel(AppNotificationManager.ONGOING_NOTIFICATION_ID)
            stopSelf()
            return
        }

        val notification = AppNotificationManager.buildOngoingNotification(this, snapshot)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(
                AppNotificationManager.ONGOING_NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE,
            )
        } else {
            startForeground(AppNotificationManager.ONGOING_NOTIFICATION_ID, notification)
        }

        val nowEpochMs = System.currentTimeMillis()
        val delayMs = NotificationProgressProjection.nextRefreshDelayMs(snapshot, nowEpochMs)
        if (delayMs == null) {
            stopForegroundCompat(removeNotification = false)
            stopSelf()
            return
        }
        handler.postDelayed(refreshRunnable, delayMs)
    }

    private fun stopForegroundCompat(removeNotification: Boolean) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(
                if (removeNotification) STOP_FOREGROUND_REMOVE else STOP_FOREGROUND_DETACH,
            )
        } else {
            @Suppress("DEPRECATION")
            stopForeground(removeNotification)
        }
    }

    companion object {
        @Volatile
        private var running = false

        fun sync(context: Context, snapshot: NativeNotificationSnapshot) {
            val intent = Intent(context, NotificationProgressService::class.java)
            if (NotificationProgressProjection.requiresRefresh(snapshot, System.currentTimeMillis())) {
                ContextCompat.startForegroundService(context, intent)
            } else if (running) {
                context.startService(intent)
            }
        }
    }
}
