package app.yahagi.kancollebrowser.diagnostics

import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test

class DiagnosticDirectoryPickerUiTest {
    @Test
    fun `shows exit controls before opening picker and restores immersive mode on finish`() {
        val events = mutableListOf<String>()
        val ui = DiagnosticDirectoryPickerUi(
            systemBars = object : DiagnosticPickerSystemBars {
                override fun showExitControls() {
                    events += "show"
                }

                override fun restoreImmersiveMode() {
                    events += "restore"
                }
            },
        )

        ui.open { events += "open" }
        ui.finish()

        assertEquals(listOf("show", "open", "restore"), events)
    }

    @Test
    fun `restores immersive mode when picker cannot be opened`() {
        val events = mutableListOf<String>()
        val ui = DiagnosticDirectoryPickerUi(
            systemBars = object : DiagnosticPickerSystemBars {
                override fun showExitControls() {
                    events += "show"
                }

                override fun restoreImmersiveMode() {
                    events += "restore"
                }
            },
        )

        assertThrows(IllegalStateException::class.java) {
            ui.open {
                events += "open"
                error("picker unavailable")
            }
        }

        assertEquals(listOf("show", "open", "restore"), events)
    }
}
