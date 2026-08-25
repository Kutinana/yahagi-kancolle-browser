package app.yahagi.kancollebrowser.notification

import org.junit.Assert.assertEquals
import org.junit.Test

class NotificationForegroundModeTest {
    @Test
    fun `session without tasks shows session notification`() {
        assertEquals(
            NotificationForegroundMode.SESSION,
            NotificationForegroundMode.resolve(
                sessionRetentionRequested = true,
                hasOngoingItems = false,
            ),
        )
    }

    @Test
    fun `tasks take priority over session`() {
        assertEquals(
            NotificationForegroundMode.PROGRESS,
            NotificationForegroundMode.resolve(
                sessionRetentionRequested = true,
                hasOngoingItems = true,
            ),
        )
    }

    @Test
    fun `tasks remain visible without session retention`() {
        assertEquals(
            NotificationForegroundMode.PROGRESS,
            NotificationForegroundMode.resolve(
                sessionRetentionRequested = false,
                hasOngoingItems = true,
            ),
        )
    }

    @Test
    fun `no requirements stops service`() {
        assertEquals(
            NotificationForegroundMode.STOP,
            NotificationForegroundMode.resolve(
                sessionRetentionRequested = false,
                hasOngoingItems = false,
            ),
        )
    }
}
