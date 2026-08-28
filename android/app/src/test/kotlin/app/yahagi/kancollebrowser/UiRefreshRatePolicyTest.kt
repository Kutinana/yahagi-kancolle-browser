package app.yahagi.kancollebrowser

import org.junit.Assert.assertEquals
import org.junit.Test

class UiRefreshRatePolicyTest {
    @Test
    fun selectsTheHighestSupportedRefreshRate() {
        assertEquals(60f, UiRefreshRatePolicy.highestSupported(listOf(60f)))
        assertEquals(90f, UiRefreshRatePolicy.highestSupported(listOf(60f, 90f)))
        assertEquals(
            120f,
            UiRefreshRatePolicy.highestSupported(listOf(120f, 60f, 90f, 120f)),
        )
    }

    @Test
    fun ignoresInvalidRefreshRates() {
        assertEquals(
            90f,
            UiRefreshRatePolicy.highestSupported(
                listOf(Float.NaN, Float.POSITIVE_INFINITY, -1f, 0f, 90f),
            ),
        )
    }

    @Test
    fun returnsNoPreferenceWhenNoValidRateExists() {
        assertEquals(
            0f,
            UiRefreshRatePolicy.highestSupported(
                listOf(Float.NaN, Float.NEGATIVE_INFINITY, -1f, 0f),
            ),
        )
        assertEquals(0f, UiRefreshRatePolicy.highestSupported(emptyList()))
    }
}
