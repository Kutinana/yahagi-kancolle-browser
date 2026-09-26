package app.yahagi.kancollebrowser.browser

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class GameMouseWheelPolicyTest {
    @Test fun acceptsBothDirectionsIncludingFractionalWheels() {
        assertTrue(GameMouseWheelPolicy.accepts(0.5, 0.25, 0.0, 120.0))
        assertTrue(GameMouseWheelPolicy.accepts(0.5, 0.25, 0.0, -0.25))
    }

    @Test fun rejectsOutOfBoundsZeroVerticalAndNonFiniteValues() {
        assertFalse(GameMouseWheelPolicy.accepts(-0.1, 0.5, 0.0, 120.0))
        assertFalse(GameMouseWheelPolicy.accepts(1.0, 0.5, 0.0, 120.0))
        assertFalse(GameMouseWheelPolicy.accepts(0.5, 1.0, 0.0, 120.0))
        assertFalse(GameMouseWheelPolicy.accepts(0.5, 0.5, 120.0, 0.0))
        assertFalse(GameMouseWheelPolicy.accepts(Double.NaN, 0.5, 0.0, 120.0))
        assertFalse(GameMouseWheelPolicy.accepts(0.5, 0.5, 0.0, Double.POSITIVE_INFINITY))
    }
}
