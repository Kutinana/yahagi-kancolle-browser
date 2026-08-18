package app.yahagi.kancollebrowser.nativewebview

import android.content.SharedPreferences
import android.webkit.CookieManager
import android.webkit.WebStorage
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.net.URI
import java.util.UUID

internal interface NativeGameWebViewHostOperations {
    val currentGeneration: Long?

    fun create(): Long?
    fun setBounds(generation: Long, bounds: NativeGameWebViewBounds): Boolean
    fun setVisible(generation: Long, visible: Boolean): Boolean
    fun loadUri(uri: String)
    fun showLocalHome()
    fun reload()
    fun canGoBack(): Boolean
    fun goBack()
    fun runJavaScript(javascript: String)
    fun fitGameScreen()
    fun clearCache()
    fun clearSession()
    fun destroy(generation: Long): Boolean
}

internal class ActivityNativeGameWebViewHostOperations(
    private val host: ActivityWebViewHost,
) : NativeGameWebViewHostOperations {
    override val currentGeneration: Long?
        get() = host.currentGeneration

    override fun create(): Long? = host.create()

    override fun setBounds(generation: Long, bounds: NativeGameWebViewBounds): Boolean =
        host.setBounds(generation, bounds)

    override fun setVisible(generation: Long, visible: Boolean): Boolean =
        host.setVisible(generation, visible)

    override fun loadUri(uri: String) {
        requireWebView().loadUrl(uri)
    }

    override fun showLocalHome() {
        requireWebView().loadDataWithBaseURL(
            LOCAL_HOME_BASE_URL,
            LOCAL_HOME_HTML,
            "text/html",
            "UTF-8",
            null,
        )
    }

    override fun reload() {
        requireWebView().reload()
    }

    override fun canGoBack(): Boolean = requireWebView().canGoBack()

    override fun goBack() {
        requireWebView().goBack()
    }

    override fun runJavaScript(javascript: String) {
        requireWebView().evaluateJavascript(javascript, null)
    }

    override fun fitGameScreen() {
        requireWebView().evaluateJavascript(
            "window.__yahagiMobileSyncPresentation?.();",
            null,
        )
    }

    override fun clearCache() {
        requireWebView().clearCache(true)
    }

    override fun clearSession() {
        CookieManager.getInstance().apply {
            removeAllCookies(null)
            flush()
        }
        WebStorage.getInstance().deleteAllData()
        requireWebView().apply {
            clearFormData()
            clearHistory()
            clearCache(true)
        }
    }

    override fun destroy(generation: Long): Boolean = host.destroy(generation)

    private fun requireWebView() = checkNotNull(host.currentWebView) {
        "Native game WebView is not ready"
    }

    private companion object {
        const val LOCAL_HOME_BASE_URL = "https://localhost/"
        const val LOCAL_HOME_HTML = "<html><body style=\"background:#000\"></body></html>"
    }
}

internal interface NativeGameWebViewLifecycleObserver {
    fun onPageFinished() = Unit
    fun onRenderProcessGone() = Unit
    fun onCreateFailed() = Unit
}

internal object NoOpNativeGameWebViewLifecycleObserver : NativeGameWebViewLifecycleObserver

