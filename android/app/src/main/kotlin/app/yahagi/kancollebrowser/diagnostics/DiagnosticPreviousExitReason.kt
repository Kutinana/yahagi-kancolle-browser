package app.yahagi.kancollebrowser.diagnostics

import android.app.ApplicationExitInfo

internal object DiagnosticPreviousExitReasonMapper {
    fun map(reason: Int?): String {
        return when (reason) {
            null -> "unavailable"
            ApplicationExitInfo.REASON_LOW_MEMORY -> "lowMemory"
            ApplicationExitInfo.REASON_CRASH,
            ApplicationExitInfo.REASON_CRASH_NATIVE,
            -> "crash"
            ApplicationExitInfo.REASON_ANR -> "anr"
            ApplicationExitInfo.REASON_USER_REQUESTED,
            ApplicationExitInfo.REASON_USER_STOPPED,
            -> "userRequested"
            ApplicationExitInfo.REASON_PACKAGE_UPDATED,
            ApplicationExitInfo.REASON_PACKAGE_STATE_CHANGE,
            -> "systemUpdate"
            else -> "unknown"
        }
    }
}

internal data class DiagnosticPreviousExitSnapshot(
    val reason: String,
    val status: Int,
    val importance: Int,
    val pssKb: Long,
    val rssKb: Long,
    val timestampMs: Long,
)
