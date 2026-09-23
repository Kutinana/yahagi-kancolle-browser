package app.yahagi.kancollebrowser.browser

import java.net.URI
import java.security.MessageDigest
import java.util.Locale

@JvmInline
value class GameResourceCacheKey(val value: String) {
    companion object {
        fun from(url: String, requestHeaders: Map<String, String> = emptyMap()): GameResourceCacheKey? {
            val uri = try {
                URI(url)
            } catch (_: Exception) {
                return null
            }
            if (!GameResourceCacheRules.isOfficialStaticUri(uri)) return null
            val path = uri.rawPath ?: return null
            val query = uri.rawQuery?.let { "?$it" }.orEmpty()
            val base = "https://${uri.host.lowercase(Locale.ROOT)}$path$query"
            if (GameResourceCacheRules.isShareableStaticUri(uri)) return GameResourceCacheKey(base)
            val variant = GameResourceCacheRules.forwardedRequestHeaders(requestHeaders).entries
                .sortedBy { it.key.lowercase(Locale.ROOT) }
                .joinToString("\n") { "${it.key.lowercase(Locale.ROOT)}:${it.value}" }
            if (variant.isEmpty()) return GameResourceCacheKey(base)
            val digest = MessageDigest.getInstance("SHA-256")
                .digest(variant.toByteArray(Charsets.UTF_8))
                .joinToString("") { "%02x".format(it) }
            return GameResourceCacheKey("$base|headers=$digest")
        }
    }
}
