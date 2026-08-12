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
    )
}
