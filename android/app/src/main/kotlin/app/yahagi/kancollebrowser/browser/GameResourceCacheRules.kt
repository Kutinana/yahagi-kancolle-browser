package app.yahagi.kancollebrowser.browser

import java.net.URI
import java.net.URLDecoder
import java.nio.charset.StandardCharsets
import java.util.Locale

object GameResourceCacheRules {
    // Keep the beta.2-sized cache metadata, plus headers needed when WebView
    // receives a cached response instead of the original network response.
    private val persistedResponseHeaderNames = setOf(
        "cache-control", "pragma", "expires",
        "content-security-policy", "content-security-policy-report-only",
        "access-control-allow-origin", "access-control-allow-credentials",
        "access-control-expose-headers", "cross-origin-resource-policy",
        "cross-origin-embedder-policy", "cross-origin-opener-policy",
        "x-content-type-options", "referrer-policy", "permissions-policy",
    )

    fun persistedResponseHeaders(headers: Map<String, String>): Map<String, String> =
        headers.filterKeys { it.lowercase(Locale.ROOT) in persistedResponseHeaderNames }

    private val forwardedRequestHeaderNames = setOf(
        "cookie", "user-agent", "accept", "accept-language", "origin", "referer",
        "x-requested-with",
    )

    fun forwardedRequestHeaders(headers: Map<String, String>): Map<String, String> =
        headers.filterKeys { it.lowercase(Locale.ROOT) in forwardedRequestHeaderNames }

    fun boundedForwardedRequestHeaders(headers: Map<String, String>): Map<String, String>? {
        val forwarded = forwardedRequestHeaders(headers)
        if (forwarded.size > 16) return null
        var totalChars = 0L
        forwarded.forEach { (name, value) ->
            if (name.length > 128 || value.length > 8_192) return null
            totalChars += name.length + value.length
            if (totalChars > 16_384) return null
        }
        return forwarded
    }

    private val officialHost = Regex("^w\\d+[a-z]\\.kancolle-server\\.com$", RegexOption.IGNORE_CASE)
    private val allowedPrefixes = listOf(
        "/kcs2/resources/",
        "/kcs2/img/",
        "/kcs2/js/",
        "/kcs2/css/",
        "/kcs/sound/",
        "/gadget_html5/",
        "/html/",
        "/kcscontents/",
    )
    private val allowedExactPaths = setOf(
        "/kcs2/version.json",
        "/kcs2/index.html",
        "/kcs2/hc.html",
    )
    private val allowedExtensions = setOf(
        "html", "htm", "js", "mjs", "css", "json", "svg",
        "png", "jpg", "jpeg", "gif", "webp",
        "woff", "woff2", "ttf", "mp3", "ogg", "wav", "mp4", "wasm",
    )

    fun shouldCache(url: String?, method: String?): Boolean {
        if (url == null || url.length > 2_048) return false
        if (method != null && !method.equals("GET", ignoreCase = true)) return false
        val uri = try {
            URI(url)
        } catch (_: Exception) {
            return false
        }
        return isOfficialStaticUri(uri)
    }

    internal fun isOfficialStaticUri(uri: URI): Boolean {
        if (!uri.scheme.equals("https", ignoreCase = true)) return false
        if (uri.port !in setOf(-1, 443)) return false
        if (uri.userInfo != null || !officialHost.matches(uri.host.orEmpty())) return false
        val path = uri.rawPath ?: return false
        if (path.startsWith("/kcsapi/", ignoreCase = true)) return false
        if (path.split('/').any(::isUnsafeSegment)) return false
        if (allowedPrefixes.none { path.startsWith(it, ignoreCase = true) } &&
            allowedExactPaths.none { path.equals(it, ignoreCase = true) }
        ) return false
        val extension = path.substringAfterLast('.', "").lowercase(Locale.ROOT)
        return extension in allowedExtensions
    }

    // These official binary asset paths are independent of the page's login identity.
    // Responses carrying Set-Cookie, Vary or private/no-store directives are still rejected.
    internal fun isShareableStaticUri(uri: URI): Boolean {
        if (!isOfficialStaticUri(uri)) return false
        val path = uri.rawPath.lowercase(Locale.ROOT)
        if (listOf("/kcs2/resources/", "/kcs2/img/", "/kcs/sound/", "/kcscontents/")
                .none(path::startsWith)) return false
        return path.substringAfterLast('.', "") in setOf(
            "png", "jpg", "jpeg", "gif", "webp", "woff", "woff2", "ttf",
            "mp3", "ogg", "wav", "mp4", "wasm",
        )
    }

    fun canInterceptWithoutCookieHeaders(url: String, method: String): Boolean =
        shouldCache(url, method)

    fun withFallbackCookie(headers: Map<String, String>, cookie: String?): Map<String, String> {
        if (cookie.isNullOrBlank() || headers.keys.any { it.equals("Cookie", ignoreCase = true) }) {
            return headers
        }
        return headers + ("Cookie" to cookie)
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
        val path = staticPath(url) ?: return false
        if (path == "/kcs2/version.json" || path == "/kcs2/index.html" ||
            path == "/kcs2/js/main.js"
        ) return true
        if (!path.startsWith("/gadget_html5/")) return false
        return path.endsWith(".html", ignoreCase = true) ||
            path.endsWith(".js", ignoreCase = true) ||
            path.endsWith(".css", ignoreCase = true)
    }

    fun requiresStrictValidation(url: String): Boolean {
        val path = staticPath(url) ?: return false
        return path == "/kcs2/version.json" || path == "/kcs2/index.html" ||
            path == "/kcs2/js/main.js"
    }

    private fun staticPath(url: String): String? =
        runCatching { URI(url) }.getOrNull()?.takeIf(::isOfficialStaticUri)?.rawPath

    fun mimeTypeFor(url: String): GadgetBypassRules.MimeInfo = GadgetBypassRules.mimeTypeFor(url)
}
