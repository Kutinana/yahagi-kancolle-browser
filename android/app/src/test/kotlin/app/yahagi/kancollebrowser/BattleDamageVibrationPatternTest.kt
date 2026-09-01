package app.yahagi.kancollebrowser

import org.junit.Assert.assertArrayEquals
import org.junit.Test

class BattleDamageVibrationPatternTest {
    @Test
    fun moderateUsesOneClearShortPulse() {
        val pattern = BattleDamageVibrationPattern.forSeverity("moderate")

        assertArrayEquals(longArrayOf(0, 300), pattern.timings)
        assertArrayEquals(intArrayOf(0, 255), pattern.amplitudes)
    }

    @Test
    fun heavyUsesTwoStrongerPulses() {
        val pattern = BattleDamageVibrationPattern.forSeverity("heavy")

        assertArrayEquals(longArrayOf(0, 255, 90, 255), pattern.timings)
        assertArrayEquals(intArrayOf(0, 255, 0, 255), pattern.amplitudes)
    }
}
