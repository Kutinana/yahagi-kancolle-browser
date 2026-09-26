package app.yahagi.kancollebrowser.browser

import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.webviewflutter.WebViewFlutterAndroidExternalApi

/** Resolves the exact PlatformView that Flutter hit-tested, never a global view. */
internal class GameMouseWheelChannel(private val engine: FlutterEngine) : MethodChannel.MethodCallHandler {
    private val channel = MethodChannel(engine.dartExecutor.binaryMessenger, GameMouseWheelBridge.CHANNEL)

    init { channel.setMethodCallHandler(this) }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "scroll") {
            result.notImplemented()
            return
        }
        val id = call.argument<Number>("webViewId")?.toLong()
        val x = call.argument<Number>("x")?.toDouble()
        val y = call.argument<Number>("y")?.toDouble()
        val dx = call.argument<Number>("deltaX")?.toDouble()
        val dy = call.argument<Number>("deltaY")?.toDouble()
        @Suppress("DEPRECATION")
        val target = id?.let { WebViewFlutterAndroidExternalApi.getWebView(engine, it) }
        result.success(
            target != null && x != null && y != null && dx != null && dy != null &&
                GameMouseWheelBridge.forward(target, x, y, dx, dy),
        )
    }

    fun dispose() { channel.setMethodCallHandler(null) }
}
