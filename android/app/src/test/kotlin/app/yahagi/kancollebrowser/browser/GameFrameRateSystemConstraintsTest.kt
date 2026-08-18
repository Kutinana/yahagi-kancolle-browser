package app.yahagi.kancollebrowser.browser

import android.os.PowerManager
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class GameFrameRateSystemConstraintsTest {
    @Test
    fun powerSaveConstrainsAutomaticModeTo30() {
        assertEquals(
            GameFrameRateTarget.FPS_30,
            GameFrameRateSystemPolicy.effectiveTarget(
                mode = GameFrameRateMode.AUTO,
                requestedTarget = GameFrameRateTarget.FPS_60,
                state = GameFrameRateSystemState(
                    powerSaveEnabled = true,
                    thermalStatus = PowerManager.THERMAL_STATUS_NONE,
                ),
            ),
        )
    }

    @Test
    fun moderateThermalStatusConstrainsAutomaticModeTo30() {
        assertEquals(
            GameFrameRateTarget.FPS_30,
            GameFrameRateSystemPolicy.effectiveTarget(
                mode = GameFrameRateMode.AUTO,
                requestedTarget = GameFrameRateTarget.FPS_60,
                state = GameFrameRateSystemState(
                    powerSaveEnabled = false,
                    thermalStatus = PowerManager.THERMAL_STATUS_MODERATE,
                ),
            ),
        )
    }

    @Test
    fun highRefreshRemainsUserControlledUnderSystemConstraints() {
        assertEquals(
            GameFrameRateTarget.HIGH_REFRESH,
            GameFrameRateSystemPolicy.effectiveTarget(
                mode = GameFrameRateMode.HIGH_REFRESH,
                requestedTarget = GameFrameRateTarget.HIGH_REFRESH,
                state = GameFrameRateSystemState(
                    powerSaveEnabled = true,
                    thermalStatus = PowerManager.THERMAL_STATUS_SEVERE,
                ),
            ),
        )
    }

    @Test
    fun automaticModeNeverAcceptsAnUnthrottledRuntimeTarget() {
        assertEquals(
            GameFrameRateTarget.FPS_60,
            GameFrameRateSystemPolicy.effectiveTarget(
                mode = GameFrameRateMode.AUTO,
                requestedTarget = GameFrameRateTarget.HIGH_REFRESH,
                state = GameFrameRateSystemState(),
            ),
        )
    }

    @Test
    fun automaticModeSuppressesRuntimeSamplesWhileConservingPower() {
        assertNull(
            GameFrameRateSystemPolicy.runtimeSample(
                mode = GameFrameRateMode.AUTO,
                state = GameFrameRateSystemState(powerSaveEnabled = true),
                measuredFps = 29.0,
            ),
        )
    }

    @Test
    fun automaticModeRestoresRuntimeSamplesAfterConservationEnds() {
        assertEquals(
            60.0,
            GameFrameRateSystemPolicy.runtimeSample(
                mode = GameFrameRateMode.AUTO,
                state = GameFrameRateSystemState(),
                measuredFps = 60.0,
            ),
        )
    }

    @Test
    fun manualModesKeepRuntimeSamplesUnderSystemConstraints() {
        assertEquals(
            120.0,
            GameFrameRateSystemPolicy.runtimeSample(
                mode = GameFrameRateMode.HIGH_REFRESH,
                state = GameFrameRateSystemState(powerSaveEnabled = true),
                measuredFps = 120.0,
            ),
        )
    }
}
