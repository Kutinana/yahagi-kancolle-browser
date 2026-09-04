package app.yahagi.kancollebrowser.browser

enum class GameResourceCacheMode(val wireName: String) {
    TEMPORARY("temporary"),
    NONE("none"),
    LIGHT("light"),
    FULL("full"),
    ;

    val readsCache: Boolean get() = this != NONE
    val writesCache: Boolean get() = this != NONE

    companion object {
        fun fromWireName(value: String?): GameResourceCacheMode = when (value) {
            "full", "light" -> FULL
            "temporary", "none", null -> TEMPORARY
            else -> TEMPORARY
        }
    }
}
