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

enum class GameResourceStoredState { MISSING, VALID, DAMAGED }

data class GameResourceStoredInspection(
    val state: GameResourceStoredState,
    val entry: GameResourceCacheEntry? = null,
)

class GameResourceCacheStore(
    private val root: File,
    private val index: GameResourceCacheIndex,
    val maxBytes: Long = DEFAULT_MAX_BYTES,
    private val clock: () -> Long = System::currentTimeMillis,
) {
    private val filesDirectory = root.resolve("files")
    private val temporaryDirectory = root.resolve("tmp")

    init {
        filesDirectory.mkdirs()
        temporaryDirectory.mkdirs()
        temporaryDirectory.listFiles()?.forEach { it.delete() }
    }

    @Synchronized
    fun read(key: GameResourceCacheKey): GameResourceCachedValue? {
        val entry = index.get(key) ?: return null
        val file = safeFile(entry.fileName) ?: return invalidate(key, entry)
        if (!file.isFile || file.length() != entry.byteLength) return invalidate(key, entry)
        val bytes = runCatching { file.readBytes() }.getOrNull() ?: return invalidate(key, entry)
        if (sha256(bytes) != entry.sha256) return invalidate(key, entry)
        val now = clock()
        val touched = if (now - entry.lastAccessedAt >= ACCESS_TIME_WRITE_INTERVAL_MS) {
            entry.copy(lastAccessedAt = now).also(index::put)
        } else {
            entry
        }
        return GameResourceCachedValue(bytes, touched)
    }

    @Synchronized
    fun contains(key: GameResourceCacheKey): Boolean {
        val entry = index.get(key) ?: return false
        val file = safeFile(entry.fileName) ?: return false
        return file.isFile && file.length() == entry.byteLength
    }

    @Synchronized
    fun commit(
        key: GameResourceCacheKey,
        bytes: ByteArray,
        version: String? = null,
        mimeType: String,
        etag: String? = null,
        lastModified: String? = null,
    ): GameResourceCacheEntry = checkNotNull(
        commitWithEviction(key, bytes, version, mimeType, etag, lastModified),
    ) { "Resource does not fit within the cache capacity" }

    @Synchronized
    fun commitWithEviction(
        key: GameResourceCacheKey,
        bytes: ByteArray,
        version: String? = null,
        mimeType: String,
        etag: String? = null,
        lastModified: String? = null,
    ): GameResourceCacheEntry? {
        if (bytes.size.toLong() > maxBytes) return null
        val checksum = sha256(bytes)
        val fileName = "$checksum.cache"
        val destination = filesDirectory.resolve(fileName)
        val temporary = temporaryDirectory.resolve("${UUID.randomUUID()}.part")
        val previous = index.get(key)
        temporary.writeBytes(bytes)
        evictForReplacement(key, bytes.size.toLong(), previous?.byteLength ?: 0L)
        if (projectedBytes(previous?.byteLength ?: 0L, bytes.size.toLong()) > maxBytes) {
            temporary.delete()
            return null
        }
        atomicReplace(temporary, destination)
        val entry = GameResourceCacheEntry(
            key = key.value,
            fileName = fileName,
            version = version,
            mimeType = mimeType,
            byteLength = bytes.size.toLong(),
            etag = etag,
            lastModified = lastModified,
            lastAccessedAt = clock(),
            lastValidatedAt = clock(),
            sha256 = checksum,
        )
        index.put(entry)
        if (previous != null && previous.fileName != fileName) deleteIfUnreferenced(previous.fileName)
        return entry
    }

    private fun evictForReplacement(
        currentKey: GameResourceCacheKey,
        newBytes: Long,
        replacedBytes: Long,
    ) {
        if (projectedBytes(replacedBytes, newBytes) <= maxBytes) return
        index.snapshot()
            .asSequence()
            .filterNot { it.key == currentKey.value }
            .sortedBy { it.lastAccessedAt }
            .forEach { entry ->
                if (projectedBytes(replacedBytes, newBytes) <= maxBytes) return@forEach
                remove(GameResourceCacheKey(entry.key))
            }
    }

    private fun projectedBytes(replacedBytes: Long, newBytes: Long): Long =
        totalBytes() - replacedBytes + newBytes

    @Synchronized
    fun totalBytes(): Long = index.snapshot().sumOf { it.byteLength }

    @Synchronized
    fun wouldExceedCapacity(requiredBytes: Long): Boolean =
        requiredBytes > maxBytes || totalBytes() > maxBytes - requiredBytes

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
        val removed = index.remove(key) ?: return false
        deleteIfUnreferenced(removed.fileName)
        return true
    }

    @Synchronized
    fun clear() {
        index.clear()
        filesDirectory.listFiles()?.forEach { it.delete() }
        temporaryDirectory.listFiles()?.forEach { it.delete() }
    }

    fun entries(): List<GameResourceCacheEntry> = index.snapshot()

    @Synchronized
    fun inspect(key: GameResourceCacheKey): GameResourceStoredInspection {
        val metadata = inspectMetadata(key)
        val entry = metadata.entry ?: return metadata
        val file = safeFile(entry.fileName)
            ?: return GameResourceStoredInspection(GameResourceStoredState.DAMAGED)
        val bytes = runCatching { file.readBytes() }.getOrNull()
        if (bytes == null || sha256(bytes) != entry.sha256) {
            return GameResourceStoredInspection(GameResourceStoredState.DAMAGED)
        }
        return metadata
    }

    @Synchronized
    fun inspectMetadata(key: GameResourceCacheKey): GameResourceStoredInspection {
        val entry = index.get(key)
            ?: return GameResourceStoredInspection(GameResourceStoredState.MISSING)
        val file = safeFile(entry.fileName)
        if (file == null || !file.isFile || file.length() != entry.byteLength) {
            return GameResourceStoredInspection(GameResourceStoredState.DAMAGED)
        }
        return GameResourceStoredInspection(GameResourceStoredState.VALID, entry)
    }

    @Synchronized
    fun markValidated(key: GameResourceCacheKey) {
        val entry = index.get(key) ?: return
        index.put(entry.copy(lastValidatedAt = clock()))
    }

    fun availableDeviceBytes(): Long = root.usableSpace

    private fun invalidate(
        key: GameResourceCacheKey,
        entry: GameResourceCacheEntry,
    ): GameResourceCachedValue? {
        index.remove(key)
        deleteIfUnreferenced(entry.fileName)
        return null
    }

    private fun deleteIfUnreferenced(fileName: String) {
        if (index.snapshot().none { it.fileName == fileName }) safeFile(fileName)?.delete()
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

    companion object {
        const val DEFAULT_MAX_BYTES: Long = 50_000_000_000L
        private const val ACCESS_TIME_WRITE_INTERVAL_MS = 60_000L
    }
}
