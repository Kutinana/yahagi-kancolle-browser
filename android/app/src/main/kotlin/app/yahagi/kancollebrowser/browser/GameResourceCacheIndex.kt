package app.yahagi.kancollebrowser.browser

import org.json.JSONArray
import org.json.JSONObject
import java.io.File
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
)

class GameResourceCacheIndex(private val indexFile: File) {
    private val entries = linkedMapOf<String, GameResourceCacheEntry>()
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
    fun put(entry: GameResourceCacheEntry) {
        ensureLoaded()
        entries[entry.key] = entry
        appendJournal(JSONObject().put("op", "put").put("entry", entry.toJson()))
    }

    @Synchronized
    fun remove(key: GameResourceCacheKey): GameResourceCacheEntry? {
        ensureLoaded()
        val removed = entries.remove(key.value) ?: return null
        appendJournal(JSONObject().put("op", "remove").put("key", key.value))
        return removed
    }

    @Synchronized
    fun clear() {
        ensureLoaded()
        journalFile.parentFile?.mkdirs()
        journalFile.appendText(JSONObject().put("op", "clear").toString() + "\n")
        entries.clear()
        if (journalFile.length() >= MAX_JOURNAL_BYTES) {
            save()
            journalFile.delete()
        }
    }

    private fun ensureLoaded() {
        if (loaded) return
        loaded = true
        if (indexFile.isFile) {
            runCatching {
                val array = JSONObject(indexFile.readText()).optJSONArray("entries") ?: JSONArray()
                for (index in 0 until array.length()) {
                    val entry = array.getJSONObject(index).toEntry()
                    entries[entry.key] = entry
                }
            }.onFailure {
                entries.clear()
            }
        }
        if (!journalFile.isFile) return
        journalFile.forEachLine { line ->
            runCatching {
                val operation = JSONObject(line)
                when (operation.optString("op")) {
                    "put" -> operation.getJSONObject("entry").toEntry().also {
                        entries[it.key] = it
                    }
                    "remove" -> entries.remove(operation.getString("key"))
                    "clear" -> entries.clear()
                }
            }
        }
    }

    private fun appendJournal(operation: JSONObject) {
        journalFile.parentFile?.mkdirs()
        journalFile.appendText(operation.toString() + "\n")
        if (journalFile.length() >= MAX_JOURNAL_BYTES) {
            save()
            journalFile.delete()
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