internal class NativeWebViewActivityStartupCoordinator(
    private val guard: NativeWebViewStartupGuard,
    private val nowMs: () -> Long,
    private val scheduleTimeout: (Long, () -> Unit) -> Unit,
    private val cancelTimeout: () -> Unit,
    private val requestRestart: () -> Unit,
) : NativeGameWebViewLifecycleObserver {
    private var timeoutVersion = 0L
    private var hasScheduledTimeout = false
    private var restartRequested = false

    fun begin(storedMode: String?): Boolean {
        if (storedMode != NATIVE_ACTIVITY_RENDERING_MODE) return false
        return when (val decision = guard.beginAttempt(nowMs())) {
            is NativeWebViewStartupDecision.Started -> {
                schedule(NativeWebViewStartupGuard.STARTUP_TIMEOUT_MS)
                true
            }
            is NativeWebViewStartupDecision.AlreadyInProgress -> {
                schedule(decision.remainingMs)
                true
            }
            NativeWebViewStartupDecision.FallbackTriggered -> {
                requestRestartOnce()
                false
            }
            else -> false
        }
    }

    override fun onPageFinished() {
        cancelScheduledTimeout()
        handleTerminalDecision(guard.recordPageFinished())
    }

    override fun onRenderProcessGone() {
        cancelScheduledTimeout()
        handleTerminalDecision(guard.recordRenderProcessGone())
    }

    override fun onCreateFailed() = onRenderProcessGone()

    fun close() {
        cancelScheduledTimeout()
    }

    private fun schedule(delayMs: Long) {
        if (hasScheduledTimeout) cancelTimeout()
        hasScheduledTimeout = true
        val version = ++timeoutVersion
        scheduleTimeout(delayMs.coerceAtLeast(0L)) {
            if (version != timeoutVersion) return@scheduleTimeout
            when (val decision = guard.recordStartupTimeout(nowMs())) {
                is NativeWebViewStartupDecision.NotTimedOut -> schedule(decision.remainingMs)
                else -> handleTerminalDecision(decision)
            }
        }
    }

    private fun cancelScheduledTimeout() {
        timeoutVersion++
        if (hasScheduledTimeout) {
            hasScheduledTimeout = false
            cancelTimeout()
        }
    }

    private fun handleTerminalDecision(decision: NativeWebViewStartupDecision) {
        if (decision == NativeWebViewStartupDecision.FallbackTriggered) {
            requestRestartOnce()
        }
    }

    private fun requestRestartOnce() {
        if (restartRequested) return
        restartRequested = true
        requestRestart()
    }

    companion object {
        const val NATIVE_ACTIVITY_RENDERING_MODE = "nativeActivityExperimental"
    }
}

