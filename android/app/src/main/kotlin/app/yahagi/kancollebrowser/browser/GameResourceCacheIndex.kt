package app.yahagi.kancollebrowser.browser

import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.io.RandomAccessFile
import java.nio.file.Files
import java.nio.file.StandardCopyOption

data class GameResourceCacheEntry(
    val key: String,
    val fileName: String,
    val version: String?,
    val mimeType: String,
    val byteLength: Long,
    val etag: String?,
    val lastModified: String?,
    val lastAccessedAt: Long,
    val lastValidatedAt: Long,
    val sha256: String,
    val responseHeaders: Map<String, String> = emptyMap(),
)

class GameResourceCacheIndex(private val indexFile: File) {
    private val entries = linkedMapOf<String, GameResourceCacheEntry>()
    private val fileReferenceCounts = hashMapOf<String, Int>()
    private var cachedTotalBytes = 0L
    private val journalFile = File(indexFile.parentFile, "${indexFile.name}.journal")
    private var loaded = false

    @Synchronized
    fun get(key: GameResourceCacheKey): GameResourceCacheEntry? {
        ensureLoaded()
        return entries[key.value]
    }

    @Synchronized
    fun snapshot(): List<GameResourceCacheEntry> {
        ensureLoaded()
        return entries.values.toList()
    }

    @Synchronized
    fun totalBytes(): Long {
        ensureLoaded()
        return cachedTotalBytes
    }

    @Synchronized
    fun put(entry: GameResourceCacheEntry) {
        ensureLoaded()
        appendJournalRecord(JSONObject().put("op", "put").put("entry", entry.toJson()))
        entries[entry.key]?.let {
            decrementFileReference(it.fileName)
            cachedTotalBytes -= it.byteLength
        }
        entries[entry.key] = entry
        incrementFileReference(entry.fileName)
        cachedTotalBytes += entry.byteLength
        compactJournalIfNeeded()
    }

    @Synchronized
    fun remove(key: GameResourceCacheKey): GameResourceCacheEntry? {
        ensureLoaded()
        val removed = entries[key.value] ?: return null
        appendJournalRecord(JSONObject().put("op", "remove").put("key", key.value))
        entries.remove(key.value)
        decrementFileReference(removed.fileName)
        cachedTotalBytes -= removed.byteLength
        compactJournalIfNeeded()
        return removed
    }

    @Synchronized
    fun isFileReferenced(fileName: String): Boolean {
        ensureLoaded()
        return (fileReferenceCounts[fileName] ?: 0) > 0
    }

    @Synchronized
    fun fileReferenceCount(fileName: String): Int {
        ensureLoaded()
        return fileReferenceCounts[fileName] ?: 0
    }

    @Synchronized
    fun removePrefix(prefix: String): List<GameResourceCacheEntry> {
        ensureLoaded()
        val removed = entries.values.filter { it.key.startsWith(prefix) }
        if (removed.isEmpty()) return emptyList()
        appendJournalRecord(JSONObject().put("op", "removePrefix").put("prefix", prefix))
        removed.forEach {
            entries.remove(it.key)
            decrementFileReference(it.fileName)
            cachedTotalBytes -= it.byteLength
        }
        compactJournalIfNeeded()
        return removed
    }

    @Synchronized
    fun clear() {
        ensureLoaded()
        appendJournalRecord(JSONObject().put("op", "clear"))
        entries.clear()
        fileReferenceCounts.clear()
        cachedTotalBytes = 0L
        compactJournalIfNeeded()
    }

    private fun ensureLoaded() {
        if (loaded) return
        try {
            if (indexFile.isFile) {
                val source = indexFile.readText()
                runCatching {
                    val array = JSONObject(source).optJSONArray("entries") ?: JSONArray()
                    for (index in 0 until array.length()) {
                        val entry = array.getJSONObject(index).toEntry()
                        entries[entry.key] = entry
                    }
                }.onFailure {
                    entries.clear()
                }
            }
            if (journalFile.isFile) replayJournal()
            rebuildFileReferences()
            loaded = true
        } catch (error: Exception) {
            loaded = false
            entries.clear()
            fileReferenceCounts.clear()
            cachedTotalBytes = 0L
            throw error
        }
    }

