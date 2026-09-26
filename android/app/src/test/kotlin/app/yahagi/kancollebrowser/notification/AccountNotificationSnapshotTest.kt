package app.yahagi.kancollebrowser.notification
import org.junit.Assert.*
import org.junit.Test
class AccountNotificationSnapshotTest {
    @Test
    fun `account transition must not revive due or failed notifications`() {
        val old = snapshot(alarm("old", 100L), sound = true, vibration = true).copy(
            immediateAlerts = listOf(immediate("old-ship", 100L).copy(deliveryAttempts = 1)),
        )
        val oldMap = org.json.JSONObject(NotificationSnapshotCodec.toJson(old)).apply {
            put("memberId", 1001L)
            put("sessionId", "login-a")
        }
        val nextMap = org.json.JSONObject(NotificationSnapshotCodec.toJson(old.copy(
            alarms = emptyList(), immediateAlerts = emptyList(),
        ))).apply {
            put("memberId", 2002L)
            put("sessionId", "login-b")
        }
        val result = NotificationSnapshotReconciliation.beforeApply(
            previous = NotificationSnapshotCodec.fromJson(oldMap.toString()),
            desired = NotificationSnapshotCodec.fromJson(nextMap.toString()),
            nowEpochMs = 200L,
        )
        assertTrue(result.alarms.isEmpty())
        assertTrue(result.immediateAlerts.isEmpty())
    }

    @Test
    fun `same account new session cancels and replaces even identical alarms`() {
        val old = scoped()
        val next = old.copy(sessionId = "new-login")
        val diff = NotificationSnapshotDiff.between(old, next)
        assertEquals(setOf("repair"), diff.cancelKeys)
        assertEquals(next.alarms, diff.upsert)
        assertTrue(NotificationSnapshotReconciliation.beforeApply(
            old, next.copy(alarms = emptyList()), 200L,
        ).alarms.isEmpty())
    }

    @Test
    fun `same account session retains retries and survives JSON persistence`() {
        val old = scoped().copy(immediateAlerts = listOf(
            immediate("ship", 100L).copy(deliveryAttempts = 1),
        ))
        val restored = NotificationSnapshotCodec.fromJson(NotificationSnapshotCodec.toJson(old))
        assertEquals(old, restored)
        val result = NotificationSnapshotReconciliation.beforeApply(
            restored, old.copy(alarms = emptyList(), immediateAlerts = emptyList()), 200L,
        )
        assertEquals(old.alarms, result.alarms)
        assertEquals(old.immediateAlerts, result.immediateAlerts)
    }

    @Test
    fun `receiver only delivers an existing alarm in the exact active account session`() {
        val current = scoped()
        fun eligible(snapshot: NativeNotificationSnapshot = current, memberId: Long = 1001L,
            sessionId: String? = "login-a", deadline: Long = 100L) = NotificationDelivery.currentAlarm(
            snapshot, memberId, sessionId, "repair", "task:repair", "complete", deadline,
        )
        assertEquals(current.alarms.single(), eligible())
        assertNull(eligible(memberId = 2002L))
        assertNull(eligible(sessionId = "previous-login"))
        assertNull(eligible(deadline = 99L))
        assertNull(eligible(snapshot = current.copy(alarms = emptyList())))
        assertNull(eligible(snapshot = current.copy(memberId = null, sessionId = null)))
        assertNull(eligible(snapshot = current.copy(presentation = current.presentation.copy(enabled = false))))
    }

    private fun scoped() = snapshot(alarm("repair", 100L), true, true).copy(
        memberId = 1001L, sessionId = "login-a",
    )

    private fun snapshot(alarm: NotificationAlarm, sound: Boolean, vibration: Boolean) = NativeNotificationSnapshot(
        schemaVersion = 1, updatedAtEpochMs = 1L, alarms = listOf(alarm), ongoingItems = emptyList(),
        presentation = NotificationPresentation(true, sound, vibration, true, true, true, true),
    )
    private fun alarm(key: String, at: Long) = NotificationAlarm(key, "task:$key", "repair", "complete", true, at, key, "body")
    private fun immediate(key: String, at: Long) = ImmediateNotificationAlert(key, "task:$key", "newShip", at, at, key, "body")
}