internal class NativeGameWebViewChannel(
    private val dispatchToMain: ((() -> Unit) -> Unit),
    private val lifecycleObserver: NativeGameWebViewLifecycleObserver =
        NoOpNativeGameWebViewLifecycleObserver,
) : MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler,
    NativeGameWebViewEventSink {
    private var host: NativeGameWebViewHostOperations? = null
    private var eventSink: EventChannel.EventSink? = null
    private var acceptedGeneration: Long? = null
    private var destroyed = false

    fun attachHost(host: NativeGameWebViewHostOperations) {
        check(!destroyed) { "Native game WebView channel is destroyed" }
        check(this.host == null) { "Native game WebView host is already attached" }
        this.host = host
    }

    fun disable() {
        destroyed = true
        acceptedGeneration = null
        eventSink = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method !in SUPPORTED_METHODS) {
            result.notImplemented()
            return
        }
        try {
            dispatchToMain {
                if (destroyed) {
                    result.error(ACTIVITY_DESTROYED, "The Activity has been destroyed.", null)
                    return@dispatchToMain
                }
                val activeHost = host
                if (activeHost == null) {
                    result.error(HOST_UNAVAILABLE, "The native WebView host is unavailable.", null)
                    return@dispatchToMain
                }
                try {
                    handleOnMain(call, result, activeHost)
                } catch (error: InvalidArgumentsException) {
                    result.error(INVALID_ARGUMENT, error.message, null)
                } catch (error: Exception) {
                    result.error(HOST_ERROR, error.message ?: "Native WebView operation failed.", null)
                }
            }
        } catch (error: Exception) {
            result.error(HOST_ERROR, error.message ?: "Unable to dispatch native WebView operation.", null)
        }
    }

    private fun handleOnMain(
        call: MethodCall,
        result: MethodChannel.Result,
        host: NativeGameWebViewHostOperations,
    ) {
        val arguments = strictMap(call.arguments)
        if (call.method == "create") {
            requireExactKeys(arguments, setOf("renderer"))
            if (arguments["renderer"] != "webgl") invalid("renderer must be webgl")
            host.currentGeneration?.let { oldGeneration ->
                if (!host.destroy(oldGeneration)) {
                    throw IllegalStateException("Unable to destroy the previous native WebView")
                }
            }
            val generation = host.create()
            if (generation == null || generation < 0L) {
                safeObserverCall(lifecycleObserver::onCreateFailed)
                throw IllegalStateException("Unable to create the native WebView")
            }
            acceptedGeneration = generation
            result.success(generation)
            return
        }

        val generation = requireGeneration(arguments)
        if (host.currentGeneration != generation || acceptedGeneration != generation) {
            result.error(STALE_GENERATION, "The native WebView generation is stale.", null)
            return
        }

        when (call.method) {
            "setBounds" -> {
                requireExactKeys(arguments, setOf("generationId", "bounds"))
                val bounds = parseBounds(arguments["bounds"])
                host.setBounds(generation, bounds)
                result.success(null)
            }
            "setVisible" -> {
                requireExactKeys(arguments, setOf("generationId", "visible"))
                val visible = arguments["visible"] as? Boolean ?: invalid("visible must be a boolean")
                host.setVisible(generation, visible)
                result.success(null)
            }
            "loadUri" -> {
                requireExactKeys(arguments, setOf("generationId", "uri"))
                val uri = arguments["uri"] as? String ?: invalid("uri must be a string")
                if (!isSafeWebUri(uri)) invalid("uri must be an absolute HTTP(S) URI")
                host.loadUri(uri)
                result.success(null)
            }
            "showLocalHome" -> exactGenerationOnly(arguments, result) { host.showLocalHome() }
            "reload" -> exactGenerationOnly(arguments, result) { host.reload() }
            "canGoBack" -> {
                requireExactKeys(arguments, setOf("generationId"))
                result.success(host.canGoBack())
            }
            "goBack" -> exactGenerationOnly(arguments, result) { host.goBack() }
            "runJavaScript" -> {
                requireExactKeys(arguments, setOf("generationId", "javascript"))
                val javascript = arguments["javascript"] as? String ?:
                    invalid("javascript must be a string")
                host.runJavaScript(javascript)
                result.success(null)
            }
            "fitGameScreen" -> exactGenerationOnly(arguments, result) { host.fitGameScreen() }
            "clearCache" -> exactGenerationOnly(arguments, result) { host.clearCache() }
            "clearSession" -> exactGenerationOnly(arguments, result) { host.clearSession() }
            "destroy" -> {
                requireExactKeys(arguments, setOf("generationId"))
                if (!host.destroy(generation)) stale(result)
                else result.success(null)
            }
        }
    }

    private fun exactGenerationOnly(
        arguments: Map<String, Any?>,
        result: MethodChannel.Result,
        operation: () -> Unit,
    ) {
        requireExactKeys(arguments, setOf("generationId"))
        operation()
        result.success(null)
    }

    private fun requireGeneration(arguments: Map<String, Any?>): Long {
        val value = arguments["generationId"]
        val generation = when (value) {
            is Int -> value.toLong()
            is Long -> value
            else -> invalid("generationId must be an integer")
        }
        if (generation < 0L) invalid("generationId must be non-negative")
        return generation
    }

    private fun parseBounds(raw: Any?): NativeGameWebViewBounds {
        val bounds = strictMap(raw)
        requireExactKeys(bounds, BOUNDS_KEYS)
        fun double(key: String): Double =
            (bounds[key] as? Double)?.takeIf(Double::isFinite) ?:
                invalid("$key must be a finite double")
        return try {
            NativeGameWebViewBounds(
                left = double("left"),
                top = double("top"),
                width = double("width"),
                height = double("height"),
                devicePixelRatio = double("devicePixelRatio"),
            )
        } catch (error: IllegalArgumentException) {
            invalid(error.message ?: "Invalid bounds")
        }
    }

    private fun strictMap(raw: Any?): Map<String, Any?> {
        if (raw !is Map<*, *>) invalid("arguments must be a map")
        if (raw.keys.any { it !is String }) invalid("argument keys must be strings")
        @Suppress("UNCHECKED_CAST")
        return raw as Map<String, Any?>
    }

    private fun requireExactKeys(arguments: Map<String, Any?>, expected: Set<String>) {
        if (arguments.keys != expected) invalid("arguments do not match the method schema")
    }

    private fun isSafeWebUri(raw: String): Boolean =
        try {
            val uri = URI(raw)
            (uri.scheme == "http" || uri.scheme == "https") && !uri.host.isNullOrEmpty()
        } catch (_: Exception) {
            false
        }

    private fun stale(result: MethodChannel.Result) {
        result.error(STALE_GENERATION, "The native WebView generation is stale.", null)
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        if (!destroyed) eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    override fun created(generation: Long) {
        if (destroyed || host?.currentGeneration != generation) return
        acceptedGeneration = generation
        emit(mapOf("type" to "created", "generationId" to generation))
    }

    override fun pageStarted(generation: Long, url: String) {
        emitForGeneration(generation, mapOf("type" to "pageStarted", "generationId" to generation, "url" to url))
    }

    override fun pageFinished(generation: Long, url: String) {
        if (!acceptsEvent(generation)) return
        safeObserverCall(lifecycleObserver::onPageFinished)
        emit(mapOf("type" to "pageFinished", "generationId" to generation, "url" to url))
    }

    override fun mainFrameError(generation: Long, errorCode: Int, description: String) {
        emitForGeneration(
            generation,
            mapOf(
                "type" to "mainFrameError",
                "generationId" to generation,
                "errorCode" to errorCode,
                "description" to description,
            ),
        )
    }

    override fun navigationBlocked(generation: Long, scheme: String) {
        emitForGeneration(
            generation,
            mapOf("type" to "navigationBlocked", "generationId" to generation, "scheme" to scheme),
        )
    }

    override fun renderProcessGone(generation: Long, didCrash: Boolean) {
        if (!acceptsEvent(generation)) return
        safeObserverCall(lifecycleObserver::onRenderProcessGone)
        emit(
            mapOf(
                "type" to "renderProcessGone",
                "generationId" to generation,
                "didCrash" to didCrash,
            ),
        )
    }

    override fun destroyed(generation: Long) {
        if (!acceptsEvent(generation)) return
        emit(mapOf("type" to "destroyed", "generationId" to generation))
        if (acceptedGeneration == generation) acceptedGeneration = null
    }

    private fun emitForGeneration(generation: Long, event: Map<String, Any?>) {
        if (acceptsEvent(generation)) emit(event)
    }

    private fun acceptsEvent(generation: Long): Boolean =
        !destroyed && acceptedGeneration == generation

    private fun emit(event: Map<String, Any?>) {
        val sink = eventSink ?: return
        try {
            sink.success(event)
        } catch (_: Exception) {
            // A detached Flutter listener must not break WebView lifecycle work.
        }
    }

    private fun safeObserverCall(callback: () -> Unit) {
        try {
            callback()
        } catch (_: Exception) {
            // Startup diagnostics must not break the primary WebView callback.
        }
    }

    private class InvalidArgumentsException(message: String) : IllegalArgumentException(message)

    companion object {
        const val METHOD_CHANNEL_NAME = "app.yahagi.kancollebrowser/native_game_webview"
        const val EVENT_CHANNEL_NAME = "app.yahagi.kancollebrowser/native_game_webview_events"
        val SUPPORTED_METHODS = setOf(
            "create",
            "setBounds",
            "setVisible",
            "loadUri",
            "showLocalHome",
            "reload",
            "canGoBack",
            "goBack",
            "runJavaScript",
            "fitGameScreen",
            "clearCache",
            "clearSession",
            "destroy",
        )
        val BOUNDS_KEYS = setOf("left", "top", "width", "height", "devicePixelRatio")
        const val INVALID_ARGUMENT = "invalid_argument"
        const val STALE_GENERATION = "stale_generation"
        const val HOST_UNAVAILABLE = "native_webview_unavailable"
        const val HOST_ERROR = "native_webview_error"
        const val ACTIVITY_DESTROYED = "activity_destroyed"

        fun invalid(message: String): Nothing = throw InvalidArgumentsException(message)
    }
}

