package app.yahagi.kancollebrowser.diagnostics

internal interface DiagnosticPickerSystemBars {
    fun showExitControls()

    fun restoreImmersiveMode()
}

internal class DiagnosticDirectoryPickerUi(
    private val systemBars: DiagnosticPickerSystemBars,
) {
    fun open(launcher: () -> Unit) {
        systemBars.showExitControls()
        try {
            launcher()
        } catch (error: RuntimeException) {
            systemBars.restoreImmersiveMode()
            throw error
        }
    }

    fun finish() {
        systemBars.restoreImmersiveMode()
    }
}
