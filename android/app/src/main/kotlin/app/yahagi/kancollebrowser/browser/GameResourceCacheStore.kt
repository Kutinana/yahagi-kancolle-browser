package app.yahagi.kancollebrowser.browser

import java.io.File
import java.nio.file.Files
import java.nio.file.StandardCopyOption
import java.security.MessageDigest
import java.util.UUID

data class GameResourceCachedValue(
    val bytes: ByteArray,
    val entry: GameResourceCacheEntry,
)

data class GameResourceCachedFile(val file: File, val entry: GameResourceCacheEntry)

enum class GameResourceStoredState { MISSING, VALID, DAMAGED }

data class GameResourceStoredInspection(
    val state: GameResourceStoredState,
    val entry: GameResourceCacheEntry? = null,
)

data class GameResourceCachePolicy(
    val maxBytes: Long,
    val maxIdleAgeMs: Long? = null,
) {
    init {
        require(maxBytes >= 0L) { "Cache capacity must not be negative" }
        require(maxIdleAgeMs == null || maxIdleAgeMs > 0L) {
            "Cache idle age must be positive"
        }
    }
}

class GameResourceCacheStore(
    private val root: File,
    private val index: GameResourceCacheIndex,
    maxBytes: Long = DEFAULT_MAX_BYTES,
    private val clock: () -> Long = System::currentTimeMillis,
    private val policyProvider: () -> GameResourceCachePolicy = {
        GameResourceCachePolicy(maxBytes = maxBytes)
    },
) {
    private val filesDirectory = root.resolve("files")
    private val temporaryDirectory = root.resolve("tmp")
    private var generation = 0L
    private var commitsSincePolicySweep = 0
    private var orphanCleanupPending = false
    val maxBytes: Long
        get() = policyProvider().maxBytes

    @Synchronized
    fun generation(): Long = generation

    init {
        filesDirectory.mkdirs()
        temporaryDirectory.mkdirs()
        runCatching {
            Files.newDirectoryStream(temporaryDirectory.toPath()).use { files ->
                files.forEach { Files.deleteIfExists(it) }
            }
        }
    }

    @Synchronized
    fun read(key: GameResourceCacheKey): GameResourceCachedValue? {
        val now = clock()
        val entry = liveEntry(key, now) ?: return null
        val file = safeFile(entry.fileName) ?: return invalidate(key)
        if (!file.isFile || file.length() != entry.byteLength) return invalidate(key)
        if (entry.byteLength > HttpUrlConnectionGameResourceFetcher.MAX_RESOURCE_BYTES) return invalidate(key)
        val bytes = runCatching { file.readBytes() }.getOrNull() ?: return invalidate(key)
        if (sha256(bytes) != entry.sha256) return invalidate(key)
        val touched = if (now - entry.lastAccessedAt >= ACCESS_TIME_WRITE_INTERVAL_MS) {
            entry.copy(lastAccessedAt = now).also(index::put)
        } else {
            entry
        }
        return GameResourceCachedValue(bytes, touched)
    }

    fun readFile(key: GameResourceCacheKey): GameResourceCachedFile? {
        // Hashing a cached file must not block unrelated WebView resource reads.
        repeat(2) {
            val snapshot = synchronized(this) { liveEntry(key, clock()) } ?: return null
            val file = safeFile(snapshot.fileName)
            val valid = file?.isFile == true && file.length() == snapshot.byteLength &&
                snapshot.byteLength <= HttpUrlConnectionGameResourceFetcher.MAX_RESOURCE_BYTES &&
                runCatching { sha256(file) }.getOrNull() == snapshot.sha256
            synchronized(this) {
                val current = liveEntry(key, clock()) ?: return null
                if (current.fileName != snapshot.fileName || current.sha256 != snapshot.sha256 ||
                    current.byteLength != snapshot.byteLength) return@synchronized
                if (!valid || file == null) return invalidateFile(key)
                val now = clock()
                val touched = if (now - current.lastAccessedAt >= ACCESS_TIME_WRITE_INTERVAL_MS) {
                    current.copy(lastAccessedAt = now).also(index::put)
                } else current
                return GameResourceCachedFile(file, touched)
            }
        }
        return null
    }

    private fun invalidateFile(key: GameResourceCacheKey): GameResourceCachedFile? {
        remove(key)
        return null
    }

    @Synchronized
    fun contains(key: GameResourceCacheKey): Boolean {
        val entry = liveEntry(key, clock()) ?: return false
        val file = safeFile(entry.fileName) ?: return false
        return file.isFile && file.length() == entry.byteLength
    }

    fun commit(
        key: GameResourceCacheKey,
        bytes: ByteArray,
        version: String? = null,
        mimeType: String,
        etag: String? = null,
        lastModified: String? = null,
        responseHeaders: Map<String, String> = emptyMap(),
    ): GameResourceCacheEntry = checkNotNull(
        commitWithEviction(key, bytes, version, mimeType, etag, lastModified, responseHeaders),
    ) { "Resource does not fit within the cache capacity" }

    fun commitWithEviction(
        key: GameResourceCacheKey,
        bytes: ByteArray,
        version: String? = null,
        mimeType: String,
        etag: String? = null,
        lastModified: String? = null,
        responseHeaders: Map<String, String> = emptyMap(),
        expectedGeneration: Long? = null,
    ): GameResourceCacheEntry? = commitInternal(
        key, bytes.size.toLong(), { sha256(bytes) }, { it.writeBytes(bytes) }, version,
        mimeType, etag, lastModified, responseHeaders, expectedGeneration,
    )

    fun commitFileWithEviction(
        key: GameResourceCacheKey,
        source: File,
        version: String? = null,
        mimeType: String,
        etag: String? = null,
        lastModified: String? = null,
        responseHeaders: Map<String, String> = emptyMap(),
        expectedGeneration: Long? = null,
    ): GameResourceCacheEntry? = commitInternal(
        key, source.length(), { sha256(source) }, { source.copyTo(it, overwrite = true) },
        version, mimeType, etag, lastModified, responseHeaders, expectedGeneration,
    )

    private fun commitInternal(
        key: GameResourceCacheKey,
        bodyLength: Long,
        checksumOfSource: () -> String,
        writeTemporary: (File) -> Unit,
        version: String?,
        mimeType: String,
        etag: String?,
        lastModified: String?,
        responseHeaders: Map<String, String>,
        expectedGeneration: Long?,
    ): GameResourceCacheEntry? {
        if (bodyLength > HttpUrlConnectionGameResourceFetcher.MAX_RESOURCE_BYTES) return null
        // Prepare the downloaded file outside the index lock so cache hits can proceed.
        val checksum = checksumOfSource()
        val fileName = "$checksum.cache"
        val destination = filesDirectory.resolve(fileName)
        val temporary = temporaryDirectory.resolve("${UUID.randomUUID()}.part")
        try {
            writeTemporary(temporary)
            if (temporary.length() != bodyLength) return null
            return synchronized(this) {
                // Clear may have run while the temporary file was being written.
                if (expectedGeneration != null && expectedGeneration != generation) {
                    return@synchronized null
                }
                val policy = policyProvider()
                if (policy.maxIdleAgeMs != null && ++commitsSincePolicySweep >= 256) {
                    enforcePolicy()
                    commitsSincePolicySweep = 0
                }
                val capacity = maxBytes
                if (bodyLength > capacity) return@synchronized null
                val previous = index.get(key)
                evictForReplacement(key, bodyLength, previous?.byteLength ?: 0L, capacity)
                if (projectedBytes(previous?.byteLength ?: 0L, bodyLength) > capacity) {
                    return@synchronized null
                }
                val entry = GameResourceCacheEntry(
                    key = key.value,
                    fileName = fileName,
                    version = version,
                    mimeType = mimeType,
                    byteLength = bodyLength,
                    etag = etag,
                    lastModified = lastModified,
                    lastAccessedAt = clock(),
                    lastValidatedAt = clock(),
                    sha256 = checksum,
                    responseHeaders = responseHeaders,
                )
                while (!index.canPut(entry)) {
                    val oldest = index.oldestEntry()?.takeIf { it.key != key.value }
                        ?: return@synchronized null
                    remove(GameResourceCacheKey(oldest.key))
                }
                if (!destination.isFile || destination.length() != bodyLength ||
                    runCatching { sha256(destination) }.getOrNull() != checksum
                ) atomicReplace(temporary, destination)
                try {
                    index.put(entry)
                } catch (error: Exception) {
                    orphanCleanupPending = true
                    runCatching {
                        if (!index.isFileReferenced(fileName) && destination.exists() &&
                            !destination.delete()) {
                            throw IllegalStateException("Cannot remove unindexed resource cache file")
                        }
                    }
                    throw error
                }
                if (previous != null && previous.fileName != fileName) {
                    deleteIfUnreferenced(previous.fileName)
                }
                entry
            }
        } finally {
            if (temporary.exists() && !temporary.delete()) {
                synchronized(this) { orphanCleanupPending = true }
            }
        }
    }

    private fun evictForReplacement(
        currentKey: GameResourceCacheKey,
        newBytes: Long,
        replacedBytes: Long,
        capacity: Long,
    ) {
        if (projectedBytes(replacedBytes, newBytes) <= capacity) return
        index.snapshot()
            .asSequence()
            .filterNot { it.key == currentKey.value }
            .sortedBy { it.lastAccessedAt }
            .forEach { entry ->
                if (projectedBytes(replacedBytes, newBytes) <= capacity) return@forEach
                remove(GameResourceCacheKey(entry.key))
            }
    }

    private fun projectedBytes(replacedBytes: Long, newBytes: Long): Long =
        totalBytes() - replacedBytes + newBytes

    @Synchronized
    fun totalBytes(): Long = index.totalBytes()

    @Synchronized
    fun wouldExceedCapacity(requiredBytes: Long): Boolean =
        requiredBytes > maxBytes || totalBytes() > maxBytes - requiredBytes

    @Synchronized
    fun enforcePolicy() {
        if (orphanCleanupPending) reconcileOrphanFiles()
        val policy = policyProvider()
        val now = clock()
        if (policy.maxIdleAgeMs != null) {
            index.snapshot()
                .filter { isExpired(it, now, policy) }
                .forEach { remove(GameResourceCacheKey(it.key)) }
        }
        var usedBytes = totalBytes()
        if (usedBytes <= policy.maxBytes) return
        for (entry in index.snapshot().sortedBy { it.lastAccessedAt }) {
            if (usedBytes <= policy.maxBytes) break
            if (remove(GameResourceCacheKey(entry.key))) {
                usedBytes -= entry.byteLength
            }
        }
    }

    @Synchronized
    fun evictToFit(
        requiredBytes: Long,
        protectedKeys: Set<GameResourceCacheKey> = emptySet(),
    ): List<GameResourceCacheKey> {
        if (!wouldExceedCapacity(requiredBytes)) return emptyList()
        val protectedValues = protectedKeys.mapTo(hashSetOf()) { it.value }
        val removed = mutableListOf<GameResourceCacheKey>()
        index.snapshot()
            .asSequence()
            .filterNot { it.key in protectedValues }
            .sortedBy { it.lastAccessedAt }
            .forEach { entry ->
                if (!wouldExceedCapacity(requiredBytes)) return@forEach
                val key = GameResourceCacheKey(entry.key)
                remove(key)
                removed += key
            }
        return removed
    }

    @Synchronized
    fun remove(key: GameResourceCacheKey): Boolean {
        val entry = index.get(key) ?: return false
        if (index.fileReferenceCount(entry.fileName) == 1) {
            val file = safeFile(entry.fileName)
                ?: throw IllegalStateException("Unsafe resource cache file name")
            if (file.exists() && !file.delete()) {
                throw IllegalStateException("Cannot remove resource cache file")
            }
        }
        index.remove(key) ?: return false
        return true
    }

    @Synchronized
    fun removeIfGeneration(key: GameResourceCacheKey, expectedGeneration: Long): Boolean =
        generation == expectedGeneration && remove(key)

    @Synchronized
    fun removeLegacyHostlessEntries() {
        val removed = index.removePrefix("/")
        // A previous process may have crashed after journaling a removal or clear
        // but before unlinking its files. Reconcile every file on first cache I/O.
        reconcileOrphanFiles()
        if (removed.isNotEmpty()) generation++
    }

    private fun reconcileOrphanFiles() {
        Files.newDirectoryStream(filesDirectory.toPath()).use { files ->
            files.forEach { path ->
                if (!index.isFileReferenced(path.fileName.toString()) && !Files.deleteIfExists(path)) {
                    orphanCleanupPending = true
                    throw IllegalStateException("Cannot remove an orphaned resource cache file")
                }
            }
        }
        Files.newDirectoryStream(temporaryDirectory.toPath()).use { files ->
            files.forEach { path ->
                if (!Files.deleteIfExists(path)) {
                    orphanCleanupPending = true
                    throw IllegalStateException("Cannot remove temporary resource cache file")
                }
            }
        }
        orphanCleanupPending = false
    }

    @Synchronized
    fun clear() {
        generation++
        index.clear()
        try {
            deleteAllChildren(filesDirectory)
            deleteAllChildren(temporaryDirectory)
            orphanCleanupPending = false
        } catch (error: Exception) {
            orphanCleanupPending = true
            throw error
        }
    }

    private fun deleteAllChildren(directory: File) {
        Files.newDirectoryStream(directory.toPath()).use { children ->
            children.forEach { child ->
                if (!Files.deleteIfExists(child)) {
                    throw IllegalStateException("Cannot clear resource cache file")
                }
            }
        }
    }

    fun entries(): List<GameResourceCacheEntry> = index.snapshot()

    @Synchronized
    fun inspect(key: GameResourceCacheKey): GameResourceStoredInspection {
        val metadata = inspectMetadata(key)
        val entry = metadata.entry ?: return metadata
        val file = safeFile(entry.fileName)
            ?: return GameResourceStoredInspection(GameResourceStoredState.DAMAGED)
        val checksum = runCatching { sha256(file) }.getOrNull()
        if (checksum == null || checksum != entry.sha256) {
            return GameResourceStoredInspection(GameResourceStoredState.DAMAGED)
        }
        return metadata
    }

    @Synchronized
    fun inspectMetadata(key: GameResourceCacheKey): GameResourceStoredInspection {
        val entry = liveEntry(key, clock())
            ?: return GameResourceStoredInspection(GameResourceStoredState.MISSING)
        val file = safeFile(entry.fileName)
        if (file == null || !file.isFile || file.length() != entry.byteLength) {
            return GameResourceStoredInspection(GameResourceStoredState.DAMAGED)
        }
        return GameResourceStoredInspection(GameResourceStoredState.VALID, entry)
    }

    @Synchronized
    fun markValidated(
        key: GameResourceCacheKey,
        responseHeaders: Map<String, String> = emptyMap(),
        expectedGeneration: Long? = null,
    ): Boolean {
        if (expectedGeneration != null && expectedGeneration != generation) return false
        val entry = index.get(key) ?: return false
        val merged = entry.responseHeaders.toMutableMap()
        GameResourceCacheRules.persistedResponseHeaders(responseHeaders).forEach { (name, value) ->
            merged.keys.filter { it.equals(name, ignoreCase = true) }.forEach(merged::remove)
            merged[name] = value
        }
        fun updated(name: String): String? = responseHeaders.entries
            .firstOrNull { it.key.equals(name, ignoreCase = true) }?.value
        index.put(entry.copy(
            lastValidatedAt = clock(),
            etag = updated("ETag") ?: entry.etag,
            lastModified = updated("Last-Modified") ?: entry.lastModified,
            responseHeaders = merged,
        ))
        return true
    }

    fun availableDeviceBytes(): Long = root.usableSpace

    private fun invalidate(key: GameResourceCacheKey): GameResourceCachedValue? {
        remove(key)
        return null
    }

    private fun liveEntry(key: GameResourceCacheKey, now: Long): GameResourceCacheEntry? {
        val entry = index.get(key) ?: return null
        if (!isExpired(entry, now, policyProvider())) return entry
        remove(key)
        return null
    }

    private fun isExpired(
        entry: GameResourceCacheEntry,
        now: Long,
        policy: GameResourceCachePolicy,
    ): Boolean = policy.maxIdleAgeMs?.let { now - entry.lastAccessedAt >= it } == true

    private fun deleteIfUnreferenced(fileName: String) {
        if (index.isFileReferenced(fileName)) return
        val file = safeFile(fileName) ?: throw IllegalStateException("Unsafe resource cache file name")
        if (file.exists() && !file.delete()) {
            orphanCleanupPending = true
            throw IllegalStateException("Cannot remove resource cache file")
        }
    }

    private fun safeFile(fileName: String): File? {
        if (fileName.contains('/') || fileName.contains('\\')) return null
        val file = filesDirectory.resolve(fileName)
        return file.takeIf { it.parentFile == filesDirectory }
    }

    private fun atomicReplace(source: File, target: File) {
        try {
            Files.move(
                source.toPath(),
                target.toPath(),
                StandardCopyOption.ATOMIC_MOVE,
                StandardCopyOption.REPLACE_EXISTING,
            )
        } catch (_: Exception) {
            Files.move(source.toPath(), target.toPath(), StandardCopyOption.REPLACE_EXISTING)
        }
    }

    private fun sha256(bytes: ByteArray): String =
        MessageDigest.getInstance("SHA-256").digest(bytes).joinToString("") { "%02x".format(it) }

    private fun sha256(file: File): String {
        val digest = MessageDigest.getInstance("SHA-256")
        file.inputStream().buffered().use { input ->
            val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
            while (true) {
                val count = input.read(buffer)
                if (count < 0) break
                digest.update(buffer, 0, count)
            }
        }
        return digest.digest().joinToString("") { "%02x".format(it) }
    }

    companion object {
        const val DEFAULT_MAX_BYTES: Long = 50_000_000_000L
        const val TEMPORARY_MAX_BYTES: Long = 2_000_000_000L
        const val TEMPORARY_MAX_IDLE_AGE_MS: Long = 7L * 24L * 60L * 60L * 1000L
        private const val ACCESS_TIME_WRITE_INTERVAL_MS = 60_000L
    }
}
