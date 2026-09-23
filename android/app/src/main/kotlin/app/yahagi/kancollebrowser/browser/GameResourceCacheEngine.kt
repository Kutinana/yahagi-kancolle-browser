package app.yahagi.kancollebrowser.browser

import java.net.HttpURLConnection
import java.net.URI
import java.util.concurrent.atomic.AtomicBoolean

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
    private val clock: () -> Long = System::currentTimeMillis,
    private val modeProvider: () -> GameResourceCacheMode,
) {
    private val locks = Array(64) { Any() }
    private val legacyMigrationDone = AtomicBoolean(false)

    private fun ensureLegacyMigration() {
        if (legacyMigrationDone.get()) return
        synchronized(legacyMigrationDone) {
            if (legacyMigrationDone.get()) return
            // Index loading and migration run on the caller's background I/O path.
            store.removeLegacyHostlessEntries()
            legacyMigrationDone.set(true)
        }
    }

    fun fetch(
        url: String,
        requestHeaders: Map<String, String> = emptyMap(),
        method: String = "GET",
        expectedLength: Long? = null,
        shouldStore: () -> Boolean = { true },
    ): GameResourceResponse? {
        val mode = modeProvider()
        if (!mode.readsCache || !GameResourceCacheRules.shouldCache(url, method) ||
            requestHeaders.keys.any { name -> BYPASS_REQUEST_HEADERS.any { it.equals(name, true) } ||
                (name.startsWith("X-", ignoreCase = true) &&
                    !name.equals("X-Requested-With", ignoreCase = true)) } ||
            requestHeaders.keys.any { name ->
                name.equals("Cache-Control", true) || name.equals("Pragma", true)
            }
        ) return null
        ensureLegacyMigration()
        val key = GameResourceCacheKey.from(url, requestHeaders) ?: return null
        val lock = locks[(key.hashCode() and Int.MAX_VALUE) % locks.size]
        synchronized(lock) {
            val storeGeneration = store.generation()
            val cached = store.read(key)
            val cachedLengthMismatch = cached != null && expectedLength != null &&
                cached.entry.byteLength != expectedLength
            val mustValidate = GameResourceCacheRules.isAlwaysValidated(url) ||
                cachedLengthMismatch ||
                (cached != null && cached.entry.version == null &&
                    clock() - cached.entry.lastValidatedAt >= UNVERSIONED_TTL_MS)
            if (cached != null && !mustValidate) return cached.toResponse()
            val strictValidation = GameResourceCacheRules.requiresStrictValidation(url)

            val validationEntry = cached?.entry?.takeUnless { cachedLengthMismatch }
            val fetched = runCatching { fetcher.fetch(url, requestHeaders, validationEntry) }.getOrNull()
                ?: return if (strictValidation || cachedLengthMismatch ||
                    store.generation() != storeGeneration) null else cached?.toResponse()
            if (fetched.statusCode == HttpURLConnection.HTTP_NOT_MODIFIED) {
                if (cachedLengthMismatch) return null
                if (!fetched.headers.isCacheableResponse()) {
                    store.removeIfGeneration(key, storeGeneration)
                    return null
                }
                val updatedHeaders = fetched.headers.filterKeys { name ->
                    name.lowercase() !in HOP_BY_HOP_HEADERS &&
                        !name.equals("Content-Length", ignoreCase = true)
                }
                if (!store.markValidated(key, updatedHeaders, storeGeneration)) return null
                return store.read(key)?.toResponse()
            }
            if (fetched.statusCode != HttpURLConnection.HTTP_OK) {
                if (fetched.statusCode == HttpURLConnection.HTTP_PARTIAL) return null
                return if (strictValidation || cachedLengthMismatch ||
                    store.generation() != storeGeneration) null else cached?.toResponse()
            }
            if (!fetched.headers.isCacheableResponse()) {
                store.removeIfGeneration(key, storeGeneration)
                return null
            }
            val declaredLength = fetched.headers.value("Content-Length")?.toLongOrNull()
            if (declaredLength != null && declaredLength != fetched.bytes.size.toLong()) {
                return if (strictValidation || store.generation() != storeGeneration) null
                    else cached?.toResponse()
            }

            val mimeInfo = GameResourceCacheRules.mimeTypeFor(url)
            val mimeType = fetched.headers.value("Content-Type")
                ?.substringBefore(';')
                ?.trim()
                ?.takeIf { it.isNotEmpty() }
                ?: mimeInfo.mime
            val matchesManifest = expectedLength == null ||
                expectedLength == fetched.bytes.size.toLong()
            if (matchesManifest && modeProvider().writesCache && shouldStore()) {
                store.commitWithEviction(
                    key = key,
                    bytes = fetched.bytes,
                    version = runCatching { URI(url).rawQuery }.getOrNull(),
                    mimeType = mimeType,
                    etag = fetched.headers.value("ETag"),
                    lastModified = fetched.headers.value("Last-Modified"),
                    responseHeaders = fetched.headers.filterKeys { name ->
                        name.lowercase() !in HOP_BY_HOP_HEADERS
                    },
                    expectedGeneration = storeGeneration,
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

    fun status(): GameResourceCacheStatus {
        ensureLegacyMigration()
        store.enforcePolicy()
        return statusSnapshot()
    }

    fun statusSnapshot(): GameResourceCacheStatus {
        ensureLegacyMigration()
        return GameResourceCacheStatus(
            usedBytes = store.totalBytes(),
            maxBytes = store.maxBytes,
            fileCount = store.entries().size,
        )
    }

    fun enforcePolicy() = store.enforcePolicy()

    fun clear() = store.clear()

    fun entries(): List<GameResourceCacheEntry> {
        ensureLegacyMigration()
        return store.entries()
    }

    fun hasCached(url: String): Boolean {
        return inspect(url).state == GameResourceInspectionState.VALID
    }

    fun hasCachedMetadata(url: String, expectedLength: Long? = null): Boolean {
        return inspectMetadata(url, expectedLength).state == GameResourceInspectionState.VALID
    }

    fun inspect(url: String, expectedLength: Long? = null): GameResourceInspection =
        inspect(url, verifyChecksum = true, expectedLength = expectedLength)

    fun inspectMetadata(url: String, expectedLength: Long? = null): GameResourceInspection =
        inspect(url, verifyChecksum = false, expectedLength = expectedLength)

    private fun inspect(
        url: String,
        verifyChecksum: Boolean,
        expectedLength: Long?,
    ): GameResourceInspection {
        ensureLegacyMigration()
        val key = GameResourceCacheKey.from(url)
            ?: return GameResourceInspection(GameResourceInspectionState.MISSING)
        val stored = if (verifyChecksum) store.inspect(key) else store.inspectMetadata(key)
        val entry = stored.entry
        val state = when {
            stored.state == GameResourceStoredState.MISSING -> GameResourceInspectionState.MISSING
            stored.state == GameResourceStoredState.DAMAGED -> GameResourceInspectionState.DAMAGED
            entry != null && expectedLength != null && entry.byteLength != expectedLength ->
                GameResourceInspectionState.OUTDATED
            entry != null && expectedLength == null && entry.version == null &&
                clock() - entry.lastValidatedAt >= UNVERSIONED_TTL_MS ->
                GameResourceInspectionState.OUTDATED
            else -> GameResourceInspectionState.VALID
        }
        return GameResourceInspection(state, entry?.byteLength ?: 0L)
    }

    fun availableDeviceBytes(): Long = store.availableDeviceBytes()

    private fun GameResourceCachedValue.toResponse(): GameResourceResponse {
        val mime = entry.mimeType
        val encoding = if (mime.startsWith("text/") || mime.contains("javascript") || mime.contains("json")) "utf-8" else null
        return GameResourceResponse(
            bytes = bytes,
            mimeType = mime,
            encoding = encoding,
            headers = buildMap {
                putAll(entry.responseHeaders)
                if (keys.none { it.equals("ETag", true) }) entry.etag?.let { put("ETag", it) }
                if (keys.none { it.equals("Last-Modified", true) }) {
                    entry.lastModified?.let { put("Last-Modified", it) }
                }
                keys.filter { it.equals("Content-Length", true) }.forEach(::remove)
                put("Content-Length", entry.byteLength.toString())
            },
            source = GameResourceResponseSource.CACHE,
        )
    }

    private fun Map<String, String>.value(name: String): String? =
        entries.firstOrNull { it.key.equals(name, ignoreCase = true) }?.value

    private fun Map<String, String>.isCacheableResponse(): Boolean {
        if (value("Set-Cookie") != null || value("Set-Cookie2") != null ||
            value("Vary") != null || value("Pragma")?.contains("no-cache", true) == true
        ) return false
        val directives = value("Cache-Control")?.split(',')?.map { it.trim().substringBefore('=').lowercase() }.orEmpty()
        return directives.none { it == "private" || it == "no-store" || it == "no-cache" }
    }

    companion object {
        const val UNVERSIONED_TTL_MS: Long = 6L * 60L * 60L * 1000L
        private val HOP_BY_HOP_HEADERS = setOf(
            "connection", "keep-alive", "proxy-authenticate", "proxy-authorization",
            "te", "trailer", "transfer-encoding", "upgrade", "set-cookie",
        )
        private val BYPASS_REQUEST_HEADERS = setOf(
            "Range", "If-Range", "If-None-Match", "If-Modified-Since",
            "If-Match", "If-Unmodified-Since", "Authorization", "Proxy-Authorization",
        )
    }
}

enum class GameResourceInspectionState { MISSING, VALID, DAMAGED, OUTDATED }

data class GameResourceInspection(
    val state: GameResourceInspectionState,
    val byteLength: Long = 0L,
)

data class GameResourceCacheStatus(
    val usedBytes: Long,
    val maxBytes: Long,
    val fileCount: Int,
)
