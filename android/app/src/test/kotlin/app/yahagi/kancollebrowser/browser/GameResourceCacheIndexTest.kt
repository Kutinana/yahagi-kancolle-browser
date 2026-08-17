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
