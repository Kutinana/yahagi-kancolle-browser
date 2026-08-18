package app.yahagi.kancollebrowser.nativewebview

import android.annotation.SuppressLint
import android.graphics.Color
import android.os.Build
import android.view.View
import android.webkit.CookieManager
import android.webkit.WebChromeClient
import android.webkit.WebView
import android.webkit.WebViewClient

internal enum class NativeGameWebViewConfigurationAction {
    JAVA_SCRIPT_ENABLED,
    DOM_STORAGE_ENABLED,
    DATABASE_ENABLED,
    MEDIA_PLAYBACK_WITHOUT_GESTURE,
    BACKGROUND_BLACK,
    HARDWARE_LAYER,
    ACCEPT_COOKIE,
    ACCEPT_THIRD_PARTY_COOKIES,
    WEB_VIEW_CLIENT_SET,
    WEB_CHROME_CLIENT_SET,
}

/** Applies the deliberately narrow configuration used by the native game WebView. */
internal object NativeGameWebViewConfigurator {
    fun configure(webView: WebView, client: WebViewClient) = configure(webView, client) {}

    @SuppressLint("ObsoleteSdkInt", "SetJavaScriptEnabled")
    internal fun configure(
        webView: WebView,
        client: WebViewClient,
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
        }
        webView.setBackgroundColor(Color.BLACK)
        onApplied(NativeGameWebViewConfigurationAction.BACKGROUND_BLACK)
        webView.setLayerType(View.LAYER_TYPE_HARDWARE, null)
        onApplied(NativeGameWebViewConfigurationAction.HARDWARE_LAYER)

        CookieManager.getInstance().apply {
            setAcceptCookie(true)
            onApplied(NativeGameWebViewConfigurationAction.ACCEPT_COOKIE)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                setAcceptThirdPartyCookies(webView, true)
                onApplied(NativeGameWebViewConfigurationAction.ACCEPT_THIRD_PARTY_COOKIES)
            }
        }
        webView.webViewClient = client
        onApplied(NativeGameWebViewConfigurationAction.WEB_VIEW_CLIENT_SET)
        webView.webChromeClient = WebChromeClient()
        onApplied(NativeGameWebViewConfigurationAction.WEB_CHROME_CLIENT_SET)
    }
}
