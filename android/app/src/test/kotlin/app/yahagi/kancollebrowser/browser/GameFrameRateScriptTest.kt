package app.yahagi.kancollebrowser.browser

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class GameFrameRateScriptTest {
    @Test
    fun mapsWireModesAndFallsBackToAuto() {
        assertEquals(GameFrameRateMode.AUTO, GameFrameRateMode.fromWireName("auto"))
        assertEquals(GameFrameRateMode.STABLE_30, GameFrameRateMode.fromWireName("stable30"))
        assertEquals(GameFrameRateMode.HIGH_REFRESH, GameFrameRateMode.fromWireName("prefer60"))
        assertEquals(GameFrameRateMode.AUTO, GameFrameRateMode.fromWireName("future-mode"))
    }

    @Test
    fun eachModeChoosesTheExpectedRemoteMainScriptTicker() {
        assertEquals(GameMainScriptTickerMode.CAPPED_60, GameFrameRateMode.AUTO.mainScriptTickerMode)
        assertEquals(null, GameFrameRateMode.STABLE_30.mainScriptTickerMode)
        assertEquals(
            GameMainScriptTickerMode.HIGH_REFRESH,
            GameFrameRateMode.HIGH_REFRESH.mainScriptTickerMode,
        )
    }

    @Test
    fun recognizesOnlyKancolleMainScripts() {
        assertTrue(
            GameMainScriptPatcher.isMainScriptUrl(
                "https://w00g.kancolle-server.com/kcs2/js/main.js?version=1",
            ),
        )
        assertFalse(
            GameMainScriptPatcher.isMainScriptUrl(
                "https://w00g.kancolle-server.com/kcs2/js/vendor.js",
            ),
        )
        assertFalse(
            GameMainScriptPatcher.isMainScriptUrl(
                "https://w00g.kancolle-server.com.evil.example/kcs2/js/main.js",
            ),
        )
    }

    @Test
    fun patchesCreateJsTickerToCapped60ForAutomaticMode() {
        val original = "createjs.Ticker.timingMode=createjs.Ticker.TIMEOUT,b=1;"
        assertEquals(
            "createjs.Ticker.timingMode=createjs.Ticker.RAF_SYNCHED,b=1;",
            GameMainScriptPatcher.patch(original, GameMainScriptTickerMode.CAPPED_60),
        )
    }

    @Test
    fun patchesCreateJsTickerToUnthrottledRafForHighRefreshMode() {
        val original = "createjs.Ticker.timingMode=createjs.Ticker.TIMEOUT,b=1;"
        assertEquals(
            "createjs.Ticker.timingMode=createjs.Ticker.RAF,b=1;",
            GameMainScriptPatcher.patch(original, GameMainScriptTickerMode.HIGH_REFRESH),
        )
    }

    @Test
    fun unmatchedScriptIsReturnedUnchanged() {
        val original = "console.log('main');"
        assertEquals(
            original,
            GameMainScriptPatcher.patch(original, GameMainScriptTickerMode.CAPPED_60),
        )
    }

    @Test
    fun runtimeBridgeScriptControlsTheTickerInsideEachDocument() {
        val script = GameFrameRateBridgeScript.source

        assertTrue(script.contains("window.YahagiFrameRate"))
        assertTrue(script.contains("bridge.postMessage"))
        assertTrue(script.contains("bridge.onmessage"))
        assertTrue(script.contains("createjs.Ticker"))
        assertTrue(script.contains("getMeasuredFPS"))
        assertTrue(script.contains("highRefresh"))
        assertTrue(script.contains("ticker.RAF_SYNCHED"))
        assertTrue(script.contains("ticker.RAF"))
        assertTrue(script.contains("ticker.TIMEOUT"))
        assertFalse(script.contains("fetch("))
        assertFalse(script.contains("XMLHttpRequest"))
        assertFalse(script.contains("dispatchEvent"))
    }
}
