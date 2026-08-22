package app.yahagi.kancollebrowser.nativewebview

import android.annotation.SuppressLint
import android.graphics.Color
import android.os.Build
import android.view.View
import android.webkit.CookieManager
import android.webkit.JavascriptInterface
import android.webkit.WebChromeClient
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.webkit.WebViewCompat
import androidx.webkit.WebViewFeature

internal enum class NativeGameWebViewConfigurationAction {
    JAVA_SCRIPT_ENABLED,
    DOM_STORAGE_ENABLED,
    DATABASE_ENABLED,
    MEDIA_PLAYBACK_WITHOUT_GESTURE,
    USER_AGENT_SET,
    BACKGROUND_BLACK,
    HARDWARE_LAYER,
    TAP_HIGHLIGHT_SCRIPT_SET,
    ACCEPT_COOKIE,
    ACCEPT_THIRD_PARTY_COOKIES,
    PRESENTATION_BRIDGE_SET,
    WEB_VIEW_CLIENT_SET,
    WEB_CHROME_CLIENT_SET,
}

/** Applies the deliberately narrow configuration used by the native game WebView. */
internal object NativeGameWebViewConfigurator {
    fun configure(
        webView: WebView,
        client: WebViewClient,
        onPresentationStateChanged: (Boolean) -> Unit = {},
    ) = configure(webView, client, onPresentationStateChanged) {}

    @SuppressLint("ObsoleteSdkInt", "SetJavaScriptEnabled")
    internal fun configure(
        webView: WebView,
        client: WebViewClient,
        onPresentationStateChanged: (Boolean) -> Unit,
        onApplied: (NativeGameWebViewConfigurationAction) -> Unit,
    ) {
        webView.settings.apply {
            javaScriptEnabled = true
            onApplied(NativeGameWebViewConfigurationAction.JAVA_SCRIPT_ENABLED)
            domStorageEnabled = true
            onApplied(NativeGameWebViewConfigurationAction.DOM_STORAGE_ENABLED)
            @Suppress("DEPRECATION")
            databaseEnabled = true
            onApplied(NativeGameWebViewConfigurationAction.DATABASE_ENABLED)
            mediaPlaybackRequiresUserGesture = false
            onApplied(NativeGameWebViewConfigurationAction.MEDIA_PLAYBACK_WITHOUT_GESTURE)
            userAgentString = NativeGameWebViewUserAgent.toDesktop(userAgentString)
            onApplied(NativeGameWebViewConfigurationAction.USER_AGENT_SET)
        }
        webView.setBackgroundColor(Color.BLACK)
        onApplied(NativeGameWebViewConfigurationAction.BACKGROUND_BLACK)
        webView.setLayerType(View.LAYER_TYPE_HARDWARE, null)
        onApplied(NativeGameWebViewConfigurationAction.HARDWARE_LAYER)

        if (WebViewFeature.isFeatureSupported(WebViewFeature.DOCUMENT_START_SCRIPT)) {
            WebViewCompat.addDocumentStartJavaScript(
                webView,
                NativeGameTouchFeedbackScript.source,
                NativeGameTouchFeedbackScript.allowedOriginRules,
            )
            onApplied(NativeGameWebViewConfigurationAction.TAP_HIGHLIGHT_SCRIPT_SET)
        }

        CookieManager.getInstance().apply {
            setAcceptCookie(true)
            onApplied(NativeGameWebViewConfigurationAction.ACCEPT_COOKIE)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                setAcceptThirdPartyCookies(webView, true)
                onApplied(NativeGameWebViewConfigurationAction.ACCEPT_THIRD_PARTY_COOKIES)
            }
        }
        webView.addJavascriptInterface(
            NativeGamePresentationBridge(onPresentationStateChanged),
            "YahagiPresentation",
        )
        onApplied(NativeGameWebViewConfigurationAction.PRESENTATION_BRIDGE_SET)
        webView.webViewClient = client
        onApplied(NativeGameWebViewConfigurationAction.WEB_VIEW_CLIENT_SET)
        webView.webChromeClient = WebChromeClient()
        onApplied(NativeGameWebViewConfigurationAction.WEB_CHROME_CLIENT_SET)
    }
}

/** Removes Chromium's native press highlight from the canvas without consuming touch events. */
internal object NativeGameTouchFeedbackScript {
    val allowedOriginRules: Set<String> = setOf("https://*.kancolle-server.com")

    val source: String =
        """
        (() => {
          'use strict';
          if (window.__yahagiTapHighlightDisabled) return;
          window.__yahagiTapHighlightDisabled = true;

          const apply = () => {
            const root = document.documentElement;
            if (!root) return false;
            root.style.setProperty(
              '-webkit-tap-highlight-color',
              'transparent',
              'important'
            );
            return true;
          };

          if (!apply()) {
            const observer = new MutationObserver(() => {
              if (!apply()) return;
              observer.disconnect();
            });
            observer.observe(document, {childList: true});
          }
        })();
        """.trimIndent()
}

internal class NativeGamePresentationBridge(
    private val onPresentationStateChanged: (Boolean) -> Unit,
) {
    private var lastPresentationState: Boolean? = null

    @JavascriptInterface
    fun postMessage(message: String) {
        val presentationState = when (message) {
            "game" -> true
            "web" -> false
            else -> return
        }
        if (presentationState == lastPresentationState) return
        lastPresentationState = presentationState
        onPresentationStateChanged(presentationState)
    }
}

internal object NativeGameWebViewUserAgent {
    private val chromePattern = Regex("\\bChrome/[0-9.]+")
    private val appleWebKitPattern = Regex("\\bAppleWebKit/[0-9.]+")
    private val safariPattern = Regex("\\bSafari/[0-9.]+")

    fun toDesktop(current: String): String {
        val chrome = chromePattern.find(current)?.value ?: return current
        val appleWebKit = appleWebKitPattern.find(current)?.value ?: return current
        val safari = safariPattern.find(current)?.value ?: return current
        return "Mozilla/5.0 (Windows NT 10.0; Win64; x64) " +
            "$appleWebKit (KHTML, like Gecko) $chrome $safari"
    }
}
