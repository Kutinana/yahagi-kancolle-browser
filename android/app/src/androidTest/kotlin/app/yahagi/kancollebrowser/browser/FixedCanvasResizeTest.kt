package app.yahagi.kancollebrowser.browser

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import app.yahagi.kancollebrowser.nativewebview.NativeGamePresentationBridge
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class FixedCanvasResizeTest {
    @Test
    fun loadedDocumentFitsRepeatedWindowAndFullscreenChangesWithoutReload() {
        val instrumentation = InstrumentationRegistry.getInstrumentation()
        lateinit var view: WebView
        var cleanup: WebView? = null
        lateinit var bridge: NativeGamePresentationBridge
        val policy = FixedCanvasScalePolicy()
        val loaded = CountDownLatch(1)
        var pageFinishes = 0
        try {
            instrumentation.runOnMainSync {
                view = WebView(ApplicationProvider.getApplicationContext<Context>())
                cleanup = view
                view.settings.javaScriptEnabled = true
                view.settings.useWideViewPort = true
                view.settings.loadWithOverviewMode = false
                view.settings.builtInZoomControls = true
                view.layout(0, 0, 1200, 720)
                bridge = NativeGamePresentationBridge { game ->
                    if (game) {
                        policy.nextScalePercent(view.width, view.height, 1200, 720, force = true)
                            ?.let(view::setInitialScale)
                    }
                }
                bridge.postMessage("game")
                view.webViewClient = object : WebViewClient() {
                    override fun onPageFinished(view: WebView?, url: String?) {
                        pageFinishes++
                        loaded.countDown()
                    }
                }
                view.loadDataWithBaseURL("https://localhost/", "<html><body style='margin:0;width:1200px;height:720px'>canvas</body></html>", "text/html", "UTF-8", null)
            }
            assertTrue("Local page loaded", loaded.await(15, TimeUnit.SECONDS))
            // Page finish, split-screen, restoration, fullscreen, exit, and
            // Chromium resetting its scale without changing the outer bounds.
            for (width in listOf(1200, 600, 1200, 1500, 900, 600, 600)) {
                val resized = CountDownLatch(1)
                var actual = 0f
                instrumentation.runOnMainSync {
                    view.layout(0, 0, width, width * 3 / 5)
                    view.setInitialScale(100) // Simulate a document/renderer reset.
                    bridge.postMessage("game-fit")
                    Handler(Looper.getMainLooper()).postDelayed({
                        @Suppress("DEPRECATION")
                        actual = view.scale
                        resized.countDown()
                    }, 300)
                }
                assertTrue("Scale observation completed", resized.await(5, TimeUnit.SECONDS))
                assertEquals("Canvas fits width $width", width / 1200f, actual, 0.02f)
            }
            assertEquals("Fitting never reloads the document", 1, pageFinishes)
        } finally {
            instrumentation.runOnMainSync { cleanup?.destroy() }
        }
    }
}
