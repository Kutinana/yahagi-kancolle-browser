package app.yahagi.kancollebrowser.notification

import org.json.JSONArray
import org.json.JSONObject

data class NotificationAlarm(
    val key: String,
    val taskId: String,
    val type: String,
    val stage: String,
    val removeTaskOnFire: Boolean,
    val triggerTimeEpochMs: Long,
    val title: String,
    val body: String,
)

data class OngoingNotificationItem(
    val id: String,
    val type: String,
    val title: String,
    val state: String = "running",
    val clockMode: String = "countdown",
    val anchorEpochMs: Long? = null,
    val progress: Double,
    val remainingSeconds: Int,
    val targetEpochMs: Long?,
    val totalDurationSec: Int?,
)

data class NotificationPresentation(
    val enabled: Boolean,
    val sound: Boolean,
    val vibration: Boolean,
    val showProgress: Boolean,
    val showPercent: Boolean,
    val showCountdown: Boolean,
    val ongoingLive: Boolean,
)

data class NativeNotificationSnapshot(
    val schemaVersion: Int,
    val updatedAtEpochMs: Long,
    val alarms: List<NotificationAlarm>,
    val ongoingItems: List<OngoingNotificationItem>,
    val presentation: NotificationPresentation,
) {
    companion object {
        val EMPTY = NativeNotificationSnapshot(
            schemaVersion = 1,
            updatedAtEpochMs = 0L,
            alarms = emptyList(),
            ongoingItems = emptyList(),
            presentation = NotificationPresentation(
                enabled = false,
                sound = true,
                vibration = true,
                showProgress = true,
                showPercent = true,
                showCountdown = true,
                ongoingLive = true,
            ),
        )
    }
}

data class NotificationAlarmDiff(
    val cancelKeys: Set<String>,
    val upsert: List<NotificationAlarm>,
)

object NotificationSnapshotDiff {
    fun between(
        previous: NativeNotificationSnapshot,
        next: NativeNotificationSnapshot,
    ): NotificationAlarmDiff {
        val alarmDiff = between(previous.alarms, next.alarms)
        val presentationChanged =
            previous.presentation.sound != next.presentation.sound ||
                previous.presentation.vibration != next.presentation.vibration
        return if (presentationChanged) {
            alarmDiff.copy(upsert = next.alarms)
        } else {
            alarmDiff
        }
    }

    fun between(
        previous: List<NotificationAlarm>,
        next: List<NotificationAlarm>,
    ): NotificationAlarmDiff {
        val previousByKey = previous.associateBy(NotificationAlarm::key)
        val nextByKey = next.associateBy(NotificationAlarm::key)
        return NotificationAlarmDiff(
            cancelKeys = previousByKey.keys - nextByKey.keys,
            upsert = next.filter { previousByKey[it.key] != it },
        )
    }
}

object NotificationSnapshotRecovery {
    fun afterScheduleFailures(
        desired: NativeNotificationSnapshot,
        failedKeys: Set<String>,
    ): NativeNotificationSnapshot = desired.copy(
        alarms = desired.alarms.filterNot { it.key in failedKeys },
    )
}

object NotificationSnapshotTransitions {
    fun onAlarmFired(
        previous: NativeNotificationSnapshot,
        key: String,
        taskId: String,
        stage: String,
    ): NativeNotificationSnapshot {
        return previous.copy(
            alarms = previous.alarms.filterNot { it.key == key },
            ongoingItems = previous.ongoingItems.map { item ->
                if (item.id != taskId) return@map item
                when {
                    stage == "complete" -> item.copy(
                        state = "completed",
                        progress = 1.0,
                        remainingSeconds = 0,
                    )
                    stage == "milestone" && item.type == "anchorage" -> item.copy(
                        state = "settlementReady",
                    )
                    else -> item
                }
            },
        )
    }
}

