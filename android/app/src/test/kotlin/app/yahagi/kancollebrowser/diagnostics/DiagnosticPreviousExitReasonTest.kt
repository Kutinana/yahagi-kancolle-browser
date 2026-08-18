package app.yahagi.kancollebrowser.diagnostics

import android.app.ApplicationExitInfo
import org.junit.Assert.assertEquals
import org.junit.Test

class DiagnosticPreviousExitReasonTest {
    @Test
    fun mapsFixedAndroidReasonsToApprovedDiagnosticValues() {
        assertEquals(
            "lowMemory",
            DiagnosticPreviousExitReasonMapper.map(ApplicationExitInfo.REASON_LOW_MEMORY),
        )
        assertEquals(
            "crash",
            DiagnosticPreviousExitReasonMapper.map(ApplicationExitInfo.REASON_CRASH),
        )
        assertEquals(
            "crash",
            DiagnosticPreviousExitReasonMapper.map(ApplicationExitInfo.REASON_CRASH_NATIVE),
        )
        assertEquals(
            "anr",
            DiagnosticPreviousExitReasonMapper.map(ApplicationExitInfo.REASON_ANR),
        )
        assertEquals(
            "userRequested",
            DiagnosticPreviousExitReasonMapper.map(ApplicationExitInfo.REASON_USER_REQUESTED),
        )
        assertEquals(
            "systemUpdate",
            DiagnosticPreviousExitReasonMapper.map(ApplicationExitInfo.REASON_PACKAGE_UPDATED),
        )
        assertEquals(
            "unknown",
            DiagnosticPreviousExitReasonMapper.map(ApplicationExitInfo.REASON_OTHER),
        )
        assertEquals(
            "unavailable",
            DiagnosticPreviousExitReasonMapper.map(null),
        )
    }
}
