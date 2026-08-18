package app.yahagi.kancollebrowser.diagnostics

internal data class DiagnosticDeviceSnapshot(
    val manufacturer: String,
    val model: String,
    val androidSdk: Int,
    val androidRelease: String,
    val supportedAbi: String,
    val memoryClassMb: Int,
    val screenWidthPx: Int,
    val screenHeightPx: Int,
    val webViewVersion: String,
    val previousExitReason: String,
    val previousExitStatus: Int,
    val previousExitImportance: Int,
    val previousExitPssKb: Long,
    val previousExitRssKb: Long,
    val previousExitTimestampMs: Long,
) {
    fun toMap(): Map<String, Any> = linkedMapOf(
        "manufacturer" to manufacturer,
        "model" to model,
        "androidSdk" to androidSdk,
        "androidRelease" to androidRelease,
        "supportedAbi" to supportedAbi,
        "memoryClassMb" to memoryClassMb,
        "screenWidthPx" to screenWidthPx,
        "screenHeightPx" to screenHeightPx,
        "webViewVersion" to webViewVersion,
        "previousExitReason" to previousExitReason,
        "previousExitStatus" to previousExitStatus,
        "previousExitImportance" to previousExitImportance,
        "previousExitPssKb" to previousExitPssKb,
        "previousExitRssKb" to previousExitRssKb,
        "previousExitTimestampMs" to previousExitTimestampMs,
    )
}
