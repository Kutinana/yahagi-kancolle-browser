package app.yahagi.kancollebrowser.browser

import android.app.Activity
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.View
import android.view.ViewGroup
import android.webkit.WebView
import androidx.webkit.JavaScriptReplyProxy
import androidx.webkit.ScriptHandler
import androidx.webkit.WebMessageCompat
import androidx.webkit.WebViewCompat
import androidx.webkit.WebViewFeature
import app.yahagi.kancollebrowser.capture.CaptureOriginPolicy
import java.util.Collections
import java.util.IdentityHashMap
import java.util.UUID
import org.json.JSONObject

internal interface GameFrameReloadBridgePort {
    fun isSupported(): Boolean

    fun configure()

    fun reload(onComplete: (String) -> Unit)

    fun dispose()
}

internal object GameFrameReloadBridgeScript {
    const val objectName = "YahagiGameFrameReload"

    val source: String =
        """
        (() => {
          'use strict';
          if (window.__yahagiGameFrameReloadInstalled) return;
          const bridge = window.YahagiGameFrameReload;
          if (!bridge || typeof bridge.postMessage !== 'function') return;
          window.__yahagiGameFrameReloadInstalled = true;

          const post = (payload) => bridge.postMessage(JSON.stringify(payload));
          let lastAvailability;
          const reportTarget = () => {
            const available = document.getElementById('htmlWrap') !== null;
            if (available === lastAvailability) return;
            lastAvailability = available;
            post({kind: 'target', available: available});
          };
          const startObserving = () => {
            reportTarget();
            const root = document.documentElement;
            if (!root) return;
            const observer = new MutationObserver(reportTarget);
            observer.observe(root, {childList: true, subtree: true});
          };

          bridge.onmessage = (event) => {
            let data;
            try {
              data = typeof event.data === 'string'
                ? JSON.parse(event.data)
                : event.data;
            } catch (_) {
              return;
            }
            if (!data || data.kind !== 'reload' || typeof data.requestId !== 'string') {
              return;
            }
            const game = document.getElementById('htmlWrap');
            if (!game) return;

            let result = 'reloaded';
            try {
              game.contentWindow.location.reload();
            } catch (_) {
              const source = game.getAttribute('src');
              if (!source) {
                result = 'blocked';
              } else {
                game.setAttribute('src', source);
              }
            }
            post({kind: 'result', requestId: data.requestId, result: result});
          };

          if (document.readyState === 'loading') {
            document.addEventListener('DOMContentLoaded', startObserving, {once: true});
          } else {
            startObserving();
          }
        })();
        """.trimIndent()
}

internal class GameFrameReloadRequestCoordinator(
    private val requestIdFactory: () -> String = { UUID.randomUUID().toString() },
) {
    private var pending: PendingRequest? = null

    val hasPending: Boolean
        get() = pending != null

    fun start(onComplete: (String) -> Unit): String {
        val requestId = requestIdFactory()
        pending = PendingRequest(requestId, onComplete)
        return requestId
    }

    fun complete(requestId: String, result: String): Boolean {
        val active = pending ?: return false
        if (active.requestId != requestId) return false
        pending = null
        active.onComplete(result)
        return true
    }

    fun cancel(result: String): Boolean {
        val active = pending ?: return false
        pending = null
        active.onComplete(result)
        return true
    }

    private data class PendingRequest(
        val requestId: String,
        val onComplete: (String) -> Unit,
    )
}

