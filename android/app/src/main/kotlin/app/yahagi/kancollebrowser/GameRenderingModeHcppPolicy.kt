package app.yahagi.kancollebrowser

object GameRenderingModeHcppPolicy {
    const val PREFERENCES_NAME = "FlutterSharedPreferences"
    const val RENDERING_MODE_KEY = "flutter.game.renderingMode"

    @Suppress("UNUSED_PARAMETER")
    fun shouldEnable(storedMode: String?): Boolean = false
}
