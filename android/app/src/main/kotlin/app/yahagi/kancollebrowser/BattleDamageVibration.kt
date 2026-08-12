package app.yahagi.kancollebrowser

import android.content.Context
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager

data class BattleDamageVibrationPattern(
    val timings: LongArray,
    val amplitudes: IntArray,
) {
    companion object {
        fun forSeverity(severity: String): BattleDamageVibrationPattern =
            when (severity) {
                "heavy" -> BattleDamageVibrationPattern(
                    timings = longArrayOf(0, 190, 90, 230),
                    amplitudes = intArrayOf(0, 255, 0, 255),
                )
                else -> BattleDamageVibrationPattern(
                    timings = longArrayOf(0, 140),
                    amplitudes = intArrayOf(0, 170),
                )
            }
    }
}

object BattleDamageVibrator {
    fun alert(context: Context, severity: String): Boolean {
        val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            context.getSystemService(VibratorManager::class.java)?.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            context.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
        } ?: return false
        if (!vibrator.hasVibrator()) return false

        val pattern = BattleDamageVibrationPattern.forSeverity(severity)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            vibrator.vibrate(
                VibrationEffect.createWaveform(
                    pattern.timings,
                    pattern.amplitudes,
                    -1,
                ),
            )
        } else {
            @Suppress("DEPRECATION")
            vibrator.vibrate(pattern.timings, -1)
        }
        return true
    }
}
