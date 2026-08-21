package app.yahagi.kancollebrowser.browser

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

internal class GameFrameReloadManager(
    private val bridge: GameFrameReloadBridgePort,
) : MethodChannel.MethodCallHandler {
    fun configure() = bridge.configure()

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "configure" -> {
                configure()
                result.success(null)
            }
            "reload" -> {
                if (!bridge.isSupported()) {
                    result.success("unsupported")
                } else {
                    bridge.reload(result::success)
                }
            }
            else -> result.notImplemented()
        }
    }

    fun dispose() = bridge.dispose()
}
