package app.yahagi.kancollebrowser

import org.junit.Assert.assertEquals
import org.junit.Test

class GameSurfaceRecoveryTriggerTest {
    @Test
    fun windowModeTransitionsRequestSurfaceRecovery() {
        val reasons = mutableListOf<GameSurfaceRecoveryReason>()
        val trigger = GameSurfaceRecoveryTrigger(reasons::add)

        trigger.onMultiWindowModeChanged(true)
        trigger.onMultiWindowModeChanged(false)
        trigger.onPictureInPictureModeChanged(true)
        trigger.onPictureInPictureModeChanged(false)

        assertEquals(
            listOf(
                GameSurfaceRecoveryReason.MULTI_WINDOW_ENTER,
                GameSurfaceRecoveryReason.MULTI_WINDOW_EXIT,
                GameSurfaceRecoveryReason.PICTURE_IN_PICTURE_ENTER,
                GameSurfaceRecoveryReason.PICTURE_IN_PICTURE_EXIT,
            ),
            reasons,
        )
    }

    @Test
    fun configurationChangesRequestSurfaceRecovery() {
        val reasons = mutableListOf<GameSurfaceRecoveryReason>()
        val trigger = GameSurfaceRecoveryTrigger(reasons::add)

        trigger.onConfigurationChanged()

        assertEquals(
            listOf(GameSurfaceRecoveryReason.CONFIGURATION_CHANGED),
            reasons,
        )
    }
}
