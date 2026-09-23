package app.yahagi.kancollebrowser.browser

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.util.concurrent.atomic.AtomicLong

class GameResourceCacheManager(
    private val engine: GameResourceCacheEngine,
    private val coordinator: GameResourceDownloadCoordinator,
    private val modeProvider: () -> GameResourceCacheMode,
    private val onModeChanged: (GameResourceCacheMode) -> Unit,
    private val networkMonitor: GameResourceNetworkMonitor? = null,
    private val canInterceptGameRequests: () -> Boolean = { true },
) : MethodChannel.MethodCallHandler {
    private val scope = CoroutineScope(Dispatchers.Main + Job())
    private val pendingManifestLock = Any()
    private var pendingManifest: PendingManifest? = null
    private val modeEpoch = AtomicLong(0)
    @Volatile private var policyError = false

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "configure" -> {
                val mode = GameResourceCacheMode.fromWireName(call.argument<String>("mode"))
                val capturedEpoch = modeEpoch.incrementAndGet()
                synchronized(pendingManifestLock) {
                    pendingManifest = null
                }
                if (mode == GameResourceCacheMode.FULL && !canInterceptGameRequests()) {
                    result.success(false)
                } else {
                    scope.launch {
                        val outcome = runCatching {
                            withContext(Dispatchers.IO) {
                                coordinator.configureModeChange(
                                    mode.wireName,
                                    mode != GameResourceCacheMode.FULL,
                                ) { modeEpoch.get() == capturedEpoch }
                            }
                        }
                        outcome.onSuccess { configured ->
                            if (configured && modeEpoch.get() == capturedEpoch) {
                                onModeChanged(mode)
                                policyError = withContext(Dispatchers.IO) {
                                    runCatching { engine.enforcePolicy() }.isFailure
                                }
                                result.success(true)
                            } else {
                                result.success(false)
                            }
                        }.onFailure {
                            result.error("game_resource_cache_error", it.message ?: "Cache configuration failed", null)
                        }
                    }
                }
            }
            "status" -> runIo(result) { statusMap() }
            "beginManifest" -> {
                val transactionId = call.argument<String>("transactionId")
                val profile = call.argument<String>("profile") ?: modeProvider().wireName
                val targetBytes = (call.argument<Number>("targetBytes"))?.toLong() ?: 0L
                if (transactionId == null) {
                    result.success(false)
                } else {
                    synchronized(pendingManifestLock) {
                        pendingManifest = PendingManifest(
                            transactionId,
                            profile,
                            targetBytes,
                            modeEpoch.get(),
                        )
                    }
                    result.success(true)
                }
            }
            "appendManifest" -> {
                val transactionId = call.argument<String>("transactionId")
                val urls = call.argument<List<*>>("urls")?.filterIsInstance<String>().orEmpty()
                val rawLengths = call.argument<List<*>>("expectedLengths")
                val lengths = rawLengths?.mapNotNull { (it as? Number)?.toLong() }
                val appended = synchronized(pendingManifestLock) {
                    val pending = pendingManifest?.takeIf { it.transactionId == transactionId }
                    if (pending == null || (rawLengths != null && lengths?.size != urls.size) ||
                        (pending.urls.isNotEmpty() && (pending.expectedLengths == null) != (lengths == null))
                    ) {
                        false
                    } else {
                        pending.urls.addAll(urls)
                        if (lengths != null) {
                            val destination = pending.expectedLengths ?: mutableListOf<Long>().also {
                                pending.expectedLengths = it
                            }
                            destination.addAll(lengths)
                        }
                        true
                    }
                }
                result.success(appended)
            }
            "commitManifest" -> {
                val transactionId = call.argument<String>("transactionId")
                val manifest = synchronized(pendingManifestLock) {
                    pendingManifest
                        ?.takeIf { it.transactionId == transactionId }
                        ?.also { pendingManifest = null }
                }
                if (manifest == null) {
                    result.success(false)
                } else {
                    runIo(result) {
                        val expectedMode = GameResourceCacheMode.fromWireName(manifest.profile)
                        val prepared = coordinator.prepareManifest(
                            manifest.profile,
                            manifest.urls,
                            manifest.targetBytes,
                            manifest.expectedLengths.orEmpty(),
                        )
                        try {
                            val applied = coordinator.applyPreparedManifestIf(prepared) {
                                modeEpoch.get() == manifest.modeEpoch && modeProvider() == expectedMode
                            }
                            if (applied && modeEpoch.get() == manifest.modeEpoch &&
                                expectedMode == GameResourceCacheMode.FULL
                            ) coordinator.startAutoUpdate()
                            applied
                        } finally {
                            coordinator.discardPreparedManifest(prepared)
                        }
                    }
                }
            }
            "abortManifest" -> {
                val transactionId = call.argument<String>("transactionId")
                val aborted = synchronized(pendingManifestLock) {
                    if (pendingManifest?.transactionId == transactionId) {
                        pendingManifest = null
                        true
                    } else {
                        false
                    }
                }
                result.success(aborted)
            }
            "setManifest" -> {
                val profile = call.argument<String>("profile") ?: modeProvider().wireName
                val urls = call.argument<List<*>>("urls")?.filterIsInstance<String>().orEmpty()
                val expectedLengths = call.argument<List<*>>("expectedLengths")
                    ?.mapNotNull { (it as? Number)?.toLong() }
                    .orEmpty()
                val targetBytes = (call.argument<Number>("targetBytes"))?.toLong() ?: 0L
                val capturedEpoch = modeEpoch.get()
                runIo(result) {
                    val expectedMode = GameResourceCacheMode.fromWireName(profile)
                    val prepared = coordinator.prepareManifest(
                        profile,
                        urls,
                        targetBytes,
                        expectedLengths,
                    )
                    try {
                        val applied = coordinator.applyPreparedManifestIf(prepared) {
                            modeEpoch.get() == capturedEpoch && modeProvider() == expectedMode
                        }
                        if (applied && modeEpoch.get() == capturedEpoch &&
                            expectedMode == GameResourceCacheMode.FULL
                        ) coordinator.startAutoUpdate()
                        applied
                    } finally {
                        coordinator.discardPreparedManifest(prepared)
                    }
                }
            }
            "startDownload" -> runIo(result) {
                canInterceptGameRequests() &&
                    coordinator.startDownload(call.argument<Boolean>("allowMetered") == true)
            }
            "pauseDownload" -> runIo(result) { coordinator.pauseDownload() }
            "checkIntegrity" -> runIo(result) {
                coordinator.checkIntegrity()
                statusMap()
            }
            "repair" -> runIo(result) {
                coordinator.checkIntegrity()
                coordinator.startDownload(call.argument<Boolean>("allowMetered") == true)
            }
            "clear" -> runIo(result) {
                coordinator.cancelDownload()
                engine.clear()
                coordinator.checkIntegrity()
                true
            }
            else -> result.notImplemented()
        }
    }

    fun dispose() {
        networkMonitor?.dispose()
        scope.cancel()
        coordinator.dispose()
    }

    private fun statusMap(): Map<String, Any?> {
        val status = coordinator.status()
        val cache = runCatching { engine.status() }
            .onSuccess { policyError = false }
            .getOrElse {
                policyError = true
                engine.statusSnapshot()
            }
        return mapOf(
            "mode" to modeProvider().wireName,
            "supported" to canInterceptGameRequests(),
            "policyError" to policyError,
            "state" to status.state.wireName,
            "cachedBytes" to cache.usedBytes,
            "maxBytes" to cache.maxBytes,
            "targetBytes" to status.targetBytes,
            "downloadedBytes" to status.downloadedBytes,
            "bytesPerSecond" to status.bytesPerSecond,
            "remainingSeconds" to status.remainingSeconds,
            "missingCount" to status.missingCount,
            "damagedCount" to status.damagedCount,
            "outdatedCount" to status.outdatedCount,
            "fileCount" to cache.fileCount,
            "capacityBlocked" to status.capacityBlocked,
            "isMetered" to status.isMetered,
            "waitingForWifi" to status.waitingForWifi,
        )
    }

    private fun runIo(result: MethodChannel.Result, action: () -> Any?) {
        scope.launch {
            val outcome = runCatching { withContext(Dispatchers.IO) { action() } }
            outcome.onSuccess(result::success).onFailure {
                result.error("game_resource_cache_error", it.message ?: "Resource cache operation failed", null)
            }
        }
    }

    private data class PendingManifest(
        val transactionId: String,
        val profile: String,
        val targetBytes: Long,
        val modeEpoch: Long,
        val urls: MutableList<String> = mutableListOf(),
        var expectedLengths: MutableList<Long>? = null,
    )
}