internal class AndroidGameFrameReloadBridge(
    private val activity: Activity,
    private val originPolicy: CaptureOriginPolicy = CaptureOriginPolicy(),
    private val mainHandler: Handler = Handler(Looper.getMainLooper()),
) : GameFrameReloadBridgePort {
    private companion object {
        const val TAG = "GameFrameReload"
        const val RELOAD_TIMEOUT_MILLIS = 5_000L
    }

    private var attachedWebView: WebView? = null
    private var scriptHandler: ScriptHandler? = null
    private var listenerInstalled = false
    private val targetFrames: MutableSet<JavaScriptReplyProxy> =
        Collections.newSetFromMap(IdentityHashMap())
    private val coordinator = GameFrameReloadRequestCoordinator()
    private var timeoutAction: Runnable? = null

    override fun isSupported(): Boolean =
        WebViewFeature.isFeatureSupported(WebViewFeature.DOCUMENT_START_SCRIPT) &&
            WebViewFeature.isFeatureSupported(WebViewFeature.WEB_MESSAGE_LISTENER)

    override fun configure() {
        if (!isSupported()) {
            disable()
            return
        }

        val webViews = mutableListOf<WebView>()
        collectWebViews(activity.window.decorView, webViews)
        if (webViews.size != 1) {
            disable()
            Log.w(TAG, "configure expected one WebView, found ${webViews.size}")
            return
        }

        val webView = webViews.single()
        if (attachedWebView === webView && listenerInstalled && scriptHandler != null) {
            return
        }

        disable()
        try {
            WebViewCompat.addWebMessageListener(
                webView,
                GameFrameReloadBridgeScript.objectName,
                originPolicy.allowedOriginRules,
                ::onPostMessage,
            )
            listenerInstalled = true
            scriptHandler = WebViewCompat.addDocumentStartJavaScript(
                webView,
                GameFrameReloadBridgeScript.source,
                originPolicy.allowedOriginRules,
            )
            attachedWebView = webView
            Log.i(TAG, "configured frame-level reload bridge")
        } catch (error: RuntimeException) {
            disableWebView(webView)
            attachedWebView = null
            Log.w(TAG, "unable to configure frame-level reload bridge", error)
        }
    }

    override fun reload(onComplete: (String) -> Unit) {
        if (!isSupported()) {
            onComplete("unsupported")
            return
        }
        if (attachedWebView == null || !listenerInstalled || scriptHandler == null) {
            onComplete("blocked")
            return
        }
        if (coordinator.hasPending) {
            onComplete("blocked")
            return
        }

        val candidates = targetFrames.toList()
        if (candidates.isEmpty()) {
            onComplete("html_wrap_not_found")
            return
        }

        lateinit var requestId: String
        requestId = coordinator.start { result ->
            cancelTimeout()
            Log.i(TAG, "request=$requestId result=$result")
            onComplete(result)
        }
        val payload = JSONObject()
            .put("kind", "reload")
            .put("requestId", requestId)
            .toString()

        val timeout = Runnable { coordinator.cancel("blocked") }
        timeoutAction = timeout
        mainHandler.postDelayed(timeout, RELOAD_TIMEOUT_MILLIS)

        var delivered = false
        for (candidate in candidates) {
            try {
                candidate.postMessage(payload)
                delivered = true
            } catch (_: RuntimeException) {
                targetFrames.remove(candidate)
            }
        }
        if (!delivered) {
            coordinator.cancel("html_wrap_not_found")
        }
    }

    override fun dispose() = disable()

    @Suppress("UNUSED_PARAMETER")
    private fun onPostMessage(
        webView: WebView,
        message: WebMessageCompat,
        sourceOrigin: android.net.Uri,
        isMainFrame: Boolean,
        replyProxy: JavaScriptReplyProxy,
    ) {
        if (!originPolicy.isAllowed(sourceOrigin.toString())) return
        val payload = try {
            JSONObject(message.data ?: return)
        } catch (_: Exception) {
            return
        }

        when (payload.optString("kind")) {
            "target" -> {
                if (payload.optBoolean("available", false)) {
                    targetFrames.add(replyProxy)
                } else {
                    targetFrames.remove(replyProxy)
                }
            }
            "result" -> {
                val requestId = payload.optString("requestId")
                val result = payload.optString("result")
                if (requestId.isEmpty() || result !in setOf("reloaded", "blocked")) return
                coordinator.complete(requestId, result)
            }
        }
    }

    private fun disable() {
        cancelTimeout()
        coordinator.cancel("blocked")
        scriptHandler?.remove()
        scriptHandler = null
        attachedWebView?.let(::disableWebView)
        attachedWebView = null
        targetFrames.clear()
    }

    private fun cancelTimeout() {
        timeoutAction?.let(mainHandler::removeCallbacks)
        timeoutAction = null
    }

    private fun disableWebView(webView: WebView) {
        if (listenerInstalled) {
            try {
                WebViewCompat.removeWebMessageListener(
                    webView,
                    GameFrameReloadBridgeScript.objectName,
                )
            } catch (_: RuntimeException) {
                // The old JavaScript context may already have been destroyed.
            }
        }
        listenerInstalled = false
    }

    private fun collectWebViews(view: View, results: MutableList<WebView>) {
        if (view is WebView) results.add(view)
        if (view is ViewGroup) {
            for (index in 0 until view.childCount) {
                collectWebViews(view.getChildAt(index), results)
            }
        }
    }
}
