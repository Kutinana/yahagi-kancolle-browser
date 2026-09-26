package app.yahagi.kancollebrowser.backup

import android.content.Context
import androidx.core.content.FileProvider
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import java.io.File
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertNotEquals
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class BackupShareProviderTest {
    @Test
    fun providerKeepsFirstUriReadableAfterSecondSameNameShare() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        val root = File(context.cacheDir, "record-backup-share")
        val firstBytes = byteArrayOf(1, 2, 3)
        val secondBytes = byteArrayOf(4, 5, 6)
        val first = BackupShareCache.write(root, "same-name.yhb", firstBytes)
        val second = BackupShareCache.write(root, "same-name.yhb", secondBytes)
        try {
            val authority = "${context.packageName}.diagnostics"
            val firstUri = FileProvider.getUriForFile(context, authority, first)
            val secondUri = FileProvider.getUriForFile(context, authority, second)
            assertNotEquals(firstUri, secondUri)
            assertArrayEquals(
                firstBytes,
                context.contentResolver.openInputStream(firstUri)!!.use { it.readBytes() },
            )
            assertArrayEquals(
                secondBytes,
                context.contentResolver.openInputStream(secondUri)!!.use { it.readBytes() },
            )
        } finally {
            first.parentFile?.deleteRecursively()
            second.parentFile?.deleteRecursively()
        }
    }
}
