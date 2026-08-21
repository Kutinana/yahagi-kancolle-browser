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
                "immediateAlerts" to listOf(
                    mapOf(
                        "key" to "construction:1:manual:1700000000000",
                        "type" to "construction",
                        "occurredAtEpochMs" to 1_700_000_000_000L,
                        "title" to "done now",
                        "body" to "dock ready",
                    ),
                ),
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
                        "state" to "completed",
                        "clockMode" to "elapsed",
                        "anchorEpochMs" to 1_700_000_000_000L,
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
        assertEquals("construction", snapshot.immediateAlerts.single().type)
        assertTrue(snapshot.alarms.single().removeTaskOnFire)
        assertEquals(1_700_000_600_000L, snapshot.ongoingItems.single().targetEpochMs)
        assertEquals("completed", snapshot.ongoingItems.single().state)
        assertEquals("elapsed", snapshot.ongoingItems.single().clockMode)
        assertEquals(1_700_000_000_000L, snapshot.ongoingItems.single().anchorEpochMs)
        assertEquals(false, snapshot.presentation.sound)
    }

    @Test
    fun `codec round trip preserves ongoing task lifecycle fields`() {
        val alarm = alarm("same", 200L)
        val original = snapshot(
            alarm,
            sound = true,
            vibration = false,
            ongoingItems = listOf(
                ongoing("anchorage:1").copy(
                    state = "settlementReady",
                    clockMode = "elapsed",
                    anchorEpochMs = 100L,
                ),
            ),
        )

        assertEquals(
            original,
            NotificationSnapshotCodec.fromJson(NotificationSnapshotCodec.toJson(original)),
        )
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

    @Test
    fun `failed alarm schedules are omitted from the persisted snapshot so they retry`() {
        val successful = alarm("successful", 200L)
        val failed = alarm("failed", 300L)
        val desired = snapshot(successful, sound = true, vibration = true).copy(
            alarms = listOf(successful, failed),
        )

        val persisted = NotificationSnapshotRecovery.afterScheduleFailures(
            desired,
            setOf("failed"),
        )
        val retry = NotificationSnapshotDiff.between(persisted, desired)

        assertEquals(listOf(successful), persisted.alarms)
        assertEquals(listOf(failed), retry.upsert)
    }

    @Test
    fun `complete alarm marks matching ongoing item completed and is idempotent`() {
        val original = snapshot(
            alarm("expedition_2_complete", 200L),
            sound = true,
            vibration = true,
            ongoingItems = listOf(ongoing("expedition:2")),
        )

        val first = NotificationSnapshotTransitions.onAlarmFired(
            original,
            key = "expedition_2_complete",
            taskId = "expedition:2",
            stage = "complete",
        )
        val second = NotificationSnapshotTransitions.onAlarmFired(
            first,
            key = "expedition_2_complete",
            taskId = "expedition:2",
            stage = "complete",
        )

        assertEquals(emptyList<NotificationAlarm>(), first.alarms)
        assertEquals("completed", first.ongoingItems.single().state)
        assertEquals(1.0, first.ongoingItems.single().progress, 0.0)
        assertEquals(0, first.ongoingItems.single().remainingSeconds)
        assertEquals(first, second)
    }

    @Test
    fun `milestone marks anchorage settlement ready while preempt keeps running`() {
        val original = snapshot(
            alarm("anchorage_1_20m", 200L),
            sound = true,
            vibration = true,
            ongoingItems = listOf(ongoing("anchorage:1")),
        )

        val milestone = NotificationSnapshotTransitions.onAlarmFired(
            original,
            key = "anchorage_1_20m",
            taskId = "anchorage:1",
            stage = "milestone",
        )
        val preempt = NotificationSnapshotTransitions.onAlarmFired(
            original,
            key = "anchorage_1_20m",
            taskId = "anchorage:1",
            stage = "preempt",
        )

        assertEquals("settlementReady", milestone.ongoingItems.single().state)
        assertEquals("running", preempt.ongoingItems.single().state)
    }

    @Test
    fun `elapsed chronometer base uses the shared game timer anchor`() {
        assertEquals(
            47_000L,
            NotificationChronometer.elapsedRealtimeBase(
                nowEpochMs = 100_000L,
                elapsedRealtimeMs = 50_000L,
                anchorEpochMs = 97_000L,
            ),
        )
    }

    @Test
    fun `countdown format escapes the visible percent sign`() {
        assertEquals("53%%  %s", NotificationChronometer.countdownFormat(53, true))
        assertEquals("%s", NotificationChronometer.countdownFormat(53, false))
        assertEquals("53%%", NotificationChronometer.percentOnlyFormat(53))
    }

    @Test
    fun `completion notification id is stable and separate from ongoing summary`() {
        val first = NotificationDelivery.notificationId("expedition_2_complete", 100L)
        val second = NotificationDelivery.notificationId("expedition_2_complete", 100L)
        val nextMission = NotificationDelivery.notificationId("expedition_2_complete", 200L)

        assertEquals(first, second)
        assertTrue(first != nextMission)
        assertTrue(first != AppNotificationManager.ONGOING_NOTIFICATION_ID)
        assertTrue(first >= 1_000)
    }

    @Test
    fun `legacy alarm keys recover their stage when intent extra is missing`() {
        assertEquals("preempt", NotificationDelivery.stageFor("repair_1_preempt", null))
        assertEquals("milestone", NotificationDelivery.stageFor("anchorage_1_20m", null))
        assertEquals("complete", NotificationDelivery.stageFor("construction_1_complete", null))
        assertEquals("milestone", NotificationDelivery.stageFor("anything", "milestone"))
    }

    private fun snapshot(
        alarm: NotificationAlarm,
        sound: Boolean,
        vibration: Boolean,
        ongoingItems: List<OngoingNotificationItem> = emptyList(),
    ) = NativeNotificationSnapshot(
        schemaVersion = 1,
        updatedAtEpochMs = 1L,
        alarms = listOf(alarm),
        ongoingItems = ongoingItems,
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

    private fun ongoing(id: String) = OngoingNotificationItem(
        id = id,
        type = if (id.startsWith("anchorage:")) "anchorage" else "expedition",
        title = "task",
        state = "running",
        clockMode = "countdown",
        anchorEpochMs = null,
        progress = 0.5,
        remainingSeconds = 60,
        targetEpochMs = 200L,
        totalDurationSec = 120,
    )
}
