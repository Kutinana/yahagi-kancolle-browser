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

    init {
        load()
    }

    @Synchronized
    fun get(key: GameResourceCacheKey): GameResourceCacheEntry? = entries[key.value]

    @Synchronized
    fun snapshot(): List<GameResourceCacheEntry> = entries.values.toList()

    @Synchronized
    fun put(entry: GameResourceCacheEntry) {
        entries[entry.key] = entry
        save()
    }

    @Synchronized
    fun remove(key: GameResourceCacheKey): GameResourceCacheEntry? {
        val removed = entries.remove(key.value) ?: return null
        save()
        return removed
    }

    @Synchronized
    fun clear() {
        entries.clear()
        save()
    }

    private fun load() {
        if (!indexFile.isFile) return
        runCatching {
            val array = JSONObject(indexFile.readText()).optJSONArray("entries") ?: JSONArray()
            for (index in 0 until array.length()) {
                val item = array.getJSONObject(index)
                val entry = GameResourceCacheEntry(
                    key = item.getString("key"),
                    fileName = item.getString("fileName"),
                    version = item.nullableString("version"),
                    mimeType = item.getString("mimeType"),
                    byteLength = item.getLong("byteLength"),
                    etag = item.nullableString("etag"),
                    lastModified = item.nullableString("lastModified"),
                    lastAccessedAt = item.getLong("lastAccessedAt"),
                    lastValidatedAt = item.optLong("lastValidatedAt", 0L),
                    sha256 = item.getString("sha256"),
                )
                entries[entry.key] = entry
            }
        }.onFailure {
            entries.clear()
        }
    }

    private fun save() {
        indexFile.parentFile?.mkdirs()
        val array = JSONArray()
        entries.values.forEach { entry ->
            array.put(
                JSONObject()
                    .put("key", entry.key)
                    .put("fileName", entry.fileName)
                    .put("version", entry.version ?: JSONObject.NULL)
                    .put("mimeType", entry.mimeType)
                    .put("byteLength", entry.byteLength)
                    .put("etag", entry.etag ?: JSONObject.NULL)
                    .put("lastModified", entry.lastModified ?: JSONObject.NULL)
                    .put("lastAccessedAt", entry.lastAccessedAt)
                    .put("lastValidatedAt", entry.lastValidatedAt)
                    .put("sha256", entry.sha256),
            )
        }
        val temporary = File(indexFile.parentFile, "${indexFile.name}.tmp")
        temporary.writeText(JSONObject().put("version", 1).put("entries", array).toString())
        atomicReplace(temporary, indexFile)
    }

    private fun JSONObject.nullableString(name: String): String? =
        if (isNull(name)) null else optString(name).takeIf { it.isNotEmpty() }

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
}
