package app.yahagi.kancollebrowser.browser

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class GameFrameRateScriptTest {
    @Test
    fun mapsWireModesAndFallsBackToAuto() {
        assertEquals(GameFrameRateMode.AUTO, GameFrameRateMode.fromWireName("auto"))
        assertEquals(GameFrameRateMode.STABLE_60, GameFrameRateMode.fromWireName("stable60"))
        assertEquals(GameFrameRateMode.STABLE_30, GameFrameRateMode.fromWireName("stable30"))
        assertEquals(GameFrameRateMode.HIGH_REFRESH, GameFrameRateMode.fromWireName("highRefresh"))
        assertEquals(GameFrameRateMode.AUTO, GameFrameRateMode.fromWireName("prefer60"))
        assertEquals(GameFrameRateMode.AUTO, GameFrameRateMode.fromWireName("future-mode"))
    }

    @Test
    fun runtimeBridgeScriptControlsTheTickerInsideEachDocument() {
        val script = GameFrameRateBridgeScript.source

        assertTrue(script.contains("window.YahagiFrameRate"))
        assertTrue(script.contains("bridge.postMessage"))
        assertTrue(script.contains("bridge.onmessage"))
        assertTrue(script.contains("createjs.Ticker"))
        assertTrue(script.contains("getMeasuredFPS"))
        assertTrue(script.contains("ticker.RAF_SYNCHED"))
        assertTrue(script.contains("ticker.TIMEOUT"))
        assertTrue(script.contains("highRefresh"))
        assertTrue(script.contains("ticker.timingMode = ticker.RAF"))
        assertFalse(script.contains("fetch("))
        assertFalse(script.contains("XMLHttpRequest"))
        assertFalse(script.contains("dispatchEvent"))
    }
}
