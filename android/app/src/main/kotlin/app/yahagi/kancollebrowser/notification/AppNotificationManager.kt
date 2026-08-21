package app.yahagi.kancollebrowser.notification

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Build
import android.os.SystemClock
import android.view.View
import android.widget.RemoteViews
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import app.yahagi.kancollebrowser.MainActivity
import app.yahagi.kancollebrowser.R

object AppNotificationManager {
    const val ONGOING_NOTIFICATION_ID = 999
    val VIBRATION_PATTERN = longArrayOf(0, 255, 90, 255)

    private const val PREFERENCES_NAME = "yahagi_native_notification_snapshot"
    private const val SNAPSHOT_KEY = "snapshot_json"
    private const val ONGOING_CHANNEL_ID = "channel_ongoing"
    private const val ONGOING_CHANNEL_NAME = "母港实时进行中概览"
    private val channelNames = mapOf(
        "expedition" to "远征通知",
        "repair" to "入渠修复",
        "anchorage" to "泊地修理",
        "construction" to "工厂建造",
        "morale" to "士气与刷闪",
    )

    fun initChannels(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager ?: return
        val soundUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
        val audioAttributes = AudioAttributes.Builder()
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .setUsage(AudioAttributes.USAGE_NOTIFICATION)
            .build()

        channelNames.forEach { (type, name) ->
            listOf(false, true).forEach { sound ->
                listOf(false, true).forEach { vibration ->
                    manager.createNotificationChannel(
                        NotificationChannel(
                            channelId(type, sound, vibration),
                            "$name · ${if (sound) "有声" else "静音"} · ${if (vibration) "振动" else "无振动"}",
                            NotificationManager.IMPORTANCE_HIGH,
                        ).apply {
                            enableVibration(vibration)
                            vibrationPattern = if (vibration) VIBRATION_PATTERN else null
                            setSound(if (sound) soundUri else null, if (sound) audioAttributes else null)
                            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                            setShowBadge(true)
                        },
                    )
                }
            }
        }
        manager.createNotificationChannel(
            NotificationChannel(
                ONGOING_CHANNEL_ID,
                ONGOING_CHANNEL_NAME,
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                enableVibration(false)
                setSound(null, null)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                setShowBadge(false)
            },
        )
    }

    @Synchronized
    fun applySnapshot(context: Context, raw: Map<*, *>): Map<String, Any> {
        initChannels(context)
        val next = NotificationSnapshotCodec.fromMap(raw)
        require(next.schemaVersion == 1) { "Unsupported notification snapshot schema" }
        val previous = loadSnapshot(context)
        val diff = NotificationSnapshotDiff.between(previous, next)
        val failures = mutableListOf<String>()
        val failedScheduleKeys = mutableSetOf<String>()
        diff.cancelKeys.forEach { key ->
            runCatching { cancelAlarm(context, key) }
                .onFailure { failures += "$key:cancel" }
        }

        var exact = 0
        var inexact = 0
        diff.upsert.forEach { alarm ->
            runCatching {
                if (scheduleAlarm(context, alarm, next.presentation)) exact++ else inexact++
            }.onFailure {
                failures += "${alarm.key}:schedule"
                failedScheduleKeys += alarm.key
            }
        }
        val persisted = NotificationSnapshotRecovery.afterScheduleFailures(
            next,
            failedScheduleKeys,
        )
        saveSnapshot(context, persisted)
        runCatching { updateOngoingProgress(context, persisted) }
            .onFailure { failures += "ongoing" }
        return mapOf(
            "scheduledExact" to exact,
            "scheduledInexact" to inexact,
            "canceled" to diff.cancelKeys.size,
            "failures" to failures,
        )
    }

