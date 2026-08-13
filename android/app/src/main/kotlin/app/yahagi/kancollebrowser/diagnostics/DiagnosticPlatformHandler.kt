package app.yahagi.kancollebrowser.diagnostics

import android.app.ActivityManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Debug
import android.os.Handler
import android.os.Looper
import android.provider.DocumentsContract
import android.provider.OpenableColumns
import androidx.core.content.FileProvider
import androidx.webkit.WebViewCompat
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

interface DiagnosticExportDirectoryHost {
    fun openDiagnosticExportDirectory(initialUri: Uri?)
}

internal class DiagnosticPlatformHandler(
    private val context: Context,
    private val directoryHost: DiagnosticExportDirectoryHost,
) : MethodChannel.MethodCallHandler {
    private val mainHandler = Handler(Looper.getMainLooper())
    private val ioExecutor = Executors.newSingleThreadExecutor()
    private var pendingSaveResult: MethodChannel.Result? = null
    private var pendingSaveFile: File? = null

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "deviceSnapshot" -> result.success(deviceSnapshot().toMap())
            "runtimeSnapshot" -> result.success(runtimeSnapshot())
            "saveJson" -> saveJson(call.argument<String>("path"), result)
            "shareJson" -> shareJson(call.argument<String>("path"), result)
            else -> result.notImplemented()
        }
    }

    private fun deviceSnapshot(): DiagnosticDeviceSnapshot {
        val activityManager = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val metrics = context.resources.displayMetrics
        return DiagnosticDeviceSnapshot(
            manufacturer = Build.MANUFACTURER.take(128),
            model = Build.MODEL.take(128),
            androidSdk = Build.VERSION.SDK_INT,
            androidRelease = Build.VERSION.RELEASE.take(32),
            supportedAbi = (Build.SUPPORTED_ABIS.firstOrNull() ?: "unknown").take(64),
            memoryClassMb = activityManager.memoryClass,
            screenWidthPx = metrics.widthPixels,
            screenHeightPx = metrics.heightPixels,
            webViewVersion = (WebViewCompat.getCurrentWebViewPackage(context)?.versionName ?: "unknown")
                .take(64),
        )
    }

    private fun runtimeSnapshot(): Map<String, Any> {
        val processInfo = Debug.MemoryInfo()
        Debug.getMemoryInfo(processInfo)
        val runtime = Runtime.getRuntime()
        val activityManager = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val systemInfo = ActivityManager.MemoryInfo()
        activityManager.getMemoryInfo(systemInfo)
        return linkedMapOf(
            "pssKb" to processInfo.totalPss.coerceAtLeast(0),
            "javaHeapKb" to ((runtime.totalMemory() - runtime.freeMemory()) / 1024L)
                .coerceAtLeast(0L),
            "nativeHeapKb" to (Debug.getNativeHeapAllocatedSize() / 1024L).coerceAtLeast(0L),
            "lowMemory" to systemInfo.lowMemory,
        )
    }

    private fun saveJson(path: String?, result: MethodChannel.Result) {
        if (pendingSaveResult != null) {
            result.error("save_busy", "A diagnostic save is already pending.", null)
            return
        }
        val file = validatedExport(path)
        if (file == null) {
            result.error("invalid_path", "The diagnostic export is not saveable.", null)
            return
        }
        pendingSaveResult = result
        pendingSaveFile = file
        try {
            directoryHost.openDiagnosticExportDirectory(downloadsUri())
        } catch (_: RuntimeException) {
            pendingSaveResult = null
            pendingSaveFile = null
            result.error("picker_unavailable", "Unable to open the folder picker.", null)
        }
    }

    fun onDirectorySelected(directoryUri: Uri?) {
        val result = pendingSaveResult ?: return
        val source = pendingSaveFile
        if (directoryUri == null) {
            pendingSaveResult = null
            pendingSaveFile = null
            result.success(null)
            return
        }
        if (source == null || validatedExport(source.path) == null) {
            pendingSaveResult = null
            pendingSaveFile = null
            result.error("invalid_path", "The diagnostic export is not saveable.", null)
            return
        }

        ioExecutor.execute {
            val savedName = runCatching { copyToDirectory(source, directoryUri) }
            mainHandler.post {
                if (pendingSaveResult !== result) return@post
                pendingSaveResult = null
                pendingSaveFile = null
                savedName.fold(
                    onSuccess = result::success,
                    onFailure = {
                        result.error(
                            "save_failed",
                            "Unable to save the diagnostic export.",
                            null,
                        )
                    },
                )
            }
        }
    }

    fun dispose() {
        pendingSaveResult?.error(
            "activity_destroyed",
            "The diagnostic save was cancelled.",
            null,
        )
        pendingSaveResult = null
        pendingSaveFile = null
        ioExecutor.shutdownNow()
    }

    private fun shareJson(path: String?, result: MethodChannel.Result) {
        val file = validatedExport(path)
        if (file == null) {
            result.error("invalid_path", "The diagnostic export is not shareable.", null)
            return
        }
        val uri = FileProvider.getUriForFile(context, "${context.packageName}.diagnostics", file)
        val intent = Intent(Intent.ACTION_SEND).apply {
            type = "application/json"
            putExtra(Intent.EXTRA_STREAM, uri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        context.startActivity(Intent.createChooser(intent, null).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        result.success(null)
    }

    private fun validatedExport(path: String?): File? {
        if (path == null) return null
        return runCatching {
            val root = File(context.cacheDir, "diagnostics-export").canonicalFile
            val file = File(path).canonicalFile
            val insideRoot = file.parentFile?.canonicalFile == root
            file.takeIf {
                insideRoot &&
                    it.isFile &&
                    it.extension.lowercase() == "json" &&
                    it.length() in 1..MAX_EXPORT_BYTES
            }
        }.getOrNull()
    }

    private fun copyToDirectory(source: File, directoryUri: Uri): String {
        val resolver = context.contentResolver
        val directoryDocumentId = DocumentsContract.getTreeDocumentId(directoryUri)
        val directoryDocumentUri = DocumentsContract.buildDocumentUriUsingTree(
            directoryUri,
            directoryDocumentId,
        )
        val childrenUri = DocumentsContract.buildChildDocumentsUriUsingTree(
            directoryUri,
            directoryDocumentId,
        )
        val existingNames = buildSet {
            resolver.query(
                childrenUri,
                arrayOf(OpenableColumns.DISPLAY_NAME),
                null,
                null,
                null,
            )?.use { cursor ->
                val nameIndex = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                while (nameIndex >= 0 && cursor.moveToNext()) {
                    cursor.getString(nameIndex)?.let(::add)
                }
            }
        }
        val targetName = DiagnosticExportFileName.available(source.name, existingNames)
        val targetUri = DocumentsContract.createDocument(
            resolver,
            directoryDocumentUri,
            "application/json",
            targetName,
        ) ?: error("Unable to create diagnostic export document.")
        try {
            source.inputStream().use { input ->
                val output = resolver.openOutputStream(targetUri, "w")
                    ?: error("Unable to open diagnostic export document.")
                output.use(input::copyTo)
            }
        } catch (error: Throwable) {
            runCatching { DocumentsContract.deleteDocument(resolver, targetUri) }
            throw error
        }
        return targetName
    }

    private fun downloadsUri(): Uri? = runCatching {
        DocumentsContract.buildDocumentUri(
            EXTERNAL_STORAGE_AUTHORITY,
            "primary:Download",
        )
    }.getOrNull()

    private companion object {
        const val MAX_EXPORT_BYTES = 10L * 1024L * 1024L
        const val EXTERNAL_STORAGE_AUTHORITY = "com.android.externalstorage.documents"
    }
}
