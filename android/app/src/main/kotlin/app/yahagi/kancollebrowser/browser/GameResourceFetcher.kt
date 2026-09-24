package app.yahagi.kancollebrowser.browser

import java.io.File
import java.io.InputStream
import java.net.HttpURLConnection
import java.net.Proxy
import java.net.URI
import java.net.URL
import java.util.UUID

data class GameResourceFetchResult(
    val statusCode: Int,
    val reasonPhrase: String,
    val headers: Map<String, String>,
    val bytes: ByteArray = ByteArray(0),
    val file: File? = null,
) {
    val bodyLength: Long get() = file?.length() ?: bytes.size.toLong()
}

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
    private val maxFileBytes: Long = MAX_RESOURCE_BYTES,
    private val temporaryDirectory: File = File(System.getProperty("java.io.tmpdir"), "yahagi-resource-downloads"),
) : GameResourceFetcher {
    init {
        temporaryDirectory.mkdirs()
        temporaryDirectory.listFiles()?.forEach { file ->
            if (file.name.endsWith(".part") &&
                System.currentTimeMillis() - file.lastModified() > 24L * 60L * 60L * 1000L
            ) file.delete()
        }
    }

    override fun fetch(
        url: String,
        requestHeaders: Map<String, String>,
        cached: GameResourceCacheEntry?,
    ): GameResourceFetchResult? {
        val forwarded = GameResourceCacheRules.boundedForwardedRequestHeaders(requestHeaders)
            ?: return null
        var current = url
        repeat(MAX_REDIRECTS + 1) { redirectCount ->
            if (!GameResourceCacheRules.shouldCache(current, "GET")) return null
            val connection = (URL(current).openConnection(proxyProvider()) as? HttpURLConnection) ?: return null
            try {
                connection.instanceFollowRedirects = false
                connection.connectTimeout = connectTimeoutMs
                connection.readTimeout = readTimeoutMs
                connection.requestMethod = "GET"
                forwarded.forEach { (name, value) ->
                    connection.setRequestProperty(name, value)
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
                val headers = linkedMapOf<String, String>()
                var headerChars = 0L
                connection.headerFields.forEach { (key, values) ->
                    if (key == null) return@forEach
                    if (key.length > 128 || values.size > 32) return null
                    headerChars += key.length + values.sumOf { it.length.toLong() + 2L }
                    if (headerChars > 32_768) return null
                    headers[key] = values.joinToString(", ")
                }
                if (statusCode == HttpURLConnection.HTTP_NOT_MODIFIED) {
                    return GameResourceFetchResult(statusCode, connection.responseMessage ?: "Not Modified", headers, ByteArray(0))
                }
                if (statusCode !in 200..299) return null
                // WebView handles range responses and Set-Cookie; do not download the body twice.
                if (statusCode == HttpURLConnection.HTTP_PARTIAL ||
                    headers.keys.any { it.equals("Set-Cookie", true) || it.equals("Set-Cookie2", true) }) {
                    return GameResourceFetchResult(statusCode, connection.responseMessage ?: "OK", headers)
                }
                val declaredLength = connection.contentLengthLong
                if (declaredLength > maxFileBytes) return null
                val file = connection.inputStream.use { input ->
                    downloadToTemporaryFile(input, declaredLength, maxFileBytes, temporaryDirectory)
                }
                    ?: return null
                return GameResourceFetchResult(statusCode, connection.responseMessage ?: "OK", headers, file = file)
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
        return before.host.equals(after.host, ignoreCase = true)
    }

    companion object {
        const val MAX_RESOURCE_BYTES = 16L * 1024L * 1024L
        private const val MAX_REDIRECTS = 5
        private val REDIRECT_CODES = setOf(301, 302, 303, 307, 308)

        internal fun downloadToTemporaryFile(
            input: InputStream,
            declaredLength: Long,
            maxBytes: Long,
            directory: File,
        ): File? {
            if (declaredLength > maxBytes || !directory.isDirectory && !directory.mkdirs()) return null
            val file = directory.resolve("${UUID.randomUUID()}.part")
            var complete = false
            try {
                file.outputStream().buffered().use { output ->
                    val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
                    var total = 0L
                    while (true) {
                        val count = input.read(buffer)
                        if (count < 0) break
                        if (count == 0) continue
                        total += count
                        if (total > maxBytes) return null
                        output.write(buffer, 0, count)
                    }
                    if (declaredLength >= 0 && declaredLength != total) return null
                }
                complete = true
                return file
            } finally {
                if (!complete) file.delete()
            }
        }
    }
}
