package app.yahagi.kancollebrowser.diagnostics

internal object DiagnosticExportFileName {
    private val allowed = Regex(
        "^Yahagi-Diagnostics-\\d{8}-\\d{6}\\.json$",
    )

    fun available(baseName: String, existingNames: Set<String>): String {
        require(allowed.matches(baseName))
        if (baseName !in existingNames) return baseName

        val stem = baseName.removeSuffix(".json")
        var suffix = 2
        while (true) {
            val candidate = "$stem-$suffix.json"
            if (candidate !in existingNames) return candidate
            suffix += 1
        }
    }
}
