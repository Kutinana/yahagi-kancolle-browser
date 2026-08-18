package app.yahagi.kancollebrowser.diagnostics

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Test

class DiagnosticDeviceSnapshotTest {
    @Test
    fun snapshotContainsOnlyApprovedCompatibilityFields() {
        val values = DiagnosticDeviceSnapshot(
            manufacturer = "Google",
            model = "Pixel",
            androidSdk = 35,
            androidRelease = "15",
            supportedAbi = "arm64-v8a",
            memoryClassMb = 8192,
            screenWidthPx = 2400,
            screenHeightPx = 1080,
            webViewVersion = "139",
            previousExitReason = "unavailable",
            previousExitStatus = 0,
            previousExitImportance = 0,
            previousExitPssKb = 0L,
            previousExitRssKb = 0L,
            previousExitTimestampMs = 0L,
        ).toMap()

        assertEquals(
            setOf(
                "manufacturer",
                "model",
                "androidSdk",
                "androidRelease",
                "supportedAbi",
                "memoryClassMb",
                "screenWidthPx",
                "screenHeightPx",
                "webViewVersion",
                "previousExitReason",
                "previousExitStatus",
                "previousExitImportance",
                "previousExitPssKb",
                "previousExitRssKb",
                "previousExitTimestampMs",
            ),
            values.keys,
        )
        assertFalse(values.keys.any { it in setOf("androidId", "serial", "imei", "macAddress") })
    }
}
