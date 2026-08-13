package app.yahagi.kancollebrowser

import org.junit.Assert.assertFalse
import org.junit.Test

class GameRenderingModeHcppPolicyTest {
    @Test
    fun onlyExplicitHighPerformanceModeKeepsHcppDisabled() {
        assertFalse(GameRenderingModeHcppPolicy.shouldEnable("standard"))
    }

    @Test
    fun foldableSafeModesKeepHcppDisabledBeforeEngineStartup() {
        assertFalse(GameRenderingModeHcppPolicy.shouldEnable("compatibility"))
        assertFalse(GameRenderingModeHcppPolicy.shouldEnable("canvasCompatibility"))
        assertFalse(GameRenderingModeHcppPolicy.shouldEnable(null))
        assertFalse(GameRenderingModeHcppPolicy.shouldEnable("future-mode"))
    }
}
