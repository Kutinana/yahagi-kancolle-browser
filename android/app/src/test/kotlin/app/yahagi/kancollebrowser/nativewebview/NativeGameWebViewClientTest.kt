package app.yahagi.kancollebrowser.nativewebview

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class NativeGameWebViewClientTest {
    @Test
    fun reportsPageEventsForTheCurrentGeneration() {
        val events = mutableListOf<String>()
        val delegate = delegate(events)

        delegate.pageStarted("https://example.test/start")
        delegate.pageFinished("https://example.test/finish")

        assertEquals(
            listOf("started:https://example.test/start", "finished:https://example.test/finish"),
            events,
        )
    }

    @Test
    fun allowsOnlyHttpAndHttpsNavigation() {
        val events = mutableListOf<String>()
        val delegate = delegate(events)

        assertFalse(delegate.shouldOverrideUrlLoading("https://example.test/path?q=secret"))
        assertFalse(delegate.shouldOverrideUrlLoading("HTTP://example.test"))
        assertTrue(delegate.shouldOverrideUrlLoading("intent:#Intent;end"))
        assertTrue(delegate.shouldOverrideUrlLoading("javascript:alert(1)"))
        assertTrue(delegate.shouldOverrideUrlLoading(""))
        assertTrue(delegate.shouldOverrideUrlLoading("not a uri"))

        assertEquals(
            listOf("blocked:intent", "blocked:javascript", "blocked:invalid", "blocked:invalid"),
            events,
        )
    }

    @Test
    fun normalizesAndLimitsBlockedScheme() {
        val events = mutableListOf<String>()
        val delegate = delegate(events)

        delegate.shouldOverrideUrlLoading("CuStOmSchemeWhichIsFarLongerThanThirtyTwoCharacters:value")

        assertEquals("blocked:customschemewhichisfarlongerthan", events.single())
    }

    @Test
    fun blocksSubframeCustomSchemesWithoutReportingNavigation() {
        val events = mutableListOf<String>()
        val delegate = delegate(events)

        assertTrue(delegate.shouldOverrideUrlLoading("intent:#Intent;end", isMainFrame = false))
        assertFalse(delegate.shouldOverrideUrlLoading("https://example.test", isMainFrame = false))

        assertTrue(events.isEmpty())
    }

    @Test
    fun reportsOnlyMainFrameErrorsAndSanitizesDescriptions() {
        val events = mutableListOf<String>()
        val delegate = delegate(events)
        val description = "x".repeat(300)

        delegate.receivedError(isMainFrame = false, errorCode = -1, description = "subresource")
        delegate.receivedError(isMainFrame = true, errorCode = -2, description = description)

        assertEquals(1, events.size)
        assertEquals("error:-2:${"x".repeat(256)}", events.single())
    }

    @Test
    fun ignoresEventsForOldGeneration() {
        val events = mutableListOf<String>()
        val delegate = NativeGameWebViewClientDelegate(
            generation = 7,
            sink = recordingSink(events),
            acceptsGeneration = { false },
            prepareRenderProcessGone = { true },
            onRenderProcessGone = {},
        )

        delegate.pageStarted("https://example.test")
        delegate.receivedError(true, -1, "error")
        assertTrue(delegate.shouldOverrideUrlLoading("intent:#Intent;end"))
        assertTrue(delegate.renderProcessGone(didCrash = true))

        assertTrue(events.isEmpty())
    }

    @Test
    fun renderGoneEmitsBeforeCleanupAndIsolatesExceptions() {
        val events = mutableListOf<String>()
        val delegate = NativeGameWebViewClientDelegate(
            generation = 3,
            sink = object : NativeGameWebViewEventSink {
                override fun created(generation: Long) = Unit
                override fun pageStarted(generation: Long, url: String) = Unit
                override fun pageFinished(generation: Long, url: String) = Unit
                override fun mainFrameError(generation: Long, errorCode: Int, description: String) = Unit
                override fun navigationBlocked(generation: Long, scheme: String) = Unit
                override fun renderProcessGone(generation: Long, didCrash: Boolean) {
                    events += "event"
                    throw IllegalStateException("sink failure")
                }
                override fun destroyed(generation: Long) = Unit
            },
            acceptsGeneration = { true },
            prepareRenderProcessGone = { true },
            onRenderProcessGone = {
                events += "cleanup"
                throw IllegalStateException("cleanup failure")
            },
        )

        assertTrue(delegate.renderProcessGone(didCrash = true))

        assertEquals(listOf("event", "cleanup"), events)
    }

    @Test
    fun renderGonePreparesTheHostBeforeNotifyingTheSink() {
        val events = mutableListOf<String>()
        var active = true
        val delegate = NativeGameWebViewClientDelegate(
            generation = 3,
            sink = recordingSink(events),
            acceptsGeneration = { active },
            prepareRenderProcessGone = {
                events += "prepared"
                active = false
                true
            },
            onRenderProcessGone = { events += "cleanup" },
        )

        assertTrue(delegate.renderProcessGone(didCrash = true))

        assertEquals(listOf("prepared", "gone:true", "cleanup"), events)
    }

    private fun delegate(events: MutableList<String>) = NativeGameWebViewClientDelegate(
        generation = 2,
        sink = recordingSink(events),
        acceptsGeneration = { true },
        prepareRenderProcessGone = { true },
        onRenderProcessGone = {},
    )

    private fun recordingSink(events: MutableList<String>) = object : NativeGameWebViewEventSink {
        override fun created(generation: Long) = Unit
        override fun pageStarted(generation: Long, url: String) {
            events.add("started:$url")
        }
        override fun pageFinished(generation: Long, url: String) {
            events.add("finished:$url")
        }
        override fun mainFrameError(generation: Long, errorCode: Int, description: String) {
            events.add("error:$errorCode:$description")
        }
        override fun navigationBlocked(generation: Long, scheme: String) {
            events.add("blocked:$scheme")
        }
        override fun renderProcessGone(generation: Long, didCrash: Boolean) {
            events.add("gone:$didCrash")
        }
        override fun destroyed(generation: Long) = Unit
    }
}
