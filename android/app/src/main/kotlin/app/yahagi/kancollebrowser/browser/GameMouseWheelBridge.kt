package app.yahagi.kancollebrowser.browser

import android.content.Context
import android.view.InputDevice
import android.view.KeyEvent
import android.view.MotionEvent
import android.webkit.WebView
import androidx.webkit.JavaScriptReplyProxy
import androidx.webkit.WebViewCompat
import androidx.webkit.WebViewFeature
import java.lang.ref.WeakReference
import app.yahagi.kancollebrowser.R
import org.json.JSONObject

/** One bridge per WebView, shared by the native and Flutter input paths. */
internal class GameMouseWheelBridge private constructor(webView: WebView) {
    private val view = WeakReference(webView)
    private val preferences = webView.context.getSharedPreferences(
        "FlutterSharedPreferences", Context.MODE_PRIVATE,
    )
    private var target: JavaScriptReplyProxy? = null
    private var token: String? = null

    companion object {
        const val CHANNEL = "app.yahagi.kancollebrowser/game_mouse_wheel"
        private const val PREFERENCE = "flutter.game.mouseWheelCompatibility"

        fun attach(webView: WebView) {
            if (webView.getTag(R.id.game_mouse_wheel_bridge) != null ||
                !WebViewFeature.isFeatureSupported(WebViewFeature.DOCUMENT_START_SCRIPT) ||
                !WebViewFeature.isFeatureSupported(WebViewFeature.WEB_MESSAGE_LISTENER)) return
            val bridge = GameMouseWheelBridge(webView)
            try {
                WebViewCompat.addWebMessageListener(
                    webView, GameMouseWheelScript.objectName, GameMouseWheelScript.origins,
                ) { _, message, origin, _, reply ->
                    if (origin.scheme != "https" ||
                        origin.host?.endsWith(".kancolle-server.com") != true) return@addWebMessageListener
                    val payload = runCatching { JSONObject(message.data ?: "") }.getOrNull()
                        ?: return@addWebMessageListener
                    val frameToken = payload.optString("token").takeIf { it.length in 1..100 }
                        ?: return@addWebMessageListener
                    if (payload.optBoolean("available")) {
                        bridge.token = frameToken
                        bridge.target = reply
                    } else if (bridge.token == frameToken) {
                        bridge.token = null
                        bridge.target = null
                    }
                }
                WebViewCompat.addDocumentStartJavaScript(
                    webView, GameMouseWheelScript.source, GameMouseWheelScript.origins,
                )
                webView.setOnGenericMotionListener { _, event -> bridge.onMotion(event) }
                webView.setTag(R.id.game_mouse_wheel_bridge, bridge)
            } catch (_: RuntimeException) {
                // Optional input compatibility must not prevent game startup.
                runCatching {
                    WebViewCompat.removeWebMessageListener(webView, GameMouseWheelScript.objectName)
                }
            }
        }

        fun forward(webView: WebView, x: Double, y: Double, dx: Double, dy: Double): Boolean =
            (webView.getTag(R.id.game_mouse_wheel_bridge) as? GameMouseWheelBridge)
                ?.send(x, y, dx, dy) ?: false
    }

    private fun onMotion(event: MotionEvent): Boolean {
        if (event.actionMasked != MotionEvent.ACTION_SCROLL ||
            !event.isFromSource(InputDevice.SOURCE_MOUSE) ||
            event.metaState and KeyEvent.META_CTRL_ON != 0) return false
        val webView = view.get() ?: return false
        if (webView.width <= 0 || webView.height <= 0) return false
        // Android's positive vertical axis points up; DOM deltaY points down.
        return send(
            event.x.toDouble() / webView.width,
            event.y.toDouble() / webView.height,
            -event.getAxisValue(MotionEvent.AXIS_HSCROLL).toDouble() * 120.0,
            -event.getAxisValue(MotionEvent.AXIS_VSCROLL).toDouble() * 120.0,
        )
    }

    private fun send(x: Double, y: Double, dx: Double, dy: Double): Boolean {
        if (!preferences.getBoolean(PREFERENCE, false) ||
            !GameMouseWheelPolicy.accepts(x, y, dx, dy)) return false
        val webView = view.get() ?: return false
        if (!webView.isAttachedToWindow || !webView.isShown ||
            !webView.hasWindowFocus() || webView.width <= 0 || webView.height <= 0) return false
        val reply = target ?: return false
        val frameToken = token ?: return false
        return try {
            reply.postMessage(JSONObject().put("kind", "wheel").put("token", frameToken)
                .put("x", x).put("y", y).put("deltaX", dx).put("deltaY", dy).toString())
            true // Do not also let WebView dispatch the same native wheel.
        } catch (_: RuntimeException) {
            target = null
            token = null
            false
        }
    }
}

internal object GameMouseWheelPolicy {
    fun accepts(x: Double, y: Double, dx: Double, dy: Double): Boolean =
        x.isFinite() && y.isFinite() && dx.isFinite() && dy.isFinite() &&
            x >= 0 && x < 1 && y >= 0 && y < 1 && dy != 0.0
}
