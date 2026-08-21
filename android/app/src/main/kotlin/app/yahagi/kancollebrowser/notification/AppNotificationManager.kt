package app.yahagi.kancollebrowser.notification

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Build
import android.view.View
import android.widget.RemoteViews
import androidx.core.app.NotificationCompat
import app.yahagi.kancollebrowser.MainActivity
import app.yahagi.kancollebrowser.R

object AppNotificationManager {
    const val ONGOING_NOTIFICATION_ID = 999
    val VIBRATION_PATTERN = longArrayOf(0, 255, 90, 255)

    private val CHANNELS = mapOf(
        "channel_expedition" to "远征通知",
        "channel_repair" to "入渠修复",
        "channel_anchorage" to "泊地修理",
        "channel_construction" to "工厂建造",
        "channel_morale" to "士气与刷闪",
    )
    const val ONGOING_CHANNEL_ID = "channel_ongoing"
    const val ONGOING_CHANNEL_NAME = "母港实时进行中概览"

    fun initChannels(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager ?: return

        val soundUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
        val audioAttributes = AudioAttributes.Builder()
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .setUsage(AudioAttributes.USAGE_NOTIFICATION)
            .build()

        // 1. Event Alert Channels (High Importance with [255, 90, 255] Vibration Waveform)
        for ((channelId, channelName) in CHANNELS) {
            val channel = NotificationChannel(
                channelId,
                channelName,
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                enableVibration(true)
                vibrationPattern = VIBRATION_PATTERN
                setSound(soundUri, audioAttributes)
                lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
                setShowBadge(true)
            }
            notificationManager.createNotificationChannel(channel)
        }

        // 2. Ongoing Progress Channel (Low Importance, Silent & Persistent)
        val ongoingChannel = NotificationChannel(
            ONGOING_CHANNEL_ID,
            ONGOING_CHANNEL_NAME,
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            enableVibration(false)
            setSound(null, null)
            lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
            setShowBadge(false)
        }
        notificationManager.createNotificationChannel(ongoingChannel)
    }

    fun scheduleAlarm(
        context: Context,
        key: String,
        channelId: String,
        triggerTimeEpochMs: Long,
        title: String,
        body: String,
    ) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        val intent = Intent(context, NotificationAlarmReceiver::class.java).apply {
            putExtra("key", key)
            putExtra("channelId", channelId)
            putExtra("title", title)
            putExtra("body", body)
        }

