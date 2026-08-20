package app.yahagi.kancollebrowser.nativewebview

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class NativeGameWebViewConfiguratorTest {
    @Test
    fun delayedGameSurfaceMessageReappliesNativePresentation() {
        val presentationStates = mutableListOf<Boolean>()
        val bridge = NativeGamePresentationBridge(presentationStates::add)

        bridge.postMessage("web")
        bridge.postMessage("game")
        bridge.postMessage("ignored")

        assertEquals(listOf(false, true), presentationStates)
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
}
