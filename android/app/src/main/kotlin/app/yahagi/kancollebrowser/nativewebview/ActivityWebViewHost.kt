package app.yahagi.kancollebrowser.nativewebview

import android.content.Context
import android.graphics.Color
import android.os.Looper
import android.view.View
import android.view.ViewGroup
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.FrameLayout

/**
 * Owns a native game [WebView] mounted as the final child of [contentRoot].
 *
 * All public methods must be called on the Android main thread. Calls from a
 * background thread fail fast to keep View ownership and generation changes atomic.
 */
class ActivityWebViewHost(
    private val context: Context,
    private val contentRoot: FrameLayout,
    private val eventSink: NativeGameWebViewEventSink,
    private val webViewFactory: (Context) -> WebView = { WebView(it) },
    private val configureWebView: (WebView, WebViewClient) -> Unit = NativeGameWebViewConfigurator::configure,
) {
    private val state = NativeGameWebViewHostState()
    private var overlay: FrameLayout? = null
    private var webView: WebView? = null
    private var hasValidBounds = false

    val currentWebView: WebView?
        get() {
            requireMainThread()
            return webView
        }

    val currentGeneration: Long?
        get() {
            requireMainThread()
            return state.generationId
        }

    fun create(): Long? {
        requireMainThread()
        if (state.phase != NativeGameWebViewHostPhase.ABSENT) {
            return null
        }

        val generation = state.beginCreate()
        var createdOverlay: FrameLayout? = null
        var createdWebView: WebView? = null
        try {
            createdOverlay = FrameLayout(context).apply {
                visibility = View.INVISIBLE
                setBackgroundColor(Color.TRANSPARENT)
                clipChildren = true
                clipToPadding = true
            }
            contentRoot.addView(
                createdOverlay,
                FrameLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    ViewGroup.LayoutParams.MATCH_PARENT,
                ),
            )
            createdWebView = webViewFactory(context)
            val client = NativeGameWebViewClient(
                generation = generation,
                sink = eventSink,
                acceptsGeneration = { state.accepts(generation) },
                onRenderProcessGone = ::onRenderProcessGone,
            )
            configureWebView(createdWebView, client)
            createdOverlay.addView(
                createdWebView,
                FrameLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    ViewGroup.LayoutParams.MATCH_PARENT,
                ),
            )
            overlay = createdOverlay
            webView = createdWebView
            hasValidBounds = false
            check(state.markReady(generation))
            runCatching { eventSink.created(generation) }
            return generation
        } catch (_: Throwable) {
            rollbackCreate(generation, createdOverlay, createdWebView)
            return null
        }
    }

    fun setBounds(generation: Long, bounds: NativeGameWebViewBounds?): Boolean {
        requireMainThread()
        if (!state.accepts(generation)) {
            return false
        }
        val physicalBounds = bounds?.toPhysicalBounds(contentRoot.width, contentRoot.height)
        if (physicalBounds == null) {
            hasValidBounds = false
            overlay?.visibility = View.INVISIBLE
            return false
        }
        val activeOverlay = overlay ?: return false
        activeOverlay.layoutParams = FrameLayout.LayoutParams(
            physicalBounds.width,
            physicalBounds.height,
        ).apply {
            leftMargin = physicalBounds.left
            topMargin = physicalBounds.top
        }
        hasValidBounds = true
        return true
    }

    fun setVisible(generation: Long, visible: Boolean): Boolean {
        requireMainThread()
        if (!state.accepts(generation)) {
            return false
        }
        val activeOverlay = overlay ?: return false
        if (!visible) {
            activeOverlay.visibility = View.INVISIBLE
            return true
        }
        if (state.phase != NativeGameWebViewHostPhase.READY || !hasValidBounds) {
            activeOverlay.visibility = View.INVISIBLE
            return false
        }
        activeOverlay.visibility = View.VISIBLE
        return true
    }

    fun destroy(generation: Long): Boolean {
        requireMainThread()
        return destroyInternal(generation, rendererGone = false)
    }

    /** Idempotent lifecycle cleanup for the owning Activity's `onDestroy`. */
    fun destroyCurrent(): Boolean {
        requireMainThread()
        return state.generationId?.let { destroyInternal(it, rendererGone = false) } ?: false
    }

    /** Called by [NativeGameWebViewClient] after it reports a renderer loss. */
    fun onRenderProcessGone(generation: Long): Boolean {
        requireMainThread()
        return destroyInternal(generation, rendererGone = true)
    }

    private fun destroyInternal(generation: Long, rendererGone: Boolean): Boolean {
        if (!state.beginDestroy(generation)) {
            return false
        }
        val activeOverlay = overlay
        val activeWebView = webView
        activeOverlay?.visibility = View.INVISIBLE
        hasValidBounds = false

        if (!rendererGone) {
            bestEffort { activeWebView?.stopLoading() }
            // The destroying state makes client callbacks reject this generation.
            bestEffort { activeWebView?.loadUrl("about:blank") }
            bestEffort { activeWebView?.clearHistory() }
            bestEffort { activeWebView?.removeAllViews() }
        }
        bestEffort { activeOverlay?.removeView(activeWebView) }
        bestEffort { contentRoot.removeView(activeOverlay) }
        bestEffort { activeWebView?.webChromeClient = null }
        bestEffort { activeWebView?.webViewClient = WebViewClient() }
        bestEffort { activeWebView?.destroy() }

        overlay = null
        webView = null
        state.completeDestroy(generation)
        runCatching { eventSink.destroyed(generation) }
        return true
    }

    private fun rollbackCreate(
        generation: Long,
        createdOverlay: FrameLayout?,
        createdWebView: WebView?,
    ) {
        bestEffort { createdOverlay?.visibility = View.INVISIBLE }
        bestEffort { createdOverlay?.removeView(createdWebView) }
        bestEffort { contentRoot.removeView(createdOverlay) }
        bestEffort { createdWebView?.webChromeClient = null }
        bestEffort { createdWebView?.webViewClient = WebViewClient() }
        bestEffort { createdWebView?.destroy() }
        overlay = null
        webView = null
        hasValidBounds = false
        if (state.beginDestroy(generation)) {
            state.completeDestroy(generation)
        }
    }

    private fun bestEffort(operation: () -> Unit) {
        runCatching(operation)
    }

    private fun requireMainThread() {
        check(Looper.myLooper() == Looper.getMainLooper()) {
            "ActivityWebViewHost must be used on the Android main thread"
        }
    }
}
