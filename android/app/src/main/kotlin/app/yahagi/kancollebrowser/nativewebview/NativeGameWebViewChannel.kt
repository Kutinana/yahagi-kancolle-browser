package app.yahagi.kancollebrowser.nativewebview

import android.annotation.SuppressLint
import android.content.SharedPreferences
import android.webkit.CookieManager
import android.webkit.WebStorage
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.lang.ref.WeakReference
import java.net.URI
import java.util.UUID
import java.util.WeakHashMap
import java.util.concurrent.atomic.AtomicBoolean

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
    fun clearSession(onComplete: (Exception?) -> Unit)
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
        // Task 8 replaces this placeholder with the complete offline home document.
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
        // Task 8 installs the complete fitting script; this only invokes its future hook.
        requireWebView().evaluateJavascript(
            "window.__yahagiMobileSyncPresentation?.();",
            null,
        )
    }

    override fun clearCache() {
        requireWebView().clearCache(true)
    }

    override fun clearSession(onComplete: (Exception?) -> Unit) {
        WebStorage.getInstance().deleteAllData()
        requireWebView().apply {
            clearFormData()
            clearHistory()
            clearCache(true)
        }
        CookieManager.getInstance().removeAllCookies {
            try {
                CookieManager.getInstance().flush()
                onComplete(null)
            } catch (error: Exception) {
                onComplete(error)
            }
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

internal class NativeGameWebViewActivityAttachment internal constructor(
    internal val id: Long,
)

internal class NativeGameWebViewChannel : MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler,
    NativeGameWebViewEventSink {
    private data class ActivityBinding(
        val token: NativeGameWebViewActivityAttachment,
        val dispatchToMain: ((() -> Unit) -> Unit),
        val lifecycleObserver: NativeGameWebViewLifecycleObserver,
        var host: NativeGameWebViewHostOperations? = null,
        var detaching: Boolean = false,
    )

    private data class ParsedCall(
        val method: String,
        val generation: Long? = null,
        val bounds: NativeGameWebViewBounds? = null,
        val visible: Boolean? = null,
        val text: String? = null,
    )

    private data class PendingCall(
        val parsed: ParsedCall,
        val result: MethodChannel.Result,
    )

    private var activityBinding: ActivityBinding? = null
    private var nextAttachmentId = 0L
    private val pendingCalls = ArrayDeque<PendingCall>()
    private var callRunning = false
    private var asyncVersion = 0L
    private var eventSink: EventChannel.EventSink? = null
    private var acceptedGeneration: Long? = null
    private var engineDestroyed = false

    fun attachActivity(
        dispatchToMain: ((() -> Unit) -> Unit),
        lifecycleObserver: NativeGameWebViewLifecycleObserver =
            NoOpNativeGameWebViewLifecycleObserver,
    ): NativeGameWebViewActivityAttachment {
        check(!engineDestroyed) { "Native game WebView engine channel is destroyed" }
        activityBinding?.let(::detachBinding)
        val token = NativeGameWebViewActivityAttachment(nextAttachmentId++)
        activityBinding = ActivityBinding(token, dispatchToMain, lifecycleObserver)
        return token
    }

    fun attachHost(
        attachment: NativeGameWebViewActivityAttachment,
        host: NativeGameWebViewHostOperations,
    ) {
        val binding = activityBinding
        check(binding?.token === attachment) { "Native game WebView Activity is not attached" }
        check(!binding.detaching) { "Native game WebView Activity is detaching" }
        check(binding.host == null) { "Native game WebView host is already attached" }
        binding.host = host
    }

    fun detachActivity(attachment: NativeGameWebViewActivityAttachment) {
        val binding = activityBinding
        if (binding?.token !== attachment) return
        detachBinding(binding)
    }

    private fun detachBinding(binding: ActivityBinding) {
        binding.detaching = true
        asyncVersion++
        pendingCalls.clear()
        callRunning = false
        binding.host?.currentGeneration?.let { generation ->
            try {
                binding.host?.destroy(generation)
            } catch (_: Exception) {
                acceptedGeneration = null
            }
        }
        binding.host = null
        acceptedGeneration = null
        if (activityBinding === binding) activityBinding = null
    }

    fun shutdownEngine() {
        if (engineDestroyed) return
        activityBinding?.let(::detachBinding)
        engineDestroyed = true
        acceptedGeneration = null
        val sink = eventSink
        eventSink = null
        try {
            sink?.endOfStream()
        } catch (_: Exception) {
            // A detached Flutter listener must not break engine cleanup.
        }
    }

    /** Compatibility alias for tests and explicit permanent teardown. */
    fun disable() = shutdownEngine()

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method !in SUPPORTED_METHODS) {
            safeNotImplemented(result)
            return
        }
        val parsed = try {
            parseCall(call)
        } catch (error: InvalidArgumentsException) {
            safeError(result, INVALID_ARGUMENT, error.message)
            return
        }
        if (engineDestroyed) {
            safeError(result, ACTIVITY_DESTROYED, "The Flutter engine has been destroyed.")
            return
        }
        val binding = activityBinding
        if (binding == null || binding.detaching || binding.host == null) {
            safeError(result, HOST_UNAVAILABLE, "The native WebView host is unavailable.")
            return
        }
        pendingCalls.addLast(PendingCall(parsed, result))
        dispatchNext(binding)
    }

    private fun dispatchNext(binding: ActivityBinding) {
        if (callRunning || pendingCalls.isEmpty()) return
        if (activityBinding !== binding || binding.detaching) {
            pendingCalls.clear()
            return
        }
        callRunning = true
        try {
            binding.dispatchToMain {
                if (activityBinding !== binding || binding.detaching || pendingCalls.isEmpty()) {
                    callRunning = false
                    return@dispatchToMain
                }
                executeOnMain(binding, pendingCalls.first())
            }
        } catch (error: Exception) {
            val failed = pendingCalls.removeFirstOrNull()
            callRunning = false
            failed?.let {
                safeError(it.result, HOST_ERROR, error.message ?: "Unable to dispatch native WebView operation.")
            }
            dispatchNext(binding)
        }
    }

    private fun executeOnMain(binding: ActivityBinding, pending: PendingCall) {
        val host = binding.host
        if (host == null) {
            finish(binding, pending) {
                safeError(pending.result, HOST_UNAVAILABLE, "The native WebView host is unavailable.")
            }
            return
        }
        val parsed = pending.parsed
        try {
            if (parsed.method == "create") {
                host.currentGeneration?.let { oldGeneration ->
                    check(host.destroy(oldGeneration)) { "Unable to destroy the previous native WebView" }
                }
                val generation = host.create()
                if (generation == null || generation < 0L) {
                    safeObserverCall(binding.lifecycleObserver::onCreateFailed)
                    error("Unable to create the native WebView")
                }
                acceptedGeneration = generation
                finish(binding, pending) { safeSuccess(pending.result, generation) }
                return
            }

            val generation = checkNotNull(parsed.generation)
            if (host.currentGeneration != generation || acceptedGeneration != generation) {
                finish(binding, pending) {
                    safeError(pending.result, STALE_GENERATION, "The native WebView generation is stale.")
                }
                return
            }

            when (parsed.method) {
                "setBounds" -> {
                    check(host.setBounds(generation, checkNotNull(parsed.bounds))) {
                        "The native WebView bounds could not be applied"
                    }
                    finishSuccess(binding, pending)
                }
                "setVisible" -> {
                    check(host.setVisible(generation, checkNotNull(parsed.visible))) {
                        "The native WebView visibility could not be applied"
                    }
                    finishSuccess(binding, pending)
                }
                "loadUri" -> {
                    host.loadUri(checkNotNull(parsed.text))
                    finishSuccess(binding, pending)
                }
                "showLocalHome" -> {
                    host.showLocalHome()
                    finishSuccess(binding, pending)
                }
                "reload" -> {
                    host.reload()
                    finishSuccess(binding, pending)
                }
                "canGoBack" -> finish(binding, pending) {
                    safeSuccess(pending.result, host.canGoBack())
                }
                "goBack" -> {
                    host.goBack()
                    finishSuccess(binding, pending)
                }
                "runJavaScript" -> {
                    host.runJavaScript(checkNotNull(parsed.text))
                    finishSuccess(binding, pending)
                }
                "fitGameScreen" -> {
                    host.fitGameScreen()
                    finishSuccess(binding, pending)
                }
                "clearCache" -> {
                    host.clearCache()
                    finishSuccess(binding, pending)
                }
                "clearSession" -> startClearSession(binding, pending, host)
                "destroy" -> {
                    check(host.destroy(generation)) { "Unable to destroy the native WebView" }
                    finishSuccess(binding, pending)
                }
            }
        } catch (error: Exception) {
            finish(binding, pending) {
                safeError(pending.result, HOST_ERROR, error.message ?: "Native WebView operation failed.")
            }
        }
    }

    private fun startClearSession(
        binding: ActivityBinding,
        pending: PendingCall,
        host: NativeGameWebViewHostOperations,
    ) {
        val callbackConsumed = AtomicBoolean(false)
        val version = ++asyncVersion
        val attachmentId = binding.token.id
        val dispatcher = binding.dispatchToMain
        try {
            host.clearSession { error ->
                if (!callbackConsumed.compareAndSet(false, true)) return@clearSession
                try {
                    dispatcher callback@{
                        val activeBinding = activityBinding
                        if (
                            version != asyncVersion ||
                            activeBinding == null ||
                            activeBinding.token.id != attachmentId ||
                            activeBinding.detaching
                        ) {
                            return@callback
                        }
                        finish(activeBinding, pending) {
                            if (error == null) safeSuccess(pending.result, null)
                            else safeError(
                                pending.result,
                                HOST_ERROR,
                                error.message ?: "Unable to clear the native WebView session.",
                            )
                        }
                    }
                } catch (_: Exception) {
                    // Detach or dispatcher failure invalidates this Activity's pending result.
                }
            }
        } catch (error: Exception) {
            if (callbackConsumed.compareAndSet(false, true)) {
                finish(binding, pending) {
                    safeError(pending.result, HOST_ERROR, error.message ?: "Unable to clear the native WebView session.")
                }
            }
        }
    }

    private fun finishSuccess(binding: ActivityBinding, pending: PendingCall) =
        finish(binding, pending) { safeSuccess(pending.result, null) }

    private fun finish(binding: ActivityBinding, pending: PendingCall, completion: () -> Unit) {
        if (activityBinding !== binding || binding.detaching || pendingCalls.firstOrNull() !== pending) return
        pendingCalls.removeFirst()
        callRunning = false
        completion()
        dispatchNext(binding)
    }

    private fun parseCall(call: MethodCall): ParsedCall {
        val arguments = strictMap(call.arguments)
        return when (call.method) {
            "create" -> {
                requireExactKeys(arguments, setOf("renderer"))
                if (arguments["renderer"] != "webgl") invalid("renderer must be webgl")
                ParsedCall(call.method)
            }
            "setBounds" -> {
                requireExactKeys(arguments, setOf("generationId", "bounds"))
                ParsedCall(call.method, requireGeneration(arguments), bounds = parseBounds(arguments["bounds"]))
            }
            "setVisible" -> {
                requireExactKeys(arguments, setOf("generationId", "visible"))
                val visible = arguments["visible"] as? Boolean ?: invalid("visible must be a boolean")
                ParsedCall(call.method, requireGeneration(arguments), visible = visible)
            }
            "loadUri" -> {
                requireExactKeys(arguments, setOf("generationId", "uri"))
                val uri = arguments["uri"] as? String ?: invalid("uri must be a string")
                if (!isSafeWebUri(uri)) invalid("uri must be an absolute HTTP(S) URI")
                ParsedCall(call.method, requireGeneration(arguments), text = uri)
            }
            "runJavaScript" -> {
                requireExactKeys(arguments, setOf("generationId", "javascript"))
                val javascript = arguments["javascript"] as? String ?: invalid("javascript must be a string")
                ParsedCall(call.method, requireGeneration(arguments), text = javascript)
            }
            else -> {
                requireExactKeys(arguments, setOf("generationId"))
                ParsedCall(call.method, requireGeneration(arguments))
            }
        }
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

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        if (!engineDestroyed) eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    override fun created(generation: Long) {
        if (engineDestroyed || activityBinding?.host?.currentGeneration != generation) return
        acceptedGeneration = generation
        emit(mapOf("type" to "created", "generationId" to generation))
    }

    override fun pageStarted(generation: Long, url: String) {
        emitForGeneration(generation, mapOf("type" to "pageStarted", "generationId" to generation, "url" to url))
    }

    override fun pageFinished(generation: Long, url: String) {
        if (!acceptsEvent(generation)) return
        activityBinding?.lifecycleObserver?.let { safeObserverCall(it::onPageFinished) }
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
        activityBinding?.lifecycleObserver?.let { safeObserverCall(it::onRenderProcessGone) }
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
        !engineDestroyed && acceptedGeneration == generation

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

    private fun safeSuccess(result: MethodChannel.Result, value: Any?) {
        try {
            result.success(value)
        } catch (_: Exception) {
            // A detached Dart caller must not stop command serialization.
        }
    }

    private fun safeError(result: MethodChannel.Result, code: String, message: String?) {
        try {
            result.error(code, message, null)
        } catch (_: Exception) {
            // A detached Dart caller must not stop command serialization.
        }
    }

    private fun safeNotImplemented(result: MethodChannel.Result) {
        try {
            result.notImplemented()
        } catch (_: Exception) {
            // A detached Dart caller must not break the engine handler.
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

internal class NativeGameWebViewChannelRegistry<K : Any>(
    private val channelFactory: () -> NativeGameWebViewChannel = ::NativeGameWebViewChannel,
) {
    // Both sides are weak: EventSink can retain its messenger/engine through the channel value.
    private val channels = WeakHashMap<K, WeakReference<NativeGameWebViewChannel>>()

    @Synchronized
    fun acquire(key: K, register: (NativeGameWebViewChannel) -> Unit): NativeGameWebViewChannel =
        channels[key]?.get() ?: channelFactory().also { channel ->
            register(channel)
            channels[key] = WeakReference(channel)
        }

    @Synchronized
    fun peek(key: K): NativeGameWebViewChannel? = channels[key]?.get()

    @Synchronized
    fun remove(key: K): NativeGameWebViewChannel? = channels.remove(key)?.get()
}

internal object NativeGameWebViewEngineChannels {
    private val registry = NativeGameWebViewChannelRegistry<FlutterEngine>()

    fun acquire(engine: FlutterEngine): NativeGameWebViewChannel =
        registry.acquire(engine) { channel ->
            MethodChannel(
                engine.dartExecutor.binaryMessenger,
                NativeGameWebViewChannel.METHOD_CHANNEL_NAME,
            ).setMethodCallHandler(channel)
            EventChannel(
                engine.dartExecutor.binaryMessenger,
                NativeGameWebViewChannel.EVENT_CHANNEL_NAME,
            ).setStreamHandler(channel)
        }

    fun destroy(engine: FlutterEngine) {
        val channel = registry.remove(engine) ?: return
        MethodChannel(
            engine.dartExecutor.binaryMessenger,
            NativeGameWebViewChannel.METHOD_CHANNEL_NAME,
        ).setMethodCallHandler(null)
        EventChannel(
            engine.dartExecutor.binaryMessenger,
            NativeGameWebViewChannel.EVENT_CHANNEL_NAME,
        ).setStreamHandler(null)
        channel.shutdownEngine()
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

    @SuppressLint("CommitPrefEdits")
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
