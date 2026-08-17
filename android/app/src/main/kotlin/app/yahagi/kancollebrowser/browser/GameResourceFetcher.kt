package app.yahagi.kancollebrowser.browser

import java.io.ByteArrayOutputStream
import java.net.HttpURLConnection
import java.net.Proxy
import java.net.URI
import java.net.URL

data class GameResourceFetchResult(
    val statusCode: Int,
    val reasonPhrase: String,
    val headers: Map<String, String>,
    val bytes: ByteArray,
)

fun interface GameResourceFetcher {
    fun fetch(
        url: String,
        requestHeaders: Map<String, String>,
        cached: GameResourceCacheEntry?,
    ): GameResourceFetchResult?
}

class HttpUrlConnectionGameResourceFetcher(
    private val proxyProvider: () -> Proxy = { Proxy.NO_PROXY },
    private val connectTimeoutMs: Int = 8_000,
    private val readTimeoutMs: Int = 30_000,
    private val maxFileBytes: Long = 128L * 1024L * 1024L,
) : GameResourceFetcher {
    override fun fetch(
        url: String,
        requestHeaders: Map<String, String>,
        cached: GameResourceCacheEntry?,
    ): GameResourceFetchResult? {
        var current = url
        repeat(MAX_REDIRECTS + 1) { redirectCount ->
            if (!GameResourceCacheRules.shouldCache(current, "GET")) return null
            val connection = (URL(current).openConnection(proxyProvider()) as? HttpURLConnection) ?: return null
            try {
                connection.instanceFollowRedirects = false
                connection.connectTimeout = connectTimeoutMs
                connection.readTimeout = readTimeoutMs
                connection.requestMethod = "GET"
                requestHeaders.forEach { (name, value) ->
                    if (name.equals("Cookie", true) || name.equals("User-Agent", true) || name.equals("Accept", true)) {
                        connection.setRequestProperty(name, value)
                    }
                }
                cached?.etag?.let { connection.setRequestProperty("If-None-Match", it) }
                cached?.lastModified?.let { connection.setRequestProperty("If-Modified-Since", it) }
                val statusCode = connection.responseCode
                if (statusCode in REDIRECT_CODES) {
                    if (redirectCount >= MAX_REDIRECTS) return null
                    val location = connection.getHeaderField("Location") ?: return null
                    val next = URI(current).resolve(location).toString()
                    if (!isSafeRedirect(current, next)) return null
                    current = next
                    return@repeat
                }
                val headers = connection.headerFields.entries
                    .mapNotNull { (key, values) -> key?.let { it to values.joinToString(", ") } }
                    .toMap()
                if (statusCode == HttpURLConnection.HTTP_NOT_MODIFIED) {
                    return GameResourceFetchResult(statusCode, connection.responseMessage ?: "Not Modified", headers, ByteArray(0))
                }
                if (statusCode !in 200..299) return null
                val declaredLength = connection.contentLengthLong
                if (declaredLength > maxFileBytes) return null
                val bytes = connection.inputStream.use { input ->
                    val output = ByteArrayOutputStream()
                    val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
                    var total = 0L
                    while (true) {
                        val count = input.read(buffer)
                        if (count < 0) break
                        total += count
                        if (total > maxFileBytes) return null
                        output.write(buffer, 0, count)
                    }
                    output.toByteArray()
                }
                if (declaredLength >= 0 && declaredLength != bytes.size.toLong()) return null
                return GameResourceFetchResult(statusCode, connection.responseMessage ?: "OK", headers, bytes)
            } finally {
                connection.disconnect()
            }
        }
        return null
    }

    private fun isSafeRedirect(previous: String, next: String): Boolean {
        val before = runCatching { URI(previous) }.getOrNull() ?: return false
        val after = runCatching { URI(next) }.getOrNull() ?: return false
        if (!GameResourceCacheRules.shouldCache(next, "GET")) return false
        if (before.scheme.equals("https", true) && !after.scheme.equals("https", true)) return false
        return after.scheme.equals("https", true) || after.scheme.equals("http", true)
    }

    companion object {
        private const val MAX_REDIRECTS = 5
        private val REDIRECT_CODES = setOf(301, 302, 303, 307, 308)
    }
}
