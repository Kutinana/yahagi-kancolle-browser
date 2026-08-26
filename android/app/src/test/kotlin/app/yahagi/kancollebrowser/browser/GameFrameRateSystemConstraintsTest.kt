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
    fun stable30RemainsSelectedUnderSystemConstraints() {
        assertEquals(
            GameFrameRateTarget.FPS_30,
            GameFrameRateSystemPolicy.effectiveTarget(
                mode = GameFrameRateMode.STABLE_30,
                requestedTarget = GameFrameRateTarget.FPS_30,
                state = GameFrameRateSystemState(
                    powerSaveEnabled = true,
                    thermalStatus = PowerManager.THERMAL_STATUS_SEVERE,
                ),
            ),
        )
    }

    @Test
    fun automaticModeKeepsTheRequested60TargetWithoutConstraints() {
        assertEquals(
            GameFrameRateTarget.FPS_60,
            GameFrameRateSystemPolicy.effectiveTarget(
                mode = GameFrameRateMode.AUTO,
                requestedTarget = GameFrameRateTarget.FPS_60,
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
    fun stable30KeepsRuntimeSamplesUnderSystemConstraints() {
        assertEquals(
            30.0,
            GameFrameRateSystemPolicy.runtimeSample(
                mode = GameFrameRateMode.STABLE_30,
                state = GameFrameRateSystemState(powerSaveEnabled = true),
                measuredFps = 30.0,
            ),
        )
    }
}
