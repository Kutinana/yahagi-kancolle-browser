package app.yahagi.kancollebrowser.diagnostics

import org.junit.Assert.assertEquals
import org.junit.Test

class DiagnosticExportFileNameTest {
    @Test
    fun `keeps the generated name when it does not exist`() {
        assertEquals(
            "Yahagi-Diagnostics-20260813-091445.json",
            DiagnosticExportFileName.available(
                "Yahagi-Diagnostics-20260813-091445.json",
                emptySet(),
            ),
        )
    }

    @Test
    fun `adds the first available numeric suffix without overwriting`() {
        assertEquals(
            "Yahagi-Diagnostics-20260813-091445-4.json",
            DiagnosticExportFileName.available(
                "Yahagi-Diagnostics-20260813-091445.json",
                setOf(
                    "Yahagi-Diagnostics-20260813-091445.json",
                    "Yahagi-Diagnostics-20260813-091445-2.json",
                    "Yahagi-Diagnostics-20260813-091445-3.json",
                ),
            ),
        )
    }
}
