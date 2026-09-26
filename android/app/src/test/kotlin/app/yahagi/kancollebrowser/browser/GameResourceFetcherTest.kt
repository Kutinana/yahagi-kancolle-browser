package app.yahagi.kancollebrowser.browser

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.ByteArrayInputStream

class GameResourceFetcherTest {
    @get:Rule val temporaryFolder = TemporaryFolder()

    @Test
    fun `download streams body into a temporary file`() {
        val bytes = ByteArray(64 * 1024) { it.toByte() }
        val file = HttpUrlConnectionGameResourceFetcher.downloadToTemporaryFile(
            ByteArrayInputStream(bytes), bytes.size.toLong(), bytes.size.toLong(),
            temporaryFolder.root,
        )

        assertArrayEquals(bytes, file?.readBytes())
        assertEquals(1, temporaryFolder.root.listFiles()?.size)
    }

    @Test
    fun `oversized or truncated body leaves no temporary file`() {
        val bytes = ByteArray(1024)
        assertNull(HttpUrlConnectionGameResourceFetcher.downloadToTemporaryFile(
            ByteArrayInputStream(bytes), -1, 512, temporaryFolder.root,
        ))
        assertNull(HttpUrlConnectionGameResourceFetcher.downloadToTemporaryFile(
            ByteArrayInputStream(bytes), 2048, 2048, temporaryFolder.root,
        ))
        assertTrue(temporaryFolder.root.listFiles().orEmpty().isEmpty())
    }
}
