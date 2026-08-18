package app.yahagi.kancollebrowser.nativewebview

import android.graphics.Bitmap
import android.os.Build
import android.webkit.RenderProcessGoneDetail
import android.webkit.WebResourceError
import android.webkit.WebResourceRequest
import android.webkit.WebView
import android.webkit.WebViewClient
import java.util.Locale

interface NativeGameWebViewEventSink {
    fun created(generation: Long)
    fun pageStarted(generation: Long, url: String)
    fun pageFinished(generation: Long, url: String)
    fun mainFrameError(generation: Long, errorCode: Int, description: String)
    fun navigationBlocked(generation: Long, scheme: String)
    fun renderProcessGone(generation: Long, didCrash: Boolean)
    fun destroyed(generation: Long)
}

/** Android-free policy and event mapper used by [NativeGameWebViewClient]. */
internal class NativeGameWebViewClientDelegate(
    private val generation: Long,
    private val sink: NativeGameWebViewEventSink,
    private val acceptsGeneration: () -> Boolean,
    private val prepareRenderProcessGone: () -> Boolean,
    private val onRenderProcessGone: () -> Unit,
) {
    fun pageStarted(url: String) = emit { it.pageStarted(generation, url) }

    fun pageFinished(url: String) = emit { it.pageFinished(generation, url) }

    fun receivedError(isMainFrame: Boolean, errorCode: Int, description: String?) {
        if (isMainFrame) {
            emit { it.mainFrameError(generation, errorCode, sanitizeDescription(description)) }
        }
    }

    fun shouldOverrideUrlLoading(url: String?, isMainFrame: Boolean = true): Boolean {
        if (!acceptsGeneration()) {
            return true
        }
        val scheme = normalizedScheme(url)
        if (scheme == "http" || scheme == "https") {
            return false
        }
        if (isMainFrame) {
            runCatching { sink.navigationBlocked(generation, scheme) }
        }
        return true
    }

    fun renderProcessGone(didCrash: Boolean): Boolean {
        if (!acceptsGeneration()) {
            return true
        }
        if (!runCatching(prepareRenderProcessGone).getOrDefault(false)) {
            return true
        }
        runCatching { sink.renderProcessGone(generation, didCrash) }
        runCatching(onRenderProcessGone)
        return true
    }

    private fun emit(event: (NativeGameWebViewEventSink) -> Unit) {
        if (acceptsGeneration()) {
            runCatching { event(sink) }
        }
    }

    private fun normalizedScheme(url: String?): String {
        val match = SCHEME_PATTERN.find(url.orEmpty()) ?: return INVALID_SCHEME
        return match.groupValues[1].lowercase(Locale.ROOT).take(MAX_SCHEME_LENGTH)
    }

    private fun sanitizeDescription(description: String?): String = description.orEmpty().take(MAX_DESCRIPTION_LENGTH)

    private companion object {
        val SCHEME_PATTERN = Regex("^([A-Za-z][A-Za-z0-9+.-]*):")
        const val MAX_SCHEME_LENGTH = 32
        const val MAX_DESCRIPTION_LENGTH = 256
        const val INVALID_SCHEME = "invalid"
    }
}

internal class NativeGameWebViewClient(
    generation: Long,
    sink: NativeGameWebViewEventSink,
    acceptsGeneration: () -> Boolean,
    prepareRenderProcessGone: (Long) -> Boolean,
    onRenderProcessGone: (Long) -> Unit,
) : WebViewClient() {
    private val delegate = NativeGameWebViewClientDelegate(
        generation = generation,
        sink = sink,
        acceptsGeneration = acceptsGeneration,
        prepareRenderProcessGone = { prepareRenderProcessGone(generation) },
        onRenderProcessGone = { onRenderProcessGone(generation) },
    )

    override fun onPageStarted(view: WebView?, url: String?, favicon: Bitmap?) {
        delegate.pageStarted(url.orEmpty())
    }

    override fun onPageFinished(view: WebView?, url: String?) {
        delegate.pageFinished(url.orEmpty())
    }

    override fun onReceivedError(
        view: WebView?,
        request: WebResourceRequest?,
        error: WebResourceError?,
    ) {
        delegate.receivedError(
            isMainFrame = request?.isForMainFrame == true,
            errorCode = error?.errorCode ?: 0,
            description = error?.description?.toString(),
        )
    }

    @Deprecated("Deprecated in WebView")
    override fun onReceivedError(view: WebView?, errorCode: Int, description: String?, failingUrl: String?) {
        delegate.receivedError(isMainFrame = true, errorCode = errorCode, description = description)
    }

    @Deprecated("Deprecated in WebView")
    override fun shouldOverrideUrlLoading(view: WebView?, url: String?): Boolean =
        delegate.shouldOverrideUrlLoading(url)

    override fun shouldOverrideUrlLoading(view: WebView?, request: WebResourceRequest?): Boolean =
        delegate.shouldOverrideUrlLoading(
            url = request?.url?.toString(),
            isMainFrame = request?.isForMainFrame == true,
        )

    override fun onRenderProcessGone(view: WebView?, detail: RenderProcessGoneDetail?): Boolean =
        delegate.renderProcessGone(
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) detail?.didCrash() == true else false,
        )
}
