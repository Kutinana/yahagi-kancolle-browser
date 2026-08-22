package app.yahagi.kancollebrowser.notification

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class NotificationProgressProjectionTest {
    @Test
    fun `progress advances from captured value over the remaining window`() {
        val projected = NotificationProgressProjection.project(
            item = ongoing(progress = 0.2, targetEpochMs = 200_000L),
            capturedAtEpochMs = 100_000L,
            nowEpochMs = 130_000L,
        )

        assertEquals(0.44, projected.progress, 0.000_001)
        assertEquals(70, projected.remainingSeconds)
        assertEquals("running", projected.state)
    }

    @Test
    fun `countdown is clamped to completed at its target`() {
        val projected = NotificationProgressProjection.project(
            item = ongoing(progress = 0.8, targetEpochMs = 120_000L),
            capturedAtEpochMs = 100_000L,
            nowEpochMs = 120_000L,
        )

        assertEquals(1.0, projected.progress, 0.0)
        assertEquals(0, projected.remainingSeconds)
        assertEquals("completed", projected.state)
    }

    @Test
    fun `elapsed anchorage reaches full progress without inventing completion state`() {
        val projected = NotificationProgressProjection.project(
            item = ongoing(
                progress = 0.5,
                targetEpochMs = 120_000L,
                clockMode = "elapsed",
            ),
            capturedAtEpochMs = 100_000L,
            nowEpochMs = 120_000L,
        )

        assertEquals(1.0, projected.progress, 0.0)
        assertEquals("running", projected.state)
    }

    @Test
    fun `refresh delay is capped at thirty seconds and shortened for deadline`() {
        assertEquals(
            30_000L,
            NotificationProgressProjection.nextRefreshDelayMs(
                snapshot(targetEpochMs = 200_000L),
                nowEpochMs = 100_000L,
            ),
        )
        assertEquals(
            20_000L,
            NotificationProgressProjection.nextRefreshDelayMs(
                snapshot(targetEpochMs = 120_000L),
                nowEpochMs = 100_000L,
            ),
        )
    }

    @Test
    fun `disabled empty and completed snapshots do not require refresh`() {
        assertFalse(
            NotificationProgressProjection.requiresRefresh(
                snapshot(targetEpochMs = 200_000L).copy(
                    presentation = presentation(enabled = false),
                ),
                nowEpochMs = 100_000L,
            ),
        )
        assertFalse(
            NotificationProgressProjection.requiresRefresh(
                snapshot(targetEpochMs = 200_000L).copy(ongoingItems = emptyList()),
                nowEpochMs = 100_000L,
            ),
        )
        val completed = snapshot(targetEpochMs = 90_000L).copy(
            ongoingItems = listOf(
                ongoing(progress = 1.0, targetEpochMs = 90_000L).copy(state = "completed"),
            ),
        )
        assertFalse(NotificationProgressProjection.requiresRefresh(completed, 100_000L))
        assertNull(NotificationProgressProjection.nextRefreshDelayMs(completed, 100_000L))
        assertTrue(
            NotificationProgressProjection.requiresRefresh(
                snapshot(targetEpochMs = 200_000L),
                nowEpochMs = 100_000L,
            ),
        )
    }

    @Test
    fun `display projection prioritizes completed and nearest tasks`() {
        val items = listOf(
            ongoing("late", progress = 0.2, targetEpochMs = 900_000L),
            ongoing("completed-b", progress = 1.0, targetEpochMs = 300_000L).copy(state = "completed"),
            ongoing("near", progress = 0.3, targetEpochMs = 200_000L),
            ongoing("completed-a", progress = 1.0, targetEpochMs = 250_000L).copy(state = "completed"),
        )

        val displayed = NotificationProgressProjection.displayItems(items)

        assertEquals(
            listOf("completed-a", "completed-b", "near", "late"),
            displayed.map { it.id },
        )
    }

    @Test
    fun `more than five tasks use four rows plus an overflow summary`() {
        val items = (1..7).map { index ->
            ongoing(
                id = "task:$index",
                progress = index / 10.0,
                targetEpochMs = 100_000L + index * 10_000L,
            )
        }

        val displayed = NotificationProgressProjection.displayItems(items)

        assertEquals(5, displayed.size)
        assertEquals(listOf("task:1", "task:2", "task:3", "task:4"), displayed.take(4).map { it.id })
        assertEquals("overflow", displayed.last().type)
        assertEquals("另有 3 项进行中或已完成任务", displayed.last().title)
        assertEquals(150_000L, displayed.last().targetEpochMs)
        assertTrue(displayed.last().remainingSeconds >= 0)
    }

    @Test
    fun `exactly five tasks remain five concrete rows`() {
        val items = (1..5).map { index ->
            ongoing("task:$index", progress = 0.2, targetEpochMs = 200_000L + index)
        }

        val displayed = NotificationProgressProjection.displayItems(items)

        assertEquals(5, displayed.size)
        assertFalse(displayed.any { it.type == "overflow" })
    }

    private fun snapshot(targetEpochMs: Long) = NativeNotificationSnapshot(
        schemaVersion = 1,
        updatedAtEpochMs = 100_000L,
        alarms = emptyList(),
        ongoingItems = listOf(ongoing(progress = 0.2, targetEpochMs = targetEpochMs)),
        presentation = presentation(enabled = true),
    )

    private fun presentation(enabled: Boolean) = NotificationPresentation(
        enabled = enabled,
        sound = true,
        vibration = true,
        showProgress = true,
        showPercent = true,
        showCountdown = true,
        ongoingLive = true,
    )

    private fun ongoing(
        id: String = "expedition:2",
        progress: Double,
        targetEpochMs: Long,
        clockMode: String = "countdown",
    ) = OngoingNotificationItem(
        id = id,
        type = if (clockMode == "elapsed") "anchorage" else "expedition",
        title = "task",
        state = "running",
        clockMode = clockMode,
        anchorEpochMs = if (clockMode == "elapsed") 80_000L else null,
        progress = progress,
        remainingSeconds = ((targetEpochMs - 100_000L) / 1_000L).toInt().coerceAtLeast(0),
        targetEpochMs = targetEpochMs,
        totalDurationSec = 100,
    )
}
