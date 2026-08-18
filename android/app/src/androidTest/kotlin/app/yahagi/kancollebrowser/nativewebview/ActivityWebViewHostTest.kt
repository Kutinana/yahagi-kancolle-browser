package app.yahagi.kancollebrowser.nativewebview

import android.content.Context
import android.os.Build
import android.view.View
import android.view.ViewGroup
import android.webkit.CookieManager
import android.webkit.WebView
import android.widget.FrameLayout
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class ActivityWebViewHostTest {
    private val instrumentation = InstrumentationRegistry.getInstrumentation()
    private val context = ApplicationProvider.getApplicationContext<Context>()
    private var host: ActivityWebViewHost? = null

    @After
    fun tearDown() = onMain {
        host?.destroyCurrent()
        host = null
    }

    @Test
    fun createAddsInvisibleOverlayAfterExistingFlutterChildAndConfiguresWebView() = onMain {
        val root = sizedRoot()
        val flutterChild = View(context)
        root.addView(flutterChild)
        val events = mutableListOf<String>()
        val configurationActions = mutableListOf<NativeGameWebViewConfigurationAction>()
        var initialUserAgent = ""
        var initialCacheMode = 0
        var initialFileAccessFromFileUrls = false
        var initialUniversalAccessFromFileUrls = false
        host = ActivityWebViewHost(
            context = context,
            contentRoot = root,
            eventSink = recordingSink(events),
            configureWebView = { webView, client ->
                initialUserAgent = webView.settings.userAgentString
                initialCacheMode = webView.settings.cacheMode
                initialFileAccessFromFileUrls = webView.settings.allowFileAccessFromFileURLs
                initialUniversalAccessFromFileUrls = webView.settings.allowUniversalAccessFromFileURLs
                NativeGameWebViewConfigurator.configure(webView, client) { action ->
                    configurationActions += action
                }
            },
        )

        val generation = requireNotNull(host!!.create())
        val overlay = root.getChildAt(1) as FrameLayout
        val webView = requireNotNull(host!!.currentWebView)

        assertEquals(2, root.childCount)
        assertSame(overlay, root.getChildAt(root.childCount - 1))
        assertEquals(View.INVISIBLE, overlay.visibility)
        assertEquals(1, overlay.childCount)
        assertSame(webView, overlay.getChildAt(0))
        assertEquals(1, countWebViews(root))
        assertEquals(ViewGroup.LayoutParams.MATCH_PARENT, webView.layoutParams.width)
        assertEquals(ViewGroup.LayoutParams.MATCH_PARENT, webView.layoutParams.height)
        assertTrue(webView.settings.javaScriptEnabled)
        assertTrue(webView.settings.domStorageEnabled)
        assertFalse(webView.settings.mediaPlaybackRequiresUserGesture)
        assertEquals(View.LAYER_TYPE_HARDWARE, webView.layerType)
        assertTrue(CookieManager.getInstance().acceptCookie())
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            assertTrue(CookieManager.getInstance().acceptThirdPartyCookies(webView))
        }
        assertEquals(initialUserAgent, webView.settings.userAgentString)
        assertEquals(initialCacheMode, webView.settings.cacheMode)
        assertEquals(initialFileAccessFromFileUrls, webView.settings.allowFileAccessFromFileURLs)
        assertEquals(
            initialUniversalAccessFromFileUrls,
            webView.settings.allowUniversalAccessFromFileURLs,
        )
        assertTrue(NativeGameWebViewConfigurationAction.DATABASE_ENABLED in configurationActions)
        assertTrue(NativeGameWebViewConfigurationAction.BACKGROUND_BLACK in configurationActions)
        assertTrue(NativeGameWebViewConfigurationAction.WEB_VIEW_CLIENT_SET in configurationActions)
        assertTrue(NativeGameWebViewConfigurationAction.WEB_CHROME_CLIENT_SET in configurationActions)
        assertEquals(listOf("created:$generation"), events)
    }

    @Test
    fun appliesBoundsShowsOnlyWithValidBoundsAndRejectsOldGeneration() = onMain {
        val root = sizedRoot()
        host = ActivityWebViewHost(context, root, recordingSink(mutableListOf()))
        val generation = requireNotNull(host!!.create())
        val overlay = root.getChildAt(0) as FrameLayout

        assertFalse(host!!.setVisible(generation, true))
        assertEquals(View.INVISIBLE, overlay.visibility)
        assertTrue(host!!.setBounds(generation, NativeGameWebViewBounds(10.0, 20.0, 100.0, 50.0, 2.0)))
        val params = overlay.layoutParams as FrameLayout.LayoutParams
        assertEquals(200, params.width)
        assertEquals(100, params.height)
        assertEquals(20, params.leftMargin)
        assertEquals(40, params.topMargin)
        assertTrue(host!!.setVisible(generation, true))
        assertEquals(View.VISIBLE, overlay.visibility)
        assertFalse(host!!.setBounds(generation, NativeGameWebViewBounds(1000.0, 0.0, 10.0, 10.0, 1.0)))
        assertEquals(View.INVISIBLE, overlay.visibility)
        assertFalse(host!!.setBounds(generation + 1, NativeGameWebViewBounds(1.0, 1.0, 10.0, 10.0, 1.0)))
    }

    @Test
    fun destroysOnceAndAllowsNewGeneration() = onMain {
        val root = sizedRoot()
        val events = mutableListOf<String>()
        host = ActivityWebViewHost(context, root, recordingSink(events))
        val first = requireNotNull(host!!.create())

        assertTrue(host!!.destroy(first))
        assertEquals(0, root.childCount)
        assertNull(host!!.currentWebView)
        assertNull(host!!.currentGeneration)
        assertFalse(host!!.destroy(first))
        val second = requireNotNull(host!!.create())

        assertTrue(second > first)
        assertFalse(host!!.setVisible(first, false))
        assertEquals(listOf("created:$first", "destroyed:$first", "created:$second"), events)
    }

    @Test
    fun clientRenderGoneEmitsBeforeHostCleanupAndDestroyed() = onMain {
        val root = sizedRoot()
        val events = mutableListOf<String>()
        var client: NativeGameWebViewClient? = null
        host = ActivityWebViewHost(
            context = context,
            contentRoot = root,
            eventSink = recordingSink(events),
            configureWebView = { webView, suppliedClient ->
                client = suppliedClient as NativeGameWebViewClient
                NativeGameWebViewConfigurator.configure(webView, suppliedClient)
            },
        )
        val generation = requireNotNull(host!!.create())

        assertTrue(client!!.onRenderProcessGone(requireNotNull(host!!.currentWebView), null))

        assertEquals(0, root.childCount)
        assertEquals(
            listOf("created:$generation", "gone:$generation:false", "destroyed:$generation"),
            events,
        )
    }

    @Test
    fun destroyContinuesAfterCleanupOperationThrows() = onMain {
        val root = sizedRoot()
        val events = mutableListOf<String>()
        val cleanupCalls = mutableListOf<String>()
        host = ActivityWebViewHost(
            context = context,
            contentRoot = root,
            eventSink = recordingSink(events),
            webViewCleanup = throwingCleanup(cleanupCalls),
        )
        val generation = requireNotNull(host!!.create())

        assertTrue(host!!.destroy(generation))

        assertEquals(0, root.childCount)
        assertNull(host!!.currentWebView)
        assertNull(host!!.currentGeneration)
        assertEquals(listOf("created:$generation", "destroyed:$generation"), events)
        assertEquals(
            listOf("stop", "blank", "history", "contents", "chrome", "client", "destroy"),
            cleanupCalls,
        )
    }

    @Test
    fun rollsBackFactoryFailureAndCanCreateAfterward() = onMain {
        val root = sizedRoot()
        val failing = ActivityWebViewHost(
            context = context,
            contentRoot = root,
            eventSink = recordingSink(mutableListOf()),
            webViewFactory = { throw IllegalStateException("factory failure") },
        )

        assertNull(failing.create())
        assertEquals(0, root.childCount)
        assertNull(failing.currentGeneration)
        host = ActivityWebViewHost(context, root, recordingSink(mutableListOf()))
        assertNotNull(host!!.create())
    }

    @Test
    fun rollsBackConfigurationFailureWithoutLeakingTheWebView() = onMain {
        val root = sizedRoot()
        val failing = ActivityWebViewHost(
            context = context,
            contentRoot = root,
            eventSink = recordingSink(mutableListOf()),
            configureWebView = { _, _ -> throw IllegalStateException("configuration failure") },
        )

        assertNull(failing.create())
        assertEquals(0, root.childCount)
        assertNull(failing.currentWebView)
        assertNull(failing.currentGeneration)
    }

    @Test
    fun rejectsPublicCallsFromBackgroundThread() {
        onMain {
            host = ActivityWebViewHost(context, sizedRoot(), recordingSink(mutableListOf()))
        }

        try {
            host!!.currentGeneration
        } catch (_: IllegalStateException) {
            return
        }
        throw AssertionError("Expected a main-thread violation")
    }

    private fun sizedRoot(): FrameLayout = FrameLayout(context).apply {
        measure(
            View.MeasureSpec.makeMeasureSpec(800, View.MeasureSpec.EXACTLY),
            View.MeasureSpec.makeMeasureSpec(600, View.MeasureSpec.EXACTLY),
        )
        layout(0, 0, 800, 600)
    }

    private fun countWebViews(view: View): Int = when (view) {
        is WebView -> 1
        is ViewGroup -> (0 until view.childCount).sumOf { countWebViews(view.getChildAt(it)) }
        else -> 0
    }

    private fun throwingCleanup(calls: MutableList<String>) = object : NativeGameWebViewCleanup {
        override fun stopLoading(webView: WebView) {
            calls += "stop"
            throw IllegalStateException("stop failure")
        }

        override fun loadBlank(webView: WebView) {
            calls += "blank"
            throw IllegalStateException("blank failure")
        }

        override fun clearHistory(webView: WebView) {
            calls += "history"
            webView.clearHistory()
        }

        override fun removeAllViews(webView: WebView) {
            calls += "contents"
            webView.removeAllViews()
        }

        override fun clearWebChromeClient(webView: WebView) {
            calls += "chrome"
            webView.webChromeClient = null
        }

        override fun clearWebViewClient(webView: WebView) {
            calls += "client"
            webView.webViewClient = android.webkit.WebViewClient()
        }

        override fun destroy(webView: WebView) {
            calls += "destroy"
            webView.destroy()
        }
    }

    private fun recordingSink(events: MutableList<String>) = object : NativeGameWebViewEventSink {
        override fun created(generation: Long) {
            events += "created:$generation"
        }
        override fun pageStarted(generation: Long, url: String) = Unit
        override fun pageFinished(generation: Long, url: String) = Unit
        override fun mainFrameError(generation: Long, errorCode: Int, description: String) = Unit
        override fun navigationBlocked(generation: Long, scheme: String) = Unit
        override fun renderProcessGone(generation: Long, didCrash: Boolean) {
            events += "gone:$generation:$didCrash"
        }
        override fun destroyed(generation: Long) {
            events += "destroyed:$generation"
        }
    }

    private fun onMain(block: () -> Unit) {
        instrumentation.runOnMainSync(block)
    }
}
