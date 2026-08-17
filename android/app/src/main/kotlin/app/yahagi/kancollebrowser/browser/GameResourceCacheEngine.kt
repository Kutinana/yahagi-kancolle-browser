package app.yahagi.kancollebrowser.browser

import java.net.HttpURLConnection
import java.net.URI

enum class GameResourceResponseSource { CACHE, NETWORK }

data class GameResourceResponse(
    val bytes: ByteArray,
    val mimeType: String,
    val encoding: String?,
    val statusCode: Int = 200,
    val reasonPhrase: String = "OK",
    val headers: Map<String, String> = emptyMap(),
    val source: GameResourceResponseSource,
)

class GameResourceCacheEngine(
    private val store: GameResourceCacheStore,
    private val fetcher: GameResourceFetcher,
    private val modeProvider: () -> GameResourceCacheMode,
) {
    private val locks = Array(64) { Any() }

    fun fetch(
        url: String,
        requestHeaders: Map<String, String> = emptyMap(),
    ): GameResourceResponse? {
        val mode = modeProvider()
        if (!mode.readsCache || !GameResourceCacheRules.shouldCache(url, "GET")) return null
        val key = GameResourceCacheKey.from(url) ?: return null
        val lock = locks[(key.hashCode() and Int.MAX_VALUE) % locks.size]
        synchronized(lock) {
            val cached = store.read(key)
            val mustValidate = GameResourceCacheRules.isAlwaysValidated(url)
            if (cached != null && !mustValidate) return cached.toResponse()

            val fetched = runCatching { fetcher.fetch(url, requestHeaders, cached?.entry) }.getOrNull()
                ?: return cached?.toResponse()
            if (fetched.statusCode == HttpURLConnection.HTTP_NOT_MODIFIED) return cached?.toResponse()
            if (fetched.statusCode !in 200..299) return cached?.toResponse()
            val declaredLength = fetched.headers.value("Content-Length")?.toLongOrNull()
            if (declaredLength != null && declaredLength != fetched.bytes.size.toLong()) return cached?.toResponse()

            val mimeInfo = GameResourceCacheRules.mimeTypeFor(url)
            val mimeType = fetched.headers.value("Content-Type")
                ?.substringBefore(';')
                ?.trim()
                ?.takeIf { it.isNotEmpty() }
                ?: mimeInfo.mime
            if (mode == GameResourceCacheMode.LIGHT) {
                store.evictLightToFit(fetched.bytes.size.toLong())
            }
            if (!store.wouldExceedCapacity(fetched.bytes.size.toLong())) {
                store.commit(
                    key = key,
                    bytes = fetched.bytes,
                    version = runCatching { URI(url).rawQuery }.getOrNull(),
                    mimeType = mimeType,
                    etag = fetched.headers.value("ETag"),
                    lastModified = fetched.headers.value("Last-Modified"),
                )
            }
            return GameResourceResponse(
                bytes = fetched.bytes,
                mimeType = mimeType,
                encoding = mimeInfo.encoding,
                statusCode = fetched.statusCode,
                reasonPhrase = fetched.reasonPhrase,
                headers = fetched.headers,
                source = GameResourceResponseSource.NETWORK,
            )
        }
    }

    fun status(): GameResourceCacheStatus = GameResourceCacheStatus(
        usedBytes = store.totalBytes(),
        maxBytes = store.maxBytes,
        fileCount = store.entries().size,
    )

    fun clear() = store.clear()

    fun entries(): List<GameResourceCacheEntry> = store.entries()

    fun hasCached(url: String): Boolean {
        val key = GameResourceCacheKey.from(url) ?: return false
        return store.read(key) != null
    }

    private fun GameResourceCachedValue.toResponse(): GameResourceResponse {
        val mime = entry.mimeType
        val encoding = if (mime.startsWith("text/") || mime.contains("javascript") || mime.contains("json")) "utf-8" else null
        return GameResourceResponse(
            bytes = bytes,
            mimeType = mime,
            encoding = encoding,
            headers = buildMap {
                entry.etag?.let { put("ETag", it) }
                entry.lastModified?.let { put("Last-Modified", it) }
                put("Content-Length", entry.byteLength.toString())
            },
            source = GameResourceResponseSource.CACHE,
        )
    }

    private fun Map<String, String>.value(name: String): String? =
        entries.firstOrNull { it.key.equals(name, ignoreCase = true) }?.value
}

data class GameResourceCacheStatus(
    val usedBytes: Long,
    val maxBytes: Long,
    val fileCount: Int,
)