    fun loadSnapshot(context: Context): NativeNotificationSnapshot {
        val json = context.getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)
            .getString(SNAPSHOT_KEY, null) ?: return NativeNotificationSnapshot.EMPTY
        return runCatching { NotificationSnapshotCodec.fromJson(json) }
            .getOrDefault(NativeNotificationSnapshot.EMPTY)
    }

    private fun saveSnapshot(context: Context, snapshot: NativeNotificationSnapshot) {
        context.getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)
            .edit()
            .putString(SNAPSHOT_KEY, NotificationSnapshotCodec.toJson(snapshot))
            .commit()
    }

    fun onAlarmFired(
        context: Context,
        key: String,
        taskId: String,
        stage: String,
    ) {
        val previous = loadSnapshot(context)
        val next = NotificationSnapshotTransitions.onAlarmFired(
            previous = previous,
            key = key,
            taskId = taskId,
            stage = stage,
        )
        saveSnapshot(context, next)
        updateOngoingProgress(context, next)
    }

    fun canScheduleExactAlarms(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return true
        val manager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return false
        return manager.canScheduleExactAlarms()
    }

    fun channelsEnabled(context: Context): Boolean {
        if (!NotificationManagerCompat.from(context).areNotificationsEnabled()) return false
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return true
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager ?: return false
        val snapshot = loadSnapshot(context)
        val activeTypes = (snapshot.alarms.map { it.type } + snapshot.ongoingItems.map { it.type })
            .filter { it in channelNames }
            .toSet()
            .ifEmpty { channelNames.keys }
        val alertChannelsEnabled = activeTypes.all { type ->
            manager.getNotificationChannel(
                channelId(type, snapshot.presentation.sound, snapshot.presentation.vibration),
            )?.importance?.let { it != NotificationManager.IMPORTANCE_NONE } == true
        }
        val ongoingEnabled = snapshot.ongoingItems.isEmpty() ||
            manager.getNotificationChannel(ONGOING_CHANNEL_ID)
                ?.importance
                ?.let { it != NotificationManager.IMPORTANCE_NONE } == true
        return alertChannelsEnabled && ongoingEnabled
    }

    private fun scheduleAlarm(
        context: Context,
        alarm: NotificationAlarm,
        presentation: NotificationPresentation,
    ): Boolean {
        val manager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager
            ?: error("AlarmManager unavailable")
        val intent = Intent(context, NotificationAlarmReceiver::class.java).apply {
            putExtra("key", alarm.key)
            putExtra("taskId", alarm.taskId)
            putExtra("stage", alarm.stage)
            putExtra("removeTaskOnFire", alarm.removeTaskOnFire)
            putExtra("channelId", channelId(alarm.type, presentation.sound, presentation.vibration))
            putExtra("sound", presentation.sound)
            putExtra("vibration", presentation.vibration)
            putExtra("title", alarm.title)
            putExtra("body", alarm.body)
        }
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            alarm.key.hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val exactAllowed = canScheduleExactAlarms(context)
        when {
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && exactAllowed ->
                manager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, alarm.triggerTimeEpochMs, pendingIntent)
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.M ->
                manager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, alarm.triggerTimeEpochMs, pendingIntent)
            else -> manager.setExact(AlarmManager.RTC_WAKEUP, alarm.triggerTimeEpochMs, pendingIntent)
        }
        return exactAllowed
    }

    fun cancelAlarm(context: Context, key: String) {
        val manager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            key.hashCode(),
            Intent(context, NotificationAlarmReceiver::class.java),
            PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE,
        ) ?: return
        manager.cancel(pendingIntent)
        pendingIntent.cancel()
    }

    private fun updateOngoingProgress(context: Context, snapshot: NativeNotificationSnapshot) {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager ?: return
        if (!snapshot.presentation.enabled ||
            !snapshot.presentation.ongoingLive ||
            snapshot.ongoingItems.isEmpty()
        ) {
            manager.cancel(ONGOING_NOTIFICATION_ID)
            return
        }
        manager.notify(ONGOING_NOTIFICATION_ID, buildOngoingNotification(context, snapshot))
    }

    private fun buildOngoingNotification(
        context: Context,
        snapshot: NativeNotificationSnapshot,
    ): Notification {
        val items = snapshot.ongoingItems
        val presentation = snapshot.presentation
        val launchIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            context,
            0,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val collapsed = RemoteViews(context.packageName, R.layout.notification_ongoing_collapsed)
        bindItem(
            collapsed,
            items.first(),
            R.id.notif_collapsed_title,
            R.id.notif_collapsed_stats,
            R.id.notif_collapsed_progress,
            presentation,
        )
        val expanded = RemoteViews(context.packageName, R.layout.notification_ongoing_expanded)
        val containers = intArrayOf(R.id.notif_item_1, R.id.notif_item_2, R.id.notif_item_3, R.id.notif_item_4, R.id.notif_item_5)
        val titles = intArrayOf(R.id.notif_item_1_title, R.id.notif_item_2_title, R.id.notif_item_3_title, R.id.notif_item_4_title, R.id.notif_item_5_title)
        val stats = intArrayOf(R.id.notif_item_1_stats, R.id.notif_item_2_stats, R.id.notif_item_3_stats, R.id.notif_item_4_stats, R.id.notif_item_5_stats)
        val progress = intArrayOf(R.id.notif_item_1_progress, R.id.notif_item_2_progress, R.id.notif_item_3_progress, R.id.notif_item_4_progress, R.id.notif_item_5_progress)
        containers.indices.forEach { index ->
            if (index < items.size) {
                expanded.setViewVisibility(containers[index], View.VISIBLE)
                bindItem(expanded, items[index], titles[index], stats[index], progress[index], presentation)
            } else {
                expanded.setViewVisibility(containers[index], View.GONE)
            }
        }
        return NotificationCompat.Builder(context, ONGOING_CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setStyle(NotificationCompat.DecoratedCustomViewStyle())
            .setCustomContentView(collapsed)
            .setCustomBigContentView(expanded)
            .setContentTitle("矢矧 · 母港实时进行中 (${items.size} 项)")
            .setContentText(items.first().title)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setAutoCancel(false)
            .setOnlyAlertOnce(true)
            .setCategory(NotificationCompat.CATEGORY_PROGRESS)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .build()
    }

    private fun bindItem(
        views: RemoteViews,
        item: OngoingNotificationItem,
        titleId: Int,
        statsId: Int,
        progressId: Int,
        presentation: NotificationPresentation,
    ) {
        val percent = (item.progress * 100).toInt().coerceIn(0, 100)
        views.setTextViewText(titleId, item.title)
        if (item.clockMode == "elapsed" && item.anchorEpochMs != null) {
            val base = NotificationChronometer.elapsedRealtimeBase(
                nowEpochMs = System.currentTimeMillis(),
                elapsedRealtimeMs = SystemClock.elapsedRealtime(),
                anchorEpochMs = item.anchorEpochMs,
            )
            val format = when (item.state) {
                "completed" -> "预计修理完成 · 已修理 %s"
                "settlementReady" -> "首轮结算就绪 · 已修理 %s"
                else -> "已修理 %s"
            }
            views.setViewVisibility(statsId, View.VISIBLE)
            views.setChronometer(statsId, base, format, true)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                views.setChronometerCountDown(statsId, false)
            }
        } else if (item.state == "completed") {
            views.setViewVisibility(statsId, View.VISIBLE)
            views.setChronometer(statsId, SystemClock.elapsedRealtime(), "已完成", false)
        } else if (presentation.showCountdown && item.targetEpochMs != null) {
            val base = SystemClock.elapsedRealtime() + (item.targetEpochMs - System.currentTimeMillis())
            views.setViewVisibility(statsId, View.VISIBLE)
            views.setChronometer(statsId, base, if (presentation.showPercent) "$percent%  %s" else "%s", true)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                views.setChronometerCountDown(statsId, true)
            }
        } else if (presentation.showPercent) {
            views.setViewVisibility(statsId, View.VISIBLE)
            views.setChronometer(statsId, SystemClock.elapsedRealtime(), "$percent%", false)
        } else {
            views.setViewVisibility(statsId, View.GONE)
        }
        views.setViewVisibility(progressId, if (presentation.showProgress) View.VISIBLE else View.GONE)
        if (presentation.showProgress) views.setProgressBar(progressId, 100, percent, false)
    }

    private fun channelId(type: String, sound: Boolean, vibration: Boolean): String =
        "channel_${type}_${if (sound) "sound" else "silent"}_${if (vibration) "vibrate" else "quiet"}"
}
