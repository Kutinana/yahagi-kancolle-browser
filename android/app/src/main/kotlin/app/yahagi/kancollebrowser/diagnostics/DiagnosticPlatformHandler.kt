package app.yahagi.kancollebrowser.diagnostics

import android.app.ActivityManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Debug
import androidx.core.content.FileProvider
import androidx.webkit.WebViewCompat
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

internal class DiagnosticPlatformHandler(
    private val context: Context,
) : MethodChannel.MethodCallHandler {
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "deviceSnapshot" -> result.success(deviceSnapshot().toMap())
            "runtimeSnapshot" -> result.success(runtimeSnapshot())
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

    private fun shareJson(path: String?, result: MethodChannel.Result) {
        if (path == null) {
            result.error("invalid_path", "Missing diagnostic export path.", null)
            return
        }
        val root = File(context.cacheDir, "diagnostics-export").canonicalFile
        val file = File(path).canonicalFile
        val insideRoot = file.parentFile?.canonicalFile == root
        if (!insideRoot || !file.isFile || file.extension.lowercase() != "json" || file.length() > MAX_EXPORT_BYTES) {
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

    private companion object {
        const val MAX_EXPORT_BYTES = 10L * 1024L * 1024L
    }
}
