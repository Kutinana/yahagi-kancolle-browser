package app.yahagi.kancollebrowser.backup

import java.nio.file.Files
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertNotEquals
import org.junit.Test

class BackupShareCacheTest {
    @Test
    fun sameNameExportsKeepIndependentImmutableFiles() {
        val root = Files.createTempDirectory("backup-share-test").toFile()
        try {
            val firstBytes = byteArrayOf(1, 2, 3)
            val secondBytes = byteArrayOf(4, 5, 6)
            val first = BackupShareCache.write(root, "admiral-server-time.yhb", firstBytes)
            val second = BackupShareCache.write(root, "admiral-server-time.yhb", secondBytes)
            assertNotEquals(first.absolutePath, second.absolutePath)
            assertArrayEquals(firstBytes, first.readBytes())
            assertArrayEquals(secondBytes, second.readBytes())
        } finally {
            root.deleteRecursively()
        }
    }
}
