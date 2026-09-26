package app.yahagi.kancollebrowser.backup

import android.app.Activity
import android.content.Intent
import android.net.Uri
import androidx.core.content.FileProvider
import androidx.test.core.app.ActivityScenario
import androidx.test.ext.junit.runners.AndroidJUnit4
import app.yahagi.kancollebrowser.MainActivity
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class BackupSavePickerTest {
    private class Result : MethodChannel.Result {
        private val latch = CountDownLatch(1)
        var value: Any? = null
        var errorCode: String? = null

        override fun success(result: Any?) {
            value = result
            latch.countDown()
        }

        override fun error(code: String, message: String?, details: Any?) {
            errorCode = code
            latch.countDown()
        }

        override fun notImplemented() {
            errorCode = "not_implemented"
            latch.countDown()
        }

        fun await(): Any? {
            assertTrue("MethodChannel result timed out", latch.await(10, TimeUnit.SECONDS))
            return value
        }
    }

    @Test
    fun localPickerUsesCreateDocumentAndCancellationCreatesNoTarget() {
        ActivityScenario.launch(MainActivity::class.java).use { scenario ->
            val result = Result()
            var launched: Intent? = null
            scenario.onActivity { activity ->
                val handler = RecordBackupHandler(activity, { intent, code ->
                    assertEquals(RecordBackupHandler.SAVE_REQUEST, code)
                    launched = intent
                })
                handler.onMethodCall(
                    MethodCall("pickSaveLocation", mapOf("name" to "admiral-server-time.yhb")),
                    result,
                )
                assertEquals(Intent.ACTION_CREATE_DOCUMENT, launched?.action)
                assertEquals("admiral-server-time.yhb", launched?.getStringExtra(Intent.EXTRA_TITLE))
                handler.onActivityResult(RecordBackupHandler.SAVE_REQUEST, Activity.RESULT_CANCELED, null)
                handler.dispose()
            }
            assertNull(result.await())
            assertNull(result.errorCode)
        }
    }

    @Test
    fun verifiedSaveWritesSelectedUri() {
        ActivityScenario.launch(MainActivity::class.java).use { scenario ->
            lateinit var handler: RecordBackupHandler
            lateinit var file: File
            lateinit var uri: Uri
            val picked = Result()
            scenario.onActivity { activity ->
                file = BackupShareCache.write(
                    File(activity.cacheDir, "record-backup-share"),
                    "save-probe.yhb",
                    byteArrayOf(0),
                )
                uri = FileProvider.getUriForFile(
                    activity, "${activity.packageName}.diagnostics", file,
                )
                handler = RecordBackupHandler(activity, { _, _ -> })
                handler.onMethodCall(MethodCall("pickSaveLocation", mapOf("name" to "save-probe.yhb")), picked)
                handler.onActivityResult(
                    RecordBackupHandler.SAVE_REQUEST,
                    Activity.RESULT_OK,
                    Intent().setData(uri),
                )
            }
            val token = picked.await() as String
            val written = Result()
            val bytes = byteArrayOf(1, 2, 3, 4)
            scenario.onActivity {
                handler.onMethodCall(
                    MethodCall("writeSavedFile", mapOf("token" to token, "bytes" to bytes)),
                    written,
                )
            }
            written.await()
            assertNull(written.errorCode)
            val completed = Result()
            scenario.onActivity {
                handler.onMethodCall(MethodCall("completeSavedFile", mapOf("token" to token)), completed)
            }
            completed.await()
            assertNull(completed.errorCode)
            assertArrayEquals(bytes, file.readBytes())
            scenario.onActivity { handler.dispose() }
            file.parentFile?.deleteRecursively()
        }
    }

    @Test
    fun failedDocumentDeletionDoesNotBlockTheNextPicker() {
        ActivityScenario.launch(MainActivity::class.java).use { scenario ->
            lateinit var handler: RecordBackupHandler
            var launches = 0
            val picked = Result()
            scenario.onActivity { activity ->
                handler = RecordBackupHandler(
                    activity,
                    { _, _ -> launches++ },
                    deleteSavedDocument = { false },
                )
                handler.onMethodCall(MethodCall("pickSaveLocation", mapOf("name" to "first.yhb")), picked)
                handler.onActivityResult(
                    RecordBackupHandler.SAVE_REQUEST,
                    Activity.RESULT_OK,
                    Intent().setData(Uri.parse("content://example.test/denied")),
                )
            }
            val token = picked.await() as String
            val discarded = Result()
            scenario.onActivity {
                handler.onMethodCall(MethodCall("discardSavedFile", mapOf("token" to token)), discarded)
            }
            discarded.await()
            assertEquals("backup_save_failed", discarded.errorCode)

            val next = Result()
            scenario.onActivity {
                handler.onMethodCall(MethodCall("pickSaveLocation", mapOf("name" to "second.yhb")), next)
                assertEquals(2, launches)
                handler.onActivityResult(RecordBackupHandler.SAVE_REQUEST, Activity.RESULT_CANCELED, null)
                handler.dispose()
            }
            assertNull(next.await())
            assertNull(next.errorCode)
        }
    }

    @Test
    fun preparedShareCanBeDiscardedBeforeOpeningTheSharesheet() {
        ActivityScenario.launch(MainActivity::class.java).use { scenario ->
            val name = "discard-${System.nanoTime()}.yhb"
            lateinit var handler: RecordBackupHandler
            lateinit var root: File
            val prepared = Result()
            scenario.onActivity { activity ->
                root = File(activity.cacheDir, "record-backup-share")
                handler = RecordBackupHandler(activity, { _, _ -> })
                handler.onMethodCall(
                    MethodCall(
                        "prepareShareFile",
                        mapOf("name" to name, "bytes" to byteArrayOf(7, 8)),
                    ),
                    prepared,
                )
            }
            val token = prepared.await() as String
            assertNull(prepared.errorCode)
            val preparedFile = root.walkTopDown().first { it.isFile && it.name == name }
            assertArrayEquals(byteArrayOf(7, 8), preparedFile.readBytes())
            val discarded = Result()
            scenario.onActivity {
                handler.onMethodCall(MethodCall("discardShareFile", mapOf("token" to token)), discarded)
            }
            discarded.await()
            assertNull(discarded.errorCode)
            assertFalse(preparedFile.exists())
            scenario.onActivity { handler.dispose() }
        }
    }
}
