package app.yahagi.kancollebrowser.browser

import android.os.Build
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

enum class GameFrameRateMode(val wireName: String) {
    AUTO("auto"),
    STABLE_30("stable30"),
    HIGH_REFRESH("prefer60");

    val mainScriptTickerMode: GameMainScriptTickerMode?
        get() = when (this) {
            AUTO -> GameMainScriptTickerMode.CAPPED_60
            STABLE_30 -> null
            HIGH_REFRESH -> GameMainScriptTickerMode.HIGH_REFRESH
        }

    companion object {
        fun fromWireName(value: String?): GameFrameRateMode =
            entries.firstOrNull { it.wireName == value } ?: AUTO
    }
}

class GameFrameRateManager(
    private val host: Host,
    private val bridge: GameFrameRateBridge,
    private val systemConstraints: GameFrameRateSystemConstraintSource,
) : MethodChannel.MethodCallHandler {
    interface Host {
        fun onFrameRateModeChanged(mode: GameFrameRateMode)
    }

    @Volatile
    var mode: GameFrameRateMode = GameFrameRateMode.AUTO
        private set
    private var configured = false
    private var requestedTarget = GameFrameRateTarget.FPS_60

    init {
        systemConstraints.start(::onSystemStateChanged)
    }

    val mainScriptTickerMode: GameMainScriptTickerMode?
        get() = if (configured) mode.mainScriptTickerMode else null

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isSupported" -> result.success(
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && bridge.isSupported(),
            )
            "configure" -> {
                val requestedMode = GameFrameRateMode.fromWireName(
                    call.argument<String>("mode"),
                )
                try {
                    val initialTarget = requestedMode.initialTarget
                    bridge.configure(
                        GameFrameRateSystemPolicy.effectiveTarget(
                            requestedMode,
                            initialTarget,
                            systemConstraints.state,
                        ),
                    )
                    requestedTarget = initialTarget
                    mode = requestedMode
                    configured = true
                    host.onFrameRateModeChanged(mode)
                    result.success(null)
                } catch (error: GameFrameRateBridgeException) {
                    result.error(error.code, error.message, null)
                }
            }
            "applyTarget" -> {
                val target = GameFrameRateTarget.fromWireName(
                    call.argument<String>("target"),
                )
                if (target == null) {
                    result.error("invalid_frame_rate_target", "Unknown frame-rate target.", null)
                } else {
                    requestedTarget = target
                    bridge.apply(effectiveTarget())
                    result.success(null)
                }
            }
            "measuredFps" -> result.success(
                GameFrameRateSystemPolicy.runtimeSample(
                    mode,
                    systemConstraints.state,
                    bridge.measuredFps(),
                ),
            )
            else -> result.notImplemented()
        }
    }

    fun dispose() {
        systemConstraints.dispose()
        bridge.dispose()
        configured = false
        mode = GameFrameRateMode.AUTO
        requestedTarget = GameFrameRateTarget.FPS_60
    }

    private fun onSystemStateChanged(@Suppress("UNUSED_PARAMETER") state: GameFrameRateSystemState) {
        if (configured) bridge.apply(effectiveTarget())
    }

    private fun effectiveTarget(): GameFrameRateTarget =
        GameFrameRateSystemPolicy.effectiveTarget(
            mode,
            requestedTarget,
            systemConstraints.state,
        )
}

private val GameFrameRateMode.initialTarget: GameFrameRateTarget
    get() = when (this) {
        GameFrameRateMode.STABLE_30 -> GameFrameRateTarget.FPS_30
        GameFrameRateMode.AUTO -> GameFrameRateTarget.FPS_60
        GameFrameRateMode.HIGH_REFRESH -> GameFrameRateTarget.HIGH_REFRESH
    }
