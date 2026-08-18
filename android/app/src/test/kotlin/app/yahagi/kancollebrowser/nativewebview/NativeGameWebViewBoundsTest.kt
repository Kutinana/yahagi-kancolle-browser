package app.yahagi.kancollebrowser.nativewebview

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class NativeGameWebViewBoundsTest {
    @Test
    fun convertsLogicalBoundsToClippedPhysicalBounds() {
        val bounds = NativeGameWebViewBounds(
            left = 10.0,
            top = 20.0,
            width = 100.0,
            height = 50.0,
            devicePixelRatio = 2.0,
        )

        assertEquals(PhysicalBounds(20, 40, 220, 140), bounds.toPhysicalBounds(300, 200))
    }

    @Test
    fun roundsEachPhysicalEdgeBeforeClipping() {
        val bounds = NativeGameWebViewBounds(
            left = 0.25,
            top = 0.25,
            width = 10.5,
            height = 10.5,
            devicePixelRatio = 2.0,
        )

        assertEquals(PhysicalBounds(1, 1, 22, 22), bounds.toPhysicalBounds(100, 100))
    }

    @Test
    fun clipsNegativeOriginAndOverhangingRightBottomEdges() {
        val negativeOrigin = NativeGameWebViewBounds(-10.0, -5.0, 20.0, 15.0, 1.0)
        val overhanging = NativeGameWebViewBounds(90.0, 95.0, 20.0, 20.0, 1.0)

        assertEquals(PhysicalBounds(0, 0, 10, 10), negativeOrigin.toPhysicalBounds(100, 100))
        assertEquals(PhysicalBounds(90, 95, 100, 100), overhanging.toPhysicalBounds(100, 100))
    }

    @Test
    fun returnsNullForOutOfBoundsOrNonPositiveRootArea() {
        val outside = NativeGameWebViewBounds(200.0, 20.0, 10.0, 10.0, 1.0)

        assertNull(outside.toPhysicalBounds(100, 100))
        assertNull(outside.toPhysicalBounds(0, 100))
        assertNull(outside.toPhysicalBounds(100, -1))
    }

    @Test
    fun rejectsNonFiniteAndNonPositiveLogicalValues() {
        assertIllegalArgument { NativeGameWebViewBounds(Double.NaN, 0.0, 1.0, 1.0, 1.0) }
        assertIllegalArgument { NativeGameWebViewBounds(0.0, Double.POSITIVE_INFINITY, 1.0, 1.0, 1.0) }
        assertIllegalArgument { NativeGameWebViewBounds(0.0, 0.0, 0.0, 1.0, 1.0) }
        assertIllegalArgument { NativeGameWebViewBounds(0.0, 0.0, 1.0, -1.0, 1.0) }
        assertIllegalArgument { NativeGameWebViewBounds(0.0, 0.0, 1.0, 1.0, 0.0) }
    }

    @Test
    fun rejectsOverflowInsteadOfCreatingAClampedRectangle() {
        val overflowingEdge = NativeGameWebViewBounds(Double.MAX_VALUE, 0.0, 1.0, 1.0, 1.0)
        val overflowingScale = NativeGameWebViewBounds(1.0, 1.0, 1.0, 1.0, Double.MAX_VALUE)

        assertNull(overflowingEdge.toPhysicalBounds(100, 100))
        assertNull(overflowingScale.toPhysicalBounds(100, 100))
    }

    @Test
    fun physicalBoundsExposeDimensions() {
        val bounds = PhysicalBounds(3, 5, 11, 18)

        assertEquals(8, bounds.width)
        assertEquals(13, bounds.height)
    }

    @Test
    fun physicalBoundsRejectInvalidOrOverflowProneExtremes() {
        val largest = PhysicalBounds(0, 0, Int.MAX_VALUE, Int.MAX_VALUE)

        assertEquals(Int.MAX_VALUE, largest.width)
        assertEquals(Int.MAX_VALUE, largest.height)
        assertIllegalArgument { PhysicalBounds(-1, 0, 1, 1) }
        assertIllegalArgument { PhysicalBounds(0, -1, 1, 1) }
        assertIllegalArgument { PhysicalBounds(0, 0, 0, 1) }
        assertIllegalArgument { PhysicalBounds(0, 0, 1, 0) }
    }

    private fun assertIllegalArgument(block: () -> Unit) {
        try {
            block()
        } catch (_: IllegalArgumentException) {
            return
        }
        throw AssertionError("Expected IllegalArgumentException")
    }
}
