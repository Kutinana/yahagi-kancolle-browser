package app.yahagi.kancollebrowser.nativewebview

import app.yahagi.kancollebrowser.browser.GameTouchFeedbackScript
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class NativeGameWebViewConfiguratorTest {
    @Test
    fun navigationAndExplicitRecoveryRemainIndependentDuringRepeatedTransitions() {
        val states = mutableListOf<Boolean>()
        val bridge = NativeGamePresentationBridge(states::add)
        repeat(200) {
            bridge.postMessage("web")
            bridge.postMessage("pending")
            bridge.postMessage("pending")
            bridge.postMessage("game")
            repeat(10) { bridge.postMessage("game") }
            bridge.postMessage("game-fit")
            bridge.postMessage("game-fit")
        }
        assertEquals(List(200) { listOf(false, true, true, true) }.flatten(), states)
    }

    @Test
    fun explicitFitReappliesEvenWhenTheDocumentIsStillAGame() {
        val states = mutableListOf<Boolean>()
        val bridge = NativeGamePresentationBridge(states::add)
        bridge.postMessage("game")
        bridge.postMessage("game-fit")
        bridge.postMessage("game-fit")
        bridge.postMessage("game")
        assertEquals(listOf(true, true, true), states)
    }

    @Test
    fun delayedGameSurfaceMessageReappliesNativePresentation() {
        val presentationStates = mutableListOf<Boolean>()
        val bridge = NativeGamePresentationBridge(presentationStates::add)

        bridge.postMessage("game")
        bridge.postMessage("game")
        bridge.postMessage("pending")
        bridge.postMessage("pending")
        bridge.postMessage("game")
        bridge.postMessage("web")
        bridge.postMessage("web")
        bridge.postMessage("ignored")

        assertEquals(listOf(true, true, false), presentationStates)
    }

    @Test
    fun convertsChromiumAndroidUserAgentToTheExistingDesktopPolicy() {
        val source = "Mozilla/5.0 (Linux; Android 16) AppleWebKit/537.36 " +
            "(KHTML, like Gecko) Chrome/140.0.7339.0 Mobile Safari/537.36"

        val actual = NativeGameWebViewUserAgent.toDesktop(source)

        assertEquals(
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 " +
                "(KHTML, like Gecko) Chrome/140.0.7339.0 Safari/537.36",
            actual,
        )
    }

    @Test
    fun preservesUnknownUserAgentRatherThanInventingOne() {
        assertEquals("custom", NativeGameWebViewUserAgent.toDesktop("custom"))
        assertTrue(NativeGameWebViewConfigurationAction.entries.contains(
            NativeGameWebViewConfigurationAction.USER_AGENT_SET,
        ))
    }

    @Test
    fun nativeGameDocumentsDisableChromiumTapHighlightWithoutInterceptingInput() {
        val script = GameTouchFeedbackScript.source

        assertTrue(script.contains("-webkit-tap-highlight-color"))
        assertTrue(script.contains("transparent"))
        assertFalse(script.contains("preventDefault"))
        assertFalse(script.contains("addEventListener"))
        assertEquals(
            setOf("https://*.kancolle-server.com"),
            GameTouchFeedbackScript.allowedOriginRules,
        )
    }
}
