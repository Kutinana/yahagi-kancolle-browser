package app.yahagi.kancollebrowser.browser

import java.net.URI
import java.net.URLDecoder
import java.nio.charset.StandardCharsets
import java.util.Locale

object GameResourceCacheRules {
    private val officialHost = Regex("^w\\d+[gk]\\.kancolle-server\\.com$", RegexOption.IGNORE_CASE)
    private val allowedPrefixes = listOf(
        "/kcs2/resources/",
        "/kcs2/img/",
        "/kcs/sound/",
        "/gadget_html5/",
    )
    private val allowedExtensions = setOf(
        "html", "htm", "js", "mjs", "css", "json", "svg",
        "png", "jpg", "jpeg", "gif", "webp",
        "woff", "woff2", "ttf", "mp3", "ogg", "wav", "mp4", "wasm",
    )

    fun shouldCache(url: String?, method: String?): Boolean {
        if (url == null) return false
        if (method != null && !method.equals("GET", ignoreCase = true)) return false
        val uri = try {
            URI(url)
        } catch (_: Exception) {
            return false
        }
        return isOfficialStaticUri(uri)
    }

    internal fun isOfficialStaticUri(uri: URI): Boolean {
        if (uri.scheme?.lowercase(Locale.ROOT) !in setOf("http", "https")) return false
        if (uri.userInfo != null || !officialHost.matches(uri.host.orEmpty())) return false
        val path = uri.rawPath ?: return false
        if (path.startsWith("/kcsapi/", ignoreCase = true)) return false
        if (path.split('/').any(::isUnsafeSegment)) return false
        if (allowedPrefixes.none { path.startsWith(it, ignoreCase = true) }) return false
        val extension = path.substringAfterLast('.', "").lowercase(Locale.ROOT)
        return extension in allowedExtensions
    }

    private fun isUnsafeSegment(raw: String): Boolean {
        var decoded = raw
        repeat(2) {
            decoded = try {
                URLDecoder.decode(decoded, StandardCharsets.UTF_8.name())
            } catch (_: Exception) {
                return true
            }
        }
        return decoded == "." || decoded == ".." || decoded.contains('/') || decoded.contains('\\')
    }

    fun isAlwaysValidated(url: String): Boolean {
        val key = GameResourceCacheKey.from(url)?.value?.substringBefore('?') ?: return false
        if (!key.startsWith("/gadget_html5/")) return false
        return key.endsWith(".html", ignoreCase = true) ||
            key.endsWith(".js", ignoreCase = true) ||
            key.endsWith(".css", ignoreCase = true)
    }

    fun mimeTypeFor(url: String): GadgetBypassRules.MimeInfo = GadgetBypassRules.mimeTypeFor(url)
}
