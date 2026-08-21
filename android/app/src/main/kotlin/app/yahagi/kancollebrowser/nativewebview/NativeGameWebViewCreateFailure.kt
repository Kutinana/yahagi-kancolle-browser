package app.yahagi.kancollebrowser.nativewebview

import android.content.Context
import android.os.Build
import android.util.Log
import androidx.webkit.WebViewCompat

internal enum class NativeGameWebViewCreateStage(val wireName: String) {
    CREATE_OVERLAY("create_overlay"),
    ATTACH_OVERLAY("attach_overlay"),
    CREATE_WEB_VIEW("create_web_view"),
    CONFIGURE_WEB_VIEW("configure_web_view"),
    ATTACH_WEB_VIEW("attach_web_view"),
    MARK_READY("mark_ready"),
}

internal class NativeGameWebViewCreateException(
    val stage: NativeGameWebViewCreateStage,
    cause: Throwable,
    val webViewPackage: String,
    val webViewVersion: String,
    val sdkInt: Int,
) : RuntimeException(
    "Native WebView creation failed at ${stage.wireName} (${cause.javaClass.simpleName}).",
    cause,
) {
    val safeDetails: Map<String, Any?>
        get() = mapOf(
            "stage" to stage.wireName,
            "exceptionType" to (cause?.javaClass?.simpleName ?: "Unknown"),
            "webViewPackage" to webViewPackage,
            "webViewVersion" to webViewVersion,
            "sdkInt" to sdkInt,
        )
}

internal object NativeGameWebViewCreateFailureReporter {
    private const val TAG = "YahagiNativeWebView"

    fun report(
        context: Context,
        stage: NativeGameWebViewCreateStage,
        cause: Throwable,
    ): NativeGameWebViewCreateException {
        val provider = runCatching {
            WebViewCompat.getCurrentWebViewPackage(context)
        }.getOrNull()
        val failure = NativeGameWebViewCreateException(
            stage = stage,
            cause = cause,
            webViewPackage = provider?.packageName ?: "unknown",
            webViewVersion = provider?.versionName ?: "unknown",
            sdkInt = Build.VERSION.SDK_INT,
        )
        Log.e(
            TAG,
            "create failed stage=${stage.wireName} " +
                "provider=${failure.webViewPackage}/${failure.webViewVersion} " +
                "sdk=${failure.sdkInt}",
            cause,
        )
        return failure
    }
}
