package app.yahagi.kancollebrowser.browser

import org.junit.Assert.*
import org.junit.Test

class FullscreenExitGestureTest {
    @Test fun aDragNeverBecomesAClickEvenAfterReturningToItsOrigin() {
        val gesture = FullscreenExitGesture(8f)
        gesture.begin(100f, 100f)
        assertTrue(gesture.move(120f, 100f))
        assertTrue(gesture.move(100f, 100f))
        assertFalse(gesture.finish(cancelled = false))
    }

    @Test fun tapsAllowSmallFingerMotionButCancellationNeverClicks() {
        val gesture = FullscreenExitGesture(8f)
        gesture.begin(100f, 100f)
        assertFalse(gesture.move(102f, 103f))
        assertTrue(gesture.finish(cancelled = false))
        gesture.begin(100f, 100f)
        assertFalse(gesture.finish(cancelled = true))
    }
}