internal interface NativeWebViewSnapshotEditor {
    fun putInt(key: String, value: Int): NativeWebViewSnapshotEditor
    fun putLong(key: String, value: Long): NativeWebViewSnapshotEditor
    fun putString(key: String, value: String): NativeWebViewSnapshotEditor
    fun remove(key: String): NativeWebViewSnapshotEditor
    fun commit(): Boolean
}

internal interface NativeWebViewSnapshotPreferences {
    fun readAll(): Map<String, Any?>
    fun edit(): NativeWebViewSnapshotEditor
}

private class AndroidNativeWebViewSnapshotPreferences(
    private val preferences: SharedPreferences,
) : NativeWebViewSnapshotPreferences {
    override fun readAll(): Map<String, Any?> = preferences.all

    override fun edit(): NativeWebViewSnapshotEditor =
        object : NativeWebViewSnapshotEditor {
            private val editor = preferences.edit()

            override fun putInt(key: String, value: Int) = apply { editor.putInt(key, value) }
            override fun putLong(key: String, value: Long) = apply { editor.putLong(key, value) }
            override fun putString(key: String, value: String) = apply { editor.putString(key, value) }
            override fun remove(key: String) = apply { editor.remove(key) }
            override fun commit(): Boolean = editor.commit()
        }
}

