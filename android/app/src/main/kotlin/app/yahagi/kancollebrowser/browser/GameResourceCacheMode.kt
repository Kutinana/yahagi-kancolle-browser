package app.yahagi.kancollebrowser.browser

enum class GameResourceCacheMode(val wireName: String) {
    NONE("none"),
    LIGHT("light"),
    FULL("full"),
    ;

    val readsCache: Boolean get() = this != NONE
    val writesCache: Boolean get() = this != NONE

    companion object {
        fun fromWireName(value: String?): GameResourceCacheMode =
            entries.firstOrNull { it.wireName == value } ?: NONE
    }
}
