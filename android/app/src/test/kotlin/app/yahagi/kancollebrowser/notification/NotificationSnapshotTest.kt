package app.yahagi.kancollebrowser.notification

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class NotificationSnapshotTest {
    @Test
    fun `codec parses the complete Flutter snapshot`() {
        val snapshot = NotificationSnapshotCodec.fromMap(
            mapOf(
                "schemaVersion" to 1,
                "updatedAtEpochMs" to 1_700_000_000_000L,
                "alarms" to listOf(
                    mapOf(
                        "key" to "expedition_2_complete",
                        "taskId" to "expedition:2",
                        "type" to "expedition",
                        "stage" to "complete",
                        "removeTaskOnFire" to true,
                        "triggerTimeEpochMs" to 1_700_000_600_000L,
                        "title" to "done",
                        "body" to "returned",
                    ),
                ),
                "ongoingItems" to listOf(
                    mapOf(
                        "id" to "expedition:2",
                        "type" to "expedition",
                        "title" to "fleet 2",
                        "progress" to 0.5,
                        "remainingSeconds" to 600,
                        "targetEpochMs" to 1_700_000_600_000L,
                        "totalDurationSec" to 1200,
                    ),
                ),
                "presentation" to mapOf(
                    "enabled" to true,
                    "sound" to false,
                    "vibration" to true,
                    "showProgress" to true,
                    "showPercent" to false,
                    "showCountdown" to true,
                    "ongoingLive" to true,
                ),
            ),
        )

        assertEquals("expedition:2", snapshot.alarms.single().taskId)
        assertTrue(snapshot.alarms.single().removeTaskOnFire)
        assertEquals(1_700_000_600_000L, snapshot.ongoingItems.single().targetEpochMs)
        assertEquals(false, snapshot.presentation.sound)
    }

    @Test
    fun `diff cancels removed alarms and only upserts changed alarms`() {
        val oldAlarm = alarm("old", 100L)
        val unchanged = alarm("same", 200L)
        val changedBefore = alarm("changed", 300L)
        val changedAfter = alarm("changed", 400L)
        val added = alarm("new", 500L)

        val diff = NotificationSnapshotDiff.between(
            previous = listOf(oldAlarm, unchanged, changedBefore),
            next = listOf(unchanged, changedAfter, added),
        )

        assertEquals(setOf("old"), diff.cancelKeys)
        assertEquals(setOf("changed", "new"), diff.upsert.map { it.key }.toSet())
    }

    @Test
    fun `presentation sound or vibration change rebinds existing alarms`() {
        val sharedAlarm = alarm("same", 200L)
        val previous = snapshot(sharedAlarm, sound = true, vibration = true)
        val next = snapshot(sharedAlarm, sound = false, vibration = true)

        val diff = NotificationSnapshotDiff.between(previous, next)

        assertEquals(listOf(sharedAlarm), diff.upsert)
    }

    private fun snapshot(
        alarm: NotificationAlarm,
        sound: Boolean,
        vibration: Boolean,
    ) = NativeNotificationSnapshot(
        schemaVersion = 1,
        updatedAtEpochMs = 1L,
        alarms = listOf(alarm),
        ongoingItems = emptyList(),
        presentation = NotificationPresentation(
            enabled = true,
            sound = sound,
            vibration = vibration,
            showProgress = true,
            showPercent = true,
            showCountdown = true,
            ongoingLive = true,
        ),
    )

    private fun alarm(key: String, triggerAt: Long) = NotificationAlarm(
        key = key,
        taskId = "task:$key",
        type = "expedition",
        stage = "complete",
        removeTaskOnFire = true,
        triggerTimeEpochMs = triggerAt,
        title = key,
        body = "body",
    )
}