object NotificationSnapshotCodec {
    fun fromMap(raw: Map<*, *>): NativeNotificationSnapshot {
        val alarms = raw.list("alarms").map { alarmRaw ->
            val alarm = alarmRaw.asMap()
            NotificationAlarm(
                key = alarm.string("key"),
                taskId = alarm.string("taskId"),
                type = alarm.string("type"),
                stage = alarm.string("stage"),
                removeTaskOnFire = alarm.boolean("removeTaskOnFire"),
                triggerTimeEpochMs = alarm.long("triggerTimeEpochMs"),
                title = alarm.string("title"),
                body = alarm.string("body"),
            )
        }
        val ongoingItems = raw.list("ongoingItems").map { itemRaw ->
            val item = itemRaw.asMap()
            OngoingNotificationItem(
                id = item.string("id"),
                type = item.string("type"),
                title = item.string("title"),
                state = item.optionalString("state") ?: "running",
                clockMode = item.optionalString("clockMode") ?: "countdown",
                anchorEpochMs = item.optionalNumber("anchorEpochMs")?.toLong(),
                progress = item.number("progress").toDouble().coerceIn(0.0, 1.0),
                remainingSeconds = item.number("remainingSeconds").toInt().coerceAtLeast(0),
                targetEpochMs = item.optionalNumber("targetEpochMs")?.toLong(),
                totalDurationSec = item.optionalNumber("totalDurationSec")?.toInt(),
            )
        }
        val presentation = raw["presentation"].asMap()
        return NativeNotificationSnapshot(
            schemaVersion = raw.number("schemaVersion").toInt(),
            updatedAtEpochMs = raw.long("updatedAtEpochMs"),
            alarms = alarms,
            ongoingItems = ongoingItems,
            presentation = NotificationPresentation(
                enabled = presentation.boolean("enabled"),
                sound = presentation.boolean("sound"),
                vibration = presentation.boolean("vibration"),
                showProgress = presentation.boolean("showProgress"),
                showPercent = presentation.boolean("showPercent"),
                showCountdown = presentation.boolean("showCountdown"),
                ongoingLive = presentation.boolean("ongoingLive"),
            ),
        )
    }

    fun toJson(snapshot: NativeNotificationSnapshot): String = JSONObject().apply {
        put("schemaVersion", snapshot.schemaVersion)
        put("updatedAtEpochMs", snapshot.updatedAtEpochMs)
        put("alarms", JSONArray().apply {
            snapshot.alarms.forEach { alarm ->
                put(JSONObject().apply {
                    put("key", alarm.key)
                    put("taskId", alarm.taskId)
                    put("type", alarm.type)
                    put("stage", alarm.stage)
                    put("removeTaskOnFire", alarm.removeTaskOnFire)
                    put("triggerTimeEpochMs", alarm.triggerTimeEpochMs)
                    put("title", alarm.title)
                    put("body", alarm.body)
                })
            }
        })
        put("ongoingItems", JSONArray().apply {
            snapshot.ongoingItems.forEach { item ->
                put(JSONObject().apply {
                    put("id", item.id)
                    put("type", item.type)
                    put("title", item.title)
                    put("state", item.state)
                    put("clockMode", item.clockMode)
                    put("anchorEpochMs", item.anchorEpochMs ?: JSONObject.NULL)
                    put("progress", item.progress)
                    put("remainingSeconds", item.remainingSeconds)
                    put("targetEpochMs", item.targetEpochMs ?: JSONObject.NULL)
                    put("totalDurationSec", item.totalDurationSec ?: JSONObject.NULL)
                })
            }
        })
        put("presentation", JSONObject().apply {
            put("enabled", snapshot.presentation.enabled)
            put("sound", snapshot.presentation.sound)
            put("vibration", snapshot.presentation.vibration)
            put("showProgress", snapshot.presentation.showProgress)
            put("showPercent", snapshot.presentation.showPercent)
            put("showCountdown", snapshot.presentation.showCountdown)
            put("ongoingLive", snapshot.presentation.ongoingLive)
        })
    }.toString()

    fun fromJson(json: String): NativeNotificationSnapshot {
        val root = JSONObject(json)
        return fromMap(root.toMap())
    }
}

private fun Any?.asMap(): Map<*, *> = this as? Map<*, *>
    ?: throw IllegalArgumentException("Expected map")

private fun Map<*, *>.string(key: String): String = this[key] as? String
    ?: throw IllegalArgumentException("$key must be a string")

private fun Map<*, *>.optionalString(key: String): String? = this[key] as? String

private fun Map<*, *>.number(key: String): Number = this[key] as? Number
    ?: throw IllegalArgumentException("$key must be a number")

private fun Map<*, *>.optionalNumber(key: String): Number? = this[key] as? Number

private fun Map<*, *>.long(key: String): Long = number(key).toLong()

private fun Map<*, *>.boolean(key: String): Boolean = this[key] as? Boolean
    ?: throw IllegalArgumentException("$key must be a boolean")

private fun Map<*, *>.list(key: String): List<*> = this[key] as? List<*>
    ?: throw IllegalArgumentException("$key must be a list")

private fun JSONObject.toMap(): Map<String, Any?> = keys().asSequence().associateWith { key ->
    when (val value = get(key)) {
        JSONObject.NULL -> null
        is JSONObject -> value.toMap()
        is JSONArray -> value.toList()
        else -> value
    }
}

private fun JSONArray.toList(): List<Any?> = (0 until length()).map { index ->
    when (val value = get(index)) {
        JSONObject.NULL -> null
        is JSONObject -> value.toMap()
        is JSONArray -> value.toList()
        else -> value
    }
}
