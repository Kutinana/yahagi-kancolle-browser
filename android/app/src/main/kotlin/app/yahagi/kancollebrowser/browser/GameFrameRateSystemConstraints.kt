package app.yahagi.kancollebrowser.browser

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.PowerManager
import androidx.core.content.ContextCompat

private const val THERMAL_STATUS_NONE_COMPAT = 0
private const val THERMAL_STATUS_MODERATE_COMPAT = 2

data class GameFrameRateSystemState(
    val powerSaveEnabled: Boolean = false,
    val thermalStatus: Int = THERMAL_STATUS_NONE_COMPAT,
) {
    val shouldConservePower: Boolean
        get() = powerSaveEnabled ||
            thermalStatus >= THERMAL_STATUS_MODERATE_COMPAT
}

object GameFrameRateSystemPolicy {
    fun runtimeSample(
        mode: GameFrameRateMode,
        state: GameFrameRateSystemState,
        measuredFps: Double?,
    ): Double? {
        if (mode == GameFrameRateMode.AUTO && state.shouldConservePower) {
            return null
        }
        return measuredFps
    }

    fun effectiveTarget(
        mode: GameFrameRateMode,
        requestedTarget: GameFrameRateTarget,
        state: GameFrameRateSystemState,
    ): GameFrameRateTarget {
        val safeRequestedTarget = if (
            mode == GameFrameRateMode.AUTO &&
            requestedTarget == GameFrameRateTarget.HIGH_REFRESH
        ) {
            GameFrameRateTarget.FPS_60
        } else {
            requestedTarget
        }
        return if (mode == GameFrameRateMode.AUTO && state.shouldConservePower) {
            GameFrameRateTarget.FPS_30
        } else {
            safeRequestedTarget
        }
    }
}

interface GameFrameRateSystemConstraintSource {
    val state: GameFrameRateSystemState

    fun start(onChanged: (GameFrameRateSystemState) -> Unit)

    fun dispose()
}

class AndroidGameFrameRateSystemConstraints(context: Context) :
    GameFrameRateSystemConstraintSource {
    private val applicationContext = context.applicationContext
    private val powerManager =
        applicationContext.getSystemService(Context.POWER_SERVICE) as PowerManager
    private var onChanged: ((GameFrameRateSystemState) -> Unit)? = null
    private var receiverRegistered = false
    private var thermalListener: PowerManager.OnThermalStatusChangedListener? = null

    override var state = GameFrameRateSystemState()
        private set

    private val powerSaveReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == PowerManager.ACTION_POWER_SAVE_MODE_CHANGED) {
                updateState(state.copy(powerSaveEnabled = powerManager.isPowerSaveMode))
            }
        }
    }

    override fun start(onChanged: (GameFrameRateSystemState) -> Unit) {
        if (this.onChanged != null) return
        this.onChanged = onChanged
        state = GameFrameRateSystemState(
            powerSaveEnabled = powerManager.isPowerSaveMode,
            thermalStatus = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                powerManager.currentThermalStatus
            } else {
                THERMAL_STATUS_NONE_COMPAT
            },
        )
        registerPowerSaveReceiver()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val listener = PowerManager.OnThermalStatusChangedListener { status ->
                updateState(state.copy(thermalStatus = status))
            }
            thermalListener = listener
            powerManager.addThermalStatusListener(
                ContextCompat.getMainExecutor(applicationContext),
                listener,
            )
        }
        onChanged(state)
    }

    override fun dispose() {
        if (receiverRegistered) {
            try {
                applicationContext.unregisterReceiver(powerSaveReceiver)
            } catch (_: IllegalArgumentException) {
                // The process may already have unregistered receivers during teardown.
            }
            receiverRegistered = false
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            thermalListener?.let(powerManager::removeThermalStatusListener)
        }
        thermalListener = null
        onChanged = null
    }

    private fun registerPowerSaveReceiver() {
        val filter = IntentFilter(PowerManager.ACTION_POWER_SAVE_MODE_CHANGED)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            applicationContext.registerReceiver(
                powerSaveReceiver,
                filter,
                Context.RECEIVER_NOT_EXPORTED,
            )
        } else {
            @Suppress("DEPRECATION")
            applicationContext.registerReceiver(powerSaveReceiver, filter)
        }
        receiverRegistered = true
    }

    private fun updateState(next: GameFrameRateSystemState) {
        if (state == next) return
        state = next
        onChanged?.invoke(next)
    }
}
