package app.yahagi.kancollebrowser.browser

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder

class GameResourceCacheIndexTest {
    @get:Rule
    val temporaryFolder = TemporaryFolder()

    @Test
    fun `updates use an append journal and survive reload`() {
        val root = temporaryFolder.newFolder()
        val indexFile = root.resolve("index.json")
        val index = GameResourceCacheIndex(indexFile)

        repeat(1_000) { id -> index.put(entry(id)) }

        val journal = root.resolve("index.json.journal")
        assertTrue(journal.isFile)
        assertFalse(indexFile.isFile)
        assertEquals(1_000, GameResourceCacheIndex(indexFile).snapshot().size)
    }

    @Test
    fun `journal tombstones survive reload without rewriting snapshot`() {
        val root = temporaryFolder.newFolder()
        val indexFile = root.resolve("index.json")
        val index = GameResourceCacheIndex(indexFile)
        index.put(entry(1))
        index.put(entry(2))

        index.remove(GameResourceCacheKey(entry(1).key))

        val reloaded = GameResourceCacheIndex(indexFile)
        assertEquals(listOf(entry(2).key), reloaded.snapshot().map { it.key })
    }

    @Test
    fun `clear journal prevents old entries from returning after reload`() {
        val root = temporaryFolder.newFolder()
        val indexFile = root.resolve("index.json")
        val index = GameResourceCacheIndex(indexFile)
        index.put(entry(1))
        index.put(entry(2))

        index.clear()

        assertTrue(GameResourceCacheIndex(indexFile).snapshot().isEmpty())
        assertTrue(root.resolve("index.json.journal").readText().contains("\"op\":\"clear\""))
    }

    @Test
    fun `response security headers survive index reload`() {
        val indexFile = temporaryFolder.newFolder().resolve("index.json")
        val entry = entry(1).copy(responseHeaders = mapOf(
            "Content-Security-Policy" to "default-src 'none'",
        ))
        GameResourceCacheIndex(indexFile).put(entry)

        assertEquals(
            "default-src 'none'",
            GameResourceCacheIndex(indexFile).snapshot().single().responseHeaders["Content-Security-Policy"],
        )
    }

    @Test
    fun `truncated journal tail is discarded before a new record is appended`() {
        val root = temporaryFolder.newFolder()
        val indexFile = root.resolve("index.json")
        val journal = root.resolve("index.json.journal")
        journal.writeText("{\"op\":\"put\"")
        val index = GameResourceCacheIndex(indexFile)

        assertTrue(index.snapshot().isEmpty())
        index.put(entry(1))

        assertEquals(listOf(entry(1).key), GameResourceCacheIndex(indexFile).snapshot().map { it.key })
        assertEquals(1, journal.readLines().count { it.isNotBlank() })
    }

    @Test
    fun `failed journal append does not change in memory index`() {
        val root = temporaryFolder.newFolder()
        val journal = root.resolve("index.json.journal")
        assertTrue(journal.mkdir())
        journal.resolve("child").writeText("nonempty")
        val index = GameResourceCacheIndex(root.resolve("index.json"))

        assertTrue(runCatching { index.put(entry(1)) }.isFailure)
        assertTrue(index.snapshot().isEmpty())
        assertEquals(0L, index.totalBytes())
    }

    @Test
    fun `reference counts and byte totals track replacements and removals`() {
        val index = GameResourceCacheIndex(temporaryFolder.newFolder().resolve("index.json"))
        index.put(entry(1).copy(fileName = "shared.cache", byteLength = 3))
        index.put(entry(2).copy(fileName = "shared.cache", byteLength = 5))
        assertEquals(8L, index.totalBytes())
        index.remove(GameResourceCacheKey(entry(1).key))
        assertTrue(index.isFileReferenced("shared.cache"))
        index.remove(GameResourceCacheKey(entry(2).key))
        assertFalse(index.isFileReferenced("shared.cache"))
        assertEquals(0L, index.totalBytes())
    }

    private fun entry(id: Int) = GameResourceCacheEntry(
        key = "/kcs2/resources/$id.png",
        fileName = "$id.cache",
        version = null,
        mimeType = "image/png",
        byteLength = 1,
        etag = null,
        lastModified = null,
        lastAccessedAt = id.toLong(),
        lastValidatedAt = id.toLong(),
        sha256 = id.toString(),
    )
}
