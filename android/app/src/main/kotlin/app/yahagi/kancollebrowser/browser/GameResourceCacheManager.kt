package app.yahagi.kancollebrowser.browser

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class GameResourceCacheManager(
    private val engine: GameResourceCacheEngine,
    private val coordinator: GameResourceDownloadCoordinator,
    private val modeProvider: () -> GameResourceCacheMode,
    private val onModeChanged: (GameResourceCacheMode) -> Unit,
    private val networkMonitor: GameResourceNetworkMonitor? = null,
) : MethodChannel.MethodCallHandler {
    private val scope = CoroutineScope(Dispatchers.Main + Job())

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "configure" -> {
                val mode = GameResourceCacheMode.fromWireName(call.argument<String>("mode"))
                if (mode == GameResourceCacheMode.NONE) coordinator.pauseDownload()
                onModeChanged(mode)
                result.success(true)
            }
            "status" -> result.success(statusMap())
            "setManifest" -> {
                val profile = call.argument<String>("profile") ?: modeProvider().wireName
                val urls = call.argument<List<*>>("urls")?.filterIsInstance<String>().orEmpty()
                val targetBytes = (call.argument<Number>("targetBytes"))?.toLong() ?: 0L
                coordinator.setManifest(profile, urls, targetBytes)
                if (modeProvider() != GameResourceCacheMode.NONE) {
                    coordinator.startDownload()
                }
                result.success(true)
            }
            "startDownload" -> result.success(
                coordinator.startDownload(call.argument<Boolean>("allowMetered") == true),
            )
            "pauseDownload" -> result.success(coordinator.pauseDownload())
            "checkIntegrity" -> runIo(result) {
                coordinator.checkIntegrity()
                statusMap()
            }
            "repair" -> runIo(result) {
                coordinator.checkIntegrity()
                coordinator.startDownload(call.argument<Boolean>("allowMetered") == true)
            }
            "clear" -> runIo(result) {
                coordinator.pauseDownload()
                engine.clear()
                coordinator.checkIntegrity()
                true
            }
            else -> result.notImplemented()
        }
    }

    fun dispose() {
        coordinator.dispose()
        networkMonitor?.dispose()
        scope.cancel()
    }

    private fun statusMap(): Map<String, Any?> {
        val status = coordinator.status()
        val cache = engine.status()
        return mapOf(
            "mode" to modeProvider().wireName,
            "state" to status.state.wireName,
            "cachedBytes" to status.cachedBytes,
            "maxBytes" to cache.maxBytes,
            "targetBytes" to status.targetBytes,
            "downloadedBytes" to status.downloadedBytes,
            "bytesPerSecond" to status.bytesPerSecond,
            "remainingSeconds" to status.remainingSeconds,
            "missingCount" to status.missingCount,
            "damagedCount" to status.damagedCount,
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
}