    private fun replayJournal() {
        val bytes = journalFile.readBytes()
        var offset = 0
        while (offset < bytes.size) {
            val end = bytes.indexOf('\n'.code.toByte(), offset)
            if (end < 0) break
            val line = String(bytes, offset, end - offset, Charsets.UTF_8)
            val applied = runCatching {
                val operation = JSONObject(line)
                when (operation.getString("op")) {
                    "put" -> operation.getJSONObject("entry").toEntry().also {
                        entries[it.key] = it
                    }
                    "remove" -> entries.remove(operation.getString("key"))
                    "removePrefix" -> {
                        val prefix = operation.getString("prefix")
                        entries.keys.removeAll { it.startsWith(prefix) }
                    }
                    "clear" -> entries.clear()
                    else -> error("Unknown resource cache journal operation")
                }
            }.isSuccess
            if (!applied) break
            offset = end + 1
        }
        if (offset != bytes.size) {
            RandomAccessFile(journalFile, "rw").use { it.setLength(offset.toLong()) }
        }
    }

    private fun ByteArray.indexOf(value: Byte, fromIndex: Int): Int {
        for (index in fromIndex until size) {
            if (this[index] == value) return index
        }
        return -1
    }

    private fun appendJournalRecord(operation: JSONObject) {
        try {
            journalFile.parentFile?.mkdirs()
            journalFile.appendText(operation.toString() + "\n")
        } catch (error: Exception) {
            // Reload on the next call so a partial tail is truncated before retry.
            loaded = false
            entries.clear()
            fileReferenceCounts.clear()
            cachedTotalBytes = 0L
            throw error
        }
    }

    private fun compactJournalIfNeeded() {
        if (journalFile.length() >= MAX_JOURNAL_BYTES) {
            save()
            if (!journalFile.delete()) {
                throw IllegalStateException("Cannot compact resource cache journal")
            }
        }
    }

    private fun incrementFileReference(fileName: String) {
        fileReferenceCounts[fileName] = (fileReferenceCounts[fileName] ?: 0) + 1
    }

    private fun decrementFileReference(fileName: String) {
        val count = fileReferenceCounts[fileName] ?: return
        if (count <= 1) fileReferenceCounts.remove(fileName)
        else fileReferenceCounts[fileName] = count - 1
    }

    private fun rebuildFileReferences() {
        fileReferenceCounts.clear()
        cachedTotalBytes = 0L
        entries.values.forEach {
            incrementFileReference(it.fileName)
            cachedTotalBytes += it.byteLength
        }
    }

    private fun save() {
        indexFile.parentFile?.mkdirs()
        val array = JSONArray()
        entries.values.forEach { array.put(it.toJson()) }
        val temporary = File(indexFile.parentFile, "${indexFile.name}.tmp")
        temporary.writeText(JSONObject().put("version", 1).put("entries", array).toString())
        atomicReplace(temporary, indexFile)
    }

    private fun JSONObject.nullableString(name: String): String? =
        if (isNull(name)) null else optString(name).takeIf { it.isNotEmpty() }

    private fun JSONObject.toEntry() = GameResourceCacheEntry(
        key = getString("key"),
        fileName = getString("fileName"),
        version = nullableString("version"),
        mimeType = getString("mimeType"),
        byteLength = getLong("byteLength"),
        etag = nullableString("etag"),
        lastModified = nullableString("lastModified"),
        lastAccessedAt = getLong("lastAccessedAt"),
        lastValidatedAt = optLong("lastValidatedAt", 0L),
        sha256 = getString("sha256"),
        responseHeaders = optJSONObject("responseHeaders")?.let { headers ->
            headers.keys().asSequence().associateWith(headers::getString)
        }.orEmpty(),
    )

    private fun GameResourceCacheEntry.toJson() = JSONObject()
        .put("key", key)
        .put("fileName", fileName)
        .put("version", version ?: JSONObject.NULL)
        .put("mimeType", mimeType)
        .put("byteLength", byteLength)
        .put("etag", etag ?: JSONObject.NULL)
        .put("lastModified", lastModified ?: JSONObject.NULL)
        .put("lastAccessedAt", lastAccessedAt)
        .put("lastValidatedAt", lastValidatedAt)
        .put("sha256", sha256)
        .put("responseHeaders", JSONObject(responseHeaders))

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

    companion object {
        private const val MAX_JOURNAL_BYTES = 4L * 1024L * 1024L
    }
}
