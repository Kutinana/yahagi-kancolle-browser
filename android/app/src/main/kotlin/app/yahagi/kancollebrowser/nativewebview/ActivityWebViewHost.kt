package app.yahagi.kancollebrowser.nativewebview

import android.content.Context
import android.graphics.Color
import android.os.Looper
import android.view.View
import android.view.ViewGroup
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.FrameLayout

internal interface NativeGameWebViewCleanup {
    fun stopLoading(webView: WebView)
    fun loadBlank(webView: WebView)
    fun clearHistory(webView: WebView)
    fun removeAllViews(webView: WebView)
    fun clearWebChromeClient(webView: WebView)
    fun clearWebViewClient(webView: WebView)
    fun destroy(webView: WebView)
}

internal object AndroidNativeGameWebViewCleanup : NativeGameWebViewCleanup {
    override fun stopLoading(webView: WebView) = webView.stopLoading()

    override fun loadBlank(webView: WebView) = webView.loadUrl("about:blank")

    override fun clearHistory(webView: WebView) = webView.clearHistory()

    override fun removeAllViews(webView: WebView) = webView.removeAllViews()

    override fun clearWebChromeClient(webView: WebView) {
        webView.webChromeClient = null
    }

    override fun clearWebViewClient(webView: WebView) {
        webView.webViewClient = WebViewClient()
    }

    override fun destroy(webView: WebView) = webView.destroy()
}

/**
 * Owns a native game [WebView] mounted as the final child of [contentRoot].
 *
 * All public methods must be called on the Android main thread. Calls from a
 * background thread fail fast to keep View ownership and generation changes atomic.
 */
