package app.yahagi.kancollebrowser.browser

import java.net.URI

@JvmInline
value class GameResourceCacheKey(val value: String) {
    companion object {
        fun from(url: String): GameResourceCacheKey? {
            val uri = try {
                URI(url)
            } catch (_: Exception) {
                return null
            }
            if (!GameResourceCacheRules.isOfficialStaticUri(uri)) return null
            val path = uri.rawPath ?: return null
            val query = uri.rawQuery?.let { "?$it" }.orEmpty()
            return GameResourceCacheKey(path + query)
        }
    }
}