        val requestCode = key.hashCode()
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        val pendingIntent = PendingIntent.getBroadcast(context, requestCode, intent, flags)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            alarmManager.setExactAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                triggerTimeEpochMs,
                pendingIntent,
            )
        } else {
            alarmManager.setExact(
                AlarmManager.RTC_WAKEUP,
                triggerTimeEpochMs,
                pendingIntent,
            )
        }
    }

    fun cancelAlarm(context: Context, key: String) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        val intent = Intent(context, NotificationAlarmReceiver::class.java)
        val requestCode = key.hashCode()
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_NO_CREATE
        }
        val pendingIntent = PendingIntent.getBroadcast(context, requestCode, intent, flags)
        if (pendingIntent != null) {
            alarmManager.cancel(pendingIntent)
            pendingIntent.cancel()
        }
    }

    fun buildOngoingNotification(
        context: Context,
        items: List<Map<String, Any>>,
        showProgress: Boolean,
        showPercent: Boolean,
        showCountdown: Boolean,
    ): android.app.Notification? {
        if (items.isEmpty()) return null

        val launchIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        val pendingIntent = PendingIntent.getActivity(context, 0, launchIntent, flags)

        val headerTitle = "矢矧 · 母港实时进行中 (${items.size} 项)"

        // Collapsed View (RemoteViews)
        val collapsedView = RemoteViews(context.packageName, R.layout.notification_ongoing_collapsed)
        val firstItem = items[0]
        val firstTitle = firstItem["title"] as? String ?: "任务进行中"
        val firstSec = (firstItem["remainingSeconds"] as? Number)?.toInt() ?: 0
        val firstPct = (((firstItem["progress"] as? Number)?.toDouble() ?: 0.0) * 100).toInt().coerceIn(0, 100)
        val firstH = firstSec / 3600
        val firstM = (firstSec % 3600) / 60
        val firstS = firstSec % 60
        val firstTimeStr = String.format("%02d:%02d:%02d", firstH, firstM, firstS)

        collapsedView.setTextViewText(R.id.notif_collapsed_title, firstTitle)
        val firstStats = when {
            showPercent && showCountdown -> "$firstPct%  $firstTimeStr"
            showPercent -> "$firstPct%"
            showCountdown -> firstTimeStr
            else -> ""
        }
        collapsedView.setTextViewText(R.id.notif_collapsed_stats, firstStats)
        if (showProgress) {
            collapsedView.setViewVisibility(R.id.notif_collapsed_progress, View.VISIBLE)
            collapsedView.setProgressBar(R.id.notif_collapsed_progress, 100, firstPct, false)
        } else {
            collapsedView.setViewVisibility(R.id.notif_collapsed_progress, View.GONE)
        }

        // Expanded View (RemoteViews)
        val expandedView = RemoteViews(context.packageName, R.layout.notification_ongoing_expanded)

        val itemContainerIds = intArrayOf(
            R.id.notif_item_1,
            R.id.notif_item_2,
            R.id.notif_item_3,
            R.id.notif_item_4,
            R.id.notif_item_5,
        )
        val itemTitleIds = intArrayOf(
            R.id.notif_item_1_title,
            R.id.notif_item_2_title,
            R.id.notif_item_3_title,
            R.id.notif_item_4_title,
            R.id.notif_item_5_title,
        )
        val itemStatsIds = intArrayOf(
            R.id.notif_item_1_stats,
            R.id.notif_item_2_stats,
            R.id.notif_item_3_stats,
            R.id.notif_item_4_stats,
            R.id.notif_item_5_stats,
        )
        val itemProgressIds = intArrayOf(
            R.id.notif_item_1_progress,
            R.id.notif_item_2_progress,
            R.id.notif_item_3_progress,
            R.id.notif_item_4_progress,
            R.id.notif_item_5_progress,
        )

        for (i in 0 until 5) {
            if (i < items.size) {
                val item = items[i]
                val title = item["title"] as? String ?: ""
                val sec = (item["remainingSeconds"] as? Number)?.toInt() ?: 0
                val pct = (((item["progress"] as? Number)?.toDouble() ?: 0.0) * 100).toInt().coerceIn(0, 100)
                val h = sec / 3600
                val m = (sec % 3600) / 60
                val s = sec % 60
                val timeStr = String.format("%02d:%02d:%02d", h, m, s)

                val stats = when {
                    showPercent && showCountdown -> "$pct%  $timeStr"
                    showPercent -> "$pct%"
                    showCountdown -> timeStr
                    else -> ""
                }

                expandedView.setViewVisibility(itemContainerIds[i], View.VISIBLE)
                expandedView.setTextViewText(itemTitleIds[i], title)
                expandedView.setTextViewText(itemStatsIds[i], stats)

                if (showProgress) {
                    expandedView.setViewVisibility(itemProgressIds[i], View.VISIBLE)
                    expandedView.setProgressBar(itemProgressIds[i], 100, pct, false)
                } else {
                    expandedView.setViewVisibility(itemProgressIds[i], View.GONE)
                }
            } else {
                expandedView.setViewVisibility(itemContainerIds[i], View.GONE)
            }
        }

        return NotificationCompat.Builder(context, ONGOING_CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setStyle(NotificationCompat.DecoratedCustomViewStyle())
            .setCustomContentView(collapsedView)
            .setCustomBigContentView(expandedView)
            .setContentTitle(headerTitle)
            .setContentText(firstTitle)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setAutoCancel(false)
            .setOnlyAlertOnce(true)
            .setCategory(NotificationCompat.CATEGORY_PROGRESS)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .build()
    }

    fun updateOngoingProgress(
        context: Context,
        items: List<Map<String, Any>>,
        showProgress: Boolean,
        showPercent: Boolean,
        showCountdown: Boolean,
    ) {
        if (items.isEmpty()) {
            cancelOngoingProgress(context)
            return
        }

        // Delegate to Foreground Service for background persistence
        NotificationOngoingService.start(
            context,
            items,
            showProgress,
            showPercent,
            showCountdown,
        )
    }

    fun cancelOngoingProgress(context: Context) {
        NotificationOngoingService.stop(context)
    }
}