class ActivityWebViewHost internal constructor(
    private val context: Context,
    private val contentRoot: FrameLayout,
    private val eventSink: NativeGameWebViewEventSink,
    private val webViewFactory: (Context) -> WebView = { context -> WebView(context) },
    private val configureWebView: (WebView, WebViewClient) -> Unit = { webView, client ->
        NativeGameWebViewConfigurator.configure(webView, client)
    },
    private val webViewCleanup: NativeGameWebViewCleanup = AndroidNativeGameWebViewCleanup,
) {
    constructor(
        context: Context,
        contentRoot: FrameLayout,
        eventSink: NativeGameWebViewEventSink,
    ) : this(
        context = context,
        contentRoot = contentRoot,
        eventSink = eventSink,
        webViewFactory = { factoryContext -> WebView(factoryContext) },
        configureWebView = { webView, client ->
            NativeGameWebViewConfigurator.configure(webView, client)
        },
        webViewCleanup = AndroidNativeGameWebViewCleanup,
    )

    private val state = NativeGameWebViewHostState()
    private var ownedResources: OwnedWebViewResources? = null
    private var hasValidBounds = false

    internal val currentWebView: WebView?
        get() {
            requireMainThread()
            return ownedResources?.takeIf { state.phase == NativeGameWebViewHostPhase.READY }?.webView
        }

    val currentGeneration: Long?
        get() {
            requireMainThread()
            return state.generationId?.takeIf { state.phase == NativeGameWebViewHostPhase.READY }
        }

    fun create(): Long? {
        requireMainThread()
        if (state.phase != NativeGameWebViewHostPhase.ABSENT) {
            return null
        }

        val generation = state.beginCreate()
        val resources = OwnedWebViewResources(generation)
        // Publish a token before any allocation or hierarchy operation can throw.
        ownedResources = resources
        try {
            val createdOverlay = FrameLayout(context)
            resources.overlay = createdOverlay
            createdOverlay.apply {
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
            val createdWebView = webViewFactory(context)
            if (!isCurrentCreate(resources)) {
                cleanupStandaloneWebView(createdWebView)
                rollbackCreate(resources)
                return null
            }
            resources.webView = createdWebView
            val client = NativeGameWebViewClient(
                generation = generation,
                sink = eventSink,
                acceptsGeneration = { state.accepts(generation) },
                prepareRenderProcessGone = ::prepareRenderProcessGone,
                onRenderProcessGone = ::onRenderProcessGone,
            )
            configureWebView(createdWebView, client)
            if (!isCurrentCreate(resources)) {
                rollbackCreate(resources)
                return null
            }
            createdOverlay.addView(
                createdWebView,
                FrameLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    ViewGroup.LayoutParams.MATCH_PARENT,
                ),
            )
            if (!isCurrentCreate(resources)) {
                rollbackCreate(resources)
                return null
            }
            hasValidBounds = false
            if (!state.markReady(generation)) {
                rollbackCreate(resources)
                return null
            }
            runCatching { eventSink.created(generation) }
            return generation.takeIf { isCurrentReady(resources) }
        } catch (_: Throwable) {
            rollbackCreate(resources)
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
            ownedResources?.overlay?.visibility = View.INVISIBLE
            return false
        }
        val activeOverlay = ownedResources?.overlay ?: return false
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
        val activeOverlay = ownedResources?.overlay ?: return false
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

    /** Completes a renderer-loss transaction after its event has been delivered. */
    internal fun onRenderProcessGone(generation: Long): Boolean {
        requireMainThread()
        if (state.generationId != generation || state.phase != NativeGameWebViewHostPhase.DESTROYING) {
            return false
        }
        completeDestroy(generation, rendererGone = true)
        return true
    }

    /** Starts renderer-loss teardown before the client synchronously reports it to the sink. */
    private fun prepareRenderProcessGone(generation: Long): Boolean {
        requireMainThread()
        return beginDestroy(generation)
    }

    private fun destroyInternal(generation: Long, rendererGone: Boolean): Boolean {
        if (!beginDestroy(generation)) {
            return false
        }
        completeDestroy(generation, rendererGone)
        return true
    }

    private fun beginDestroy(generation: Long): Boolean {
        if (!state.beginDestroy(generation)) {
            return false
        }
        ownedResources?.overlay?.visibility = View.INVISIBLE
        hasValidBounds = false
        return true
    }

    private fun completeDestroy(generation: Long, rendererGone: Boolean) {
        val resources = ownedResources
        resources?.let { cleanupResources(it, rendererGone) }
        if (ownedResources === resources) {
            ownedResources = null
        }
        state.completeDestroy(generation)
        runCatching { eventSink.destroyed(generation) }
    }

    private fun rollbackCreate(resources: OwnedWebViewResources) {
        val canCompleteOldGeneration = state.beginDestroy(resources.generation)
        try {
            cleanupResources(resources, rendererGone = false)
        } finally {
            if (ownedResources === resources) {
                ownedResources = null
                hasValidBounds = false
            }
            if (canCompleteOldGeneration &&
                state.generationId == resources.generation &&
                state.phase == NativeGameWebViewHostPhase.DESTROYING
            ) {
                state.completeDestroy(resources.generation)
            }
        }
    }

    private fun cleanupResources(resources: OwnedWebViewResources, rendererGone: Boolean) {
        if (resources.cleaned) {
            return
        }
        resources.cleaned = true
        val activeOverlay = resources.overlay
        val activeWebView = resources.webView
        if (!rendererGone) {
            bestEffort { activeWebView?.let(webViewCleanup::stopLoading) }
            // The destroying state makes client callbacks reject this generation.
            bestEffort { activeWebView?.let(webViewCleanup::loadBlank) }
            bestEffort { activeWebView?.let(webViewCleanup::clearHistory) }
            bestEffort { activeWebView?.let(webViewCleanup::removeAllViews) }
        }
        bestEffort { activeOverlay?.removeView(activeWebView) }
        bestEffort { contentRoot.removeView(activeOverlay) }
        if (!rendererGone) {
            bestEffort { activeWebView?.let(webViewCleanup::clearWebChromeClient) }
            bestEffort { activeWebView?.let(webViewCleanup::clearWebViewClient) }
        }
        bestEffort { activeWebView?.let(webViewCleanup::destroy) }
    }

    private fun isCurrentCreate(resources: OwnedWebViewResources): Boolean =
        ownedResources === resources &&
            state.generationId == resources.generation &&
            state.phase == NativeGameWebViewHostPhase.CREATING

    private fun isCurrentReady(resources: OwnedWebViewResources): Boolean =
        ownedResources === resources &&
            state.generationId == resources.generation &&
            state.phase == NativeGameWebViewHostPhase.READY

    private fun cleanupStandaloneWebView(webView: WebView) {
        bestEffort { webViewCleanup.clearWebChromeClient(webView) }
        bestEffort { webViewCleanup.clearWebViewClient(webView) }
        bestEffort { webViewCleanup.destroy(webView) }
    }

    private class OwnedWebViewResources(
        val generation: Long,
        var overlay: FrameLayout? = null,
        var webView: WebView? = null,
        var cleaned: Boolean = false,
    )

    private fun bestEffort(operation: () -> Unit) {
        runCatching(operation)
    }

    private fun requireMainThread() {
        check(Looper.myLooper() == Looper.getMainLooper()) {
            "ActivityWebViewHost must be used on the Android main thread"
        }
    }
}
