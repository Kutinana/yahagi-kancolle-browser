package app.yahagi.kancollebrowser.browser

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class GameFrameReloadBridgeTest {
    @Test
    fun platformViewDocumentsDisableChromiumTapHighlightBeforeNavigation() {
        val scripts = platformGameDocumentStartScripts()

        val touchFeedback = scripts.single {
            it.source.contains("-webkit-tap-highlight-color")
        }
        assertTrue(touchFeedback.source.contains("transparent"))
        assertFalse(touchFeedback.source.contains("preventDefault"))
        assertEquals(
            setOf("https://*.kancolle-server.com"),
            touchFeedback.allowedOriginRules,
        )
    }

    @Test
    fun scriptReloadsOnlyHtmlWrapAndNeverReloadsTopWindow() {
        val source = GameFrameReloadBridgeScript.source

        assertTrue(source.contains("getElementById('htmlWrap')"))
        assertTrue(source.contains("game.contentWindow.location.reload()"))
        assertTrue(source.contains("game.setAttribute('src', source)"))
        assertFalse(source.contains("window.location.reload()"))
    }

    @Test
    fun scriptReportsTargetAfterDomIsAvailable() {
        val source = GameFrameReloadBridgeScript.source

        assertTrue(source.contains("kind: 'target'"))
        assertTrue(source.contains("DOMContentLoaded"))
        assertTrue(source.contains("available:"))
    }

    @Test
    fun scriptObservesHtmlWrapInsertedAfterDomContentLoaded() {
        val source = GameFrameReloadBridgeScript.source

        assertTrue(source.contains("MutationObserver"))
        assertTrue(source.contains("observer.observe"))
    }

    @Test
    fun coordinatorCompletesMatchingRequestOnlyOnce() {
        val coordinator = GameFrameReloadRequestCoordinator(
            requestIdFactory = { "request-1" },
        )
        val results = mutableListOf<String>()
        val request = coordinator.start(results::add)

        assertEquals("request-1", request)
        assertFalse(coordinator.complete("wrong", "reloaded"))
        assertTrue(coordinator.complete(request, "reloaded"))
        assertFalse(coordinator.complete(request, "reloaded"))
        assertEquals(listOf("reloaded"), results)
    }

    @Test
    fun coordinatorCancelsPendingRequestOnlyOnce() {
        val coordinator = GameFrameReloadRequestCoordinator(
            requestIdFactory = { "request-1" },
        )
        val results = mutableListOf<String>()
        coordinator.start(results::add)

        assertTrue(coordinator.cancel("blocked"))
        assertFalse(coordinator.cancel("blocked"))
        assertEquals(listOf("blocked"), results)
    }
}
