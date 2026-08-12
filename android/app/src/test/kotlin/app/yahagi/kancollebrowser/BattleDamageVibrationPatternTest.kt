package app.yahagi.kancollebrowser

import org.junit.Assert.assertArrayEquals
import org.junit.Test

class BattleDamageVibrationPatternTest {
    @Test
    fun moderateUsesOneShortPulse() {
        val pattern = BattleDamageVibrationPattern.forSeverity("moderate")

        assertArrayEquals(longArrayOf(0, 140), pattern.timings)
        assertArrayEquals(intArrayOf(0, 170), pattern.amplitudes)
    }

    @Test
    fun heavyUsesTwoStrongerPulses() {
        val pattern = BattleDamageVibrationPattern.forSeverity("heavy")

        assertArrayEquals(longArrayOf(0, 190, 90, 230), pattern.timings)
        assertArrayEquals(intArrayOf(0, 255, 0, 255), pattern.amplitudes)
    }
}