internal class NativeWebViewStartupStoreProcessState {
    @Volatile
    private var poisoned = false

    fun isPoisoned(): Boolean = poisoned

    fun poison() {
        poisoned = true
    }
}

internal class SharedPreferencesNativeWebViewStartupStore internal constructor(
    private val preferences: NativeWebViewSnapshotPreferences,
    private val processState: NativeWebViewStartupStoreProcessState,
) : NativeWebViewStartupStore {
    constructor(preferences: SharedPreferences) : this(
        AndroidNativeWebViewSnapshotPreferences(preferences),
        NativeWebViewProcessState.startupStore,
    )

    override fun read(): NativeWebViewStartupReadResult {
        if (processState.isPoisoned()) return NativeWebViewStartupReadResult.Unavailable
        return try {
            val values = preferences.readAll()
            NativeWebViewStartupReadResult.Success(
                NativeWebViewStartupSnapshot(
                    consecutiveFailures = values.optionalTyped<Int>(
                        NativeWebViewStartupGuard.CONSECUTIVE_FAILURES_KEY,
                    ) ?: 0,
                    attemptStartedAtMs = values.optionalTyped<Long>(
                        NativeWebViewStartupGuard.LAST_STARTUP_STARTED_AT_MS_KEY,
                    ),
                    attemptSessionId = values.optionalTyped<String>(
                        NativeWebViewStartupGuard.ATTEMPT_SESSION_ID_KEY,
                    )?.let(::NativeWebViewProcessSessionId),
                    storedRenderingMode = values.optionalTyped<String>(
                        NativeWebViewStartupGuard.RENDERING_MODE_KEY,
                    ),
                ),
            )
        } catch (_: Exception) {
            NativeWebViewStartupReadResult.Unavailable
        }
    }

    override fun write(nextSnapshot: NativeWebViewStartupSnapshot): NativeWebViewStartupWriteResult {
        if (processState.isPoisoned()) return NativeWebViewStartupWriteResult.Indeterminate
        return try {
            val editor = preferences.edit()
                .putInt(
                    NativeWebViewStartupGuard.CONSECUTIVE_FAILURES_KEY,
                    nextSnapshot.consecutiveFailures,
                )
                .putNullableLong(
                    NativeWebViewStartupGuard.LAST_STARTUP_STARTED_AT_MS_KEY,
                    nextSnapshot.attemptStartedAtMs,
                )
                .putNullableString(
                    NativeWebViewStartupGuard.ATTEMPT_SESSION_ID_KEY,
                    nextSnapshot.attemptSessionId?.value,
                )
                .putNullableString(
                    NativeWebViewStartupGuard.RENDERING_MODE_KEY,
                    nextSnapshot.storedRenderingMode,
                )
            if (editor.commit()) {
                NativeWebViewStartupWriteResult.Durable
            } else {
                processState.poison()
                NativeWebViewStartupWriteResult.Indeterminate
            }
        } catch (_: Exception) {
            processState.poison()
            NativeWebViewStartupWriteResult.Indeterminate
        }
    }

    private inline fun <reified T> Map<String, Any?>.optionalTyped(key: String): T? {
        if (!containsKey(key)) return null
        return get(key) as? T ?: throw IllegalStateException("Invalid persisted type for $key")
    }

    private fun NativeWebViewSnapshotEditor.putNullableLong(key: String, value: Long?) =
        if (value == null) remove(key) else putLong(key, value)

    private fun NativeWebViewSnapshotEditor.putNullableString(key: String, value: String?) =
        if (value == null) remove(key) else putString(key, value)
}

internal class NativeWebViewProcessSessionIdProvider(
    private val factory: () -> NativeWebViewProcessSessionId,
) {
    @Volatile
    private var cached: NativeWebViewProcessSessionId? = null

    fun current(): NativeWebViewProcessSessionId =
        cached ?: synchronized(this) {
            cached ?: factory().also { cached = it }
        }
}

internal object NativeWebViewProcessState {
    val startupStore = NativeWebViewStartupStoreProcessState()
    private val sessionProvider = NativeWebViewProcessSessionIdProvider {
        NativeWebViewProcessSessionId(UUID.randomUUID().toString())
    }

    val sessionId: NativeWebViewProcessSessionId
        get() = sessionProvider.current()
}
