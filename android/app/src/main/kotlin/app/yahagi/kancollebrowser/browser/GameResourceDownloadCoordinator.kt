package app.yahagi.kancollebrowser.browser

import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.nio.file.Files
import java.nio.file.StandardCopyOption
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicLong

enum class GameResourceDownloadState(val wireName: String) {
    IDLE("idle"),
    DOWNLOADING("downloading"),
    PAUSED("paused"),
    COMPLETE("complete"),
    CHECKING("checking"),
    CAPACITY_BLOCKED("capacityBlocked"),
    ERROR("error"),
}

data class GameResourceDownloadStatus(
    val state: GameResourceDownloadState,
    val cachedBytes: Long,
    val targetBytes: Long,
    val downloadedBytes: Long,
    val bytesPerSecond: Long,
    val remainingSeconds: Long?,
    val missingCount: Int,
    val damagedCount: Int,
    val outdatedCount: Int,
    val capacityBlocked: Boolean,
    val isMetered: Boolean,
    val waitingForWifi: Boolean,
)

data class GameResourceNetworkState(
    val connected: Boolean,
    val metered: Boolean,
    val wifi: Boolean = !metered,
)

class GameResourceDownloadCoordinator(
    private val engine: GameResourceCacheEngine,
    private val modeProvider: () -> GameResourceCacheMode,
    private val stateFile: File,
    private val networkProvider: () -> GameResourceNetworkState = {
        GameResourceNetworkState(connected = true, metered = false, wifi = true)
    },
) {
    private val executor = Executors.newSingleThreadExecutor { runnable ->
        Thread(runnable, "game-resource-preloader").apply { isDaemon = true }
    }
    private val workerRunning = AtomicBoolean(false)
    private val generation = AtomicLong(0)
    @Volatile private var pauseRequested = false
    @Volatile private var networkPaused = false
    @Volatile private var allowMetered = false
    @Volatile private var userPaused = false
    private var profile = "none"
    private var urls = emptyList<String>()
    private var targetBytes = 0L
    private var downloadedBytes = 0L
    private var startedAt = 0L
    private var missingCount = 0
    private var damagedCount = 0
    private var outdatedCount = 0
    private val validByteLengths = linkedMapOf<String, Long>()
    private var state = GameResourceDownloadState.IDLE
    private var preloadAuthorized = false

    init {
        restore()
    }

    @Synchronized
    fun setManifest(profile: String, candidates: List<String>, targetBytes: Long) {
        val profileChanged = this.profile != profile
        generation.incrementAndGet()
        this.profile = profile
        urls = candidates.asSequence()
            .filter { GameResourceCacheRules.shouldCache(it, "GET") }
            .distinct()
            .toList()
        this.targetBytes = targetBytes.coerceAtLeast(0)
        downloadedBytes = 0
        if (profileChanged) {
            preloadAuthorized = false
            userPaused = false
        }
        refreshInspectionCounts()
        state = if (userPaused) {
            GameResourceDownloadState.PAUSED
        } else if (missingCount == 0 && damagedCount == 0 && outdatedCount == 0 && urls.isNotEmpty()) {
            GameResourceDownloadState.COMPLETE
        } else {
            GameResourceDownloadState.IDLE
        }
        pauseRequested = userPaused
        networkPaused = false
        allowMetered = false
        persist()
    }

    @Synchronized
    fun startDownload(allowMetered: Boolean = false): Boolean {
        preloadAuthorized = true
        userPaused = false
        return startDownloadInternal(allowMetered)
    }

    @Synchronized
    fun startAutoUpdate(): Boolean {
        if (!preloadAuthorized || userPaused) return false
        return startDownloadInternal(allowMetered = false)
    }

    private fun startDownloadInternal(allowMetered: Boolean): Boolean {
        val mode = modeProvider()
        if (mode == GameResourceCacheMode.NONE || urls.isEmpty()) return false
        if (mode == GameResourceCacheMode.FULL && targetBytes > engine.status().maxBytes) {
            state = GameResourceDownloadState.CAPACITY_BLOCKED
            pauseRequested = true
            persist()
            return false
        }
        val remainingEstimate = (targetBytes - cachedManifestBytes()).coerceAtLeast(0L)
        if (remainingEstimate > engine.availableDeviceBytes()) {
            state = GameResourceDownloadState.CAPACITY_BLOCKED
            pauseRequested = true
            persist()
            return false
        }
        this.allowMetered = allowMetered
        if (!canUseCurrentNetwork()) {
            networkPaused = true
            pauseRequested = true
            state = GameResourceDownloadState.PAUSED
            persist()
            return false
        }
        networkPaused = false
        pauseRequested = false
        state = GameResourceDownloadState.DOWNLOADING
        if (startedAt == 0L) startedAt = System.currentTimeMillis()
        persist()
        val currentGeneration = generation.get()
        if (workerRunning.compareAndSet(false, true)) {
            executor.execute { downloadLoop(currentGeneration) }
        }
        return true
    }

    @Synchronized
    fun pauseDownload(): Boolean {
        userPaused = true
        networkPaused = false
        pauseRequested = true
        state = GameResourceDownloadState.PAUSED
        persist()
        return true
    }

    @Synchronized
    fun onNetworkChanged() {
        if (!canUseCurrentNetwork()) {
            if (state == GameResourceDownloadState.DOWNLOADING) {
                networkPaused = true
                pauseRequested = true
                state = GameResourceDownloadState.PAUSED
                persist()
            }
            return
        }
        if (!networkPaused || modeProvider() == GameResourceCacheMode.NONE || urls.isEmpty()) return
        networkPaused = false
        pauseRequested = false
        state = GameResourceDownloadState.DOWNLOADING
        if (startedAt == 0L) startedAt = System.currentTimeMillis()
        persist()
        val currentGeneration = generation.get()
        if (workerRunning.compareAndSet(false, true)) {
            executor.execute { downloadLoop(currentGeneration) }
        }
    }

    fun checkIntegrity(): GameResourceDownloadStatus {
        synchronized(this) {
            state = GameResourceDownloadState.CHECKING
        }
        synchronized(this) {
            refreshInspectionCounts()
            state = when {
                pauseRequested -> GameResourceDownloadState.PAUSED
                missingCount == 0 && damagedCount == 0 && outdatedCount == 0 && urls.isNotEmpty() ->
                    GameResourceDownloadState.COMPLETE
                else -> GameResourceDownloadState.IDLE
            }
            persist()
            return status()
        }
    }

    fun repair(): Boolean {
        checkIntegrity()
        return startDownload()
    }

    @Synchronized
    fun status(): GameResourceDownloadStatus {
        val cached = cachedManifestBytes()
        val elapsedSeconds = ((System.currentTimeMillis() - startedAt) / 1000).coerceAtLeast(1)
        val speed = if (startedAt == 0L) 0L else downloadedBytes / elapsedSeconds
        val remaining = if (speed > 0 && targetBytes > cached) (targetBytes - cached + speed - 1) / speed else null
        return GameResourceDownloadStatus(
            state = state,
            cachedBytes = cached,
            targetBytes = targetBytes,
            downloadedBytes = downloadedBytes,
            bytesPerSecond = speed,
            remainingSeconds = remaining,
            missingCount = missingCount,
            damagedCount = damagedCount,
            outdatedCount = outdatedCount,
            capacityBlocked = state == GameResourceDownloadState.CAPACITY_BLOCKED,
            isMetered = !networkProvider().wifi,
            waitingForWifi = networkPaused,
        )
    }

    fun dispose() {
        synchronized(this) {
            pauseRequested = true
            if (state == GameResourceDownloadState.DOWNLOADING) {
                state = GameResourceDownloadState.PAUSED
            }
            persist()
        }
        executor.shutdownNow()
    }

    private fun downloadLoop(workerGeneration: Long) {
        try {
            val work = synchronized(this) { urls.toList() }
            for (url in work) {
                if (workerGeneration != generation.get()) return
                if (pauseRequested) return
                if (!canUseCurrentNetwork()) {
                    synchronized(this) {
                        networkPaused = true
                        pauseRequested = true
                        state = GameResourceDownloadState.PAUSED
                        persist()
                    }
                    return
                }
                if (engine.hasCached(url)) continue
                val before = engine.status()
                val response = try {
                    engine.fetch(url)
                } catch (_: Exception) {
                    synchronized(this) {
                        state = GameResourceDownloadState.ERROR
                        pauseRequested = true
                        persist()
                    }
                    return
                } ?: continue
                if (response.source == GameResourceResponseSource.NETWORK) {
                    synchronized(this) { downloadedBytes += response.bytes.size }
                }
                val inspection = engine.inspect(url)
                if (inspection.state == GameResourceInspectionState.VALID) {
                    synchronized(this) { validByteLengths[url] = inspection.byteLength }
                }
                val after = engine.status()
                if (modeProvider() == GameResourceCacheMode.FULL &&
                    after.fileCount == before.fileCount &&
                    before.usedBytes + response.bytes.size > before.maxBytes
                ) {
                    synchronized(this) {
                        state = GameResourceDownloadState.CAPACITY_BLOCKED
                        pauseRequested = true
                        missingCount = urls.count { !engine.hasCached(it) }
                        persist()
                    }
                    return
                }
                synchronized(this) { persist() }
            }
            synchronized(this) {
                if (!pauseRequested && workerGeneration == generation.get()) {
                    refreshInspectionCounts()
                    state = if (missingCount == 0 && damagedCount == 0 && outdatedCount == 0) {
                        GameResourceDownloadState.COMPLETE
                    } else {
                        GameResourceDownloadState.ERROR
                    }
                    persist()
                }
            }
        } finally {
            workerRunning.set(false)
            if (!pauseRequested && state == GameResourceDownloadState.DOWNLOADING && workerRunning.compareAndSet(false, true)) {
                val currentGeneration = generation.get()
                executor.execute { downloadLoop(currentGeneration) }
            }
        }
    }

    private fun canUseCurrentNetwork(): Boolean {
        val network = networkProvider()
        return network.connected && (network.wifi || allowMetered)
    }

    private fun refreshInspectionCounts() {
        val inspections = urls.associateWith(engine::inspect)
        validByteLengths.clear()
        inspections.forEach { (url, inspection) ->
            if (inspection.state == GameResourceInspectionState.VALID) {
                validByteLengths[url] = inspection.byteLength
            }
        }
        missingCount = inspections.values.count { it.state == GameResourceInspectionState.MISSING }
        damagedCount = inspections.values.count { it.state == GameResourceInspectionState.DAMAGED }
        outdatedCount = inspections.values.count { it.state == GameResourceInspectionState.OUTDATED }
    }

    private fun cachedManifestBytes(): Long = validByteLengths.values.sum()

    @Synchronized
    private fun persist() {
        stateFile.parentFile?.mkdirs()
        val array = JSONArray()
        urls.forEach(array::put)
        val json = JSONObject()
            .put("version", 1)
            .put("profile", profile)
            .put("urls", array)
            .put("targetBytes", targetBytes)
            .put("downloadedBytes", downloadedBytes)
            .put("missingCount", missingCount)
            .put("damagedCount", damagedCount)
            .put("outdatedCount", outdatedCount)
            .put("preloadAuthorized", preloadAuthorized)
            .put("userPaused", userPaused)
            .put("state", state.wireName)
        val temporary = File(stateFile.parentFile ?: return, "${stateFile.name}.tmp")
        temporary.writeText(json.toString())
        try {
            Files.move(temporary.toPath(), stateFile.toPath(), StandardCopyOption.ATOMIC_MOVE, StandardCopyOption.REPLACE_EXISTING)
        } catch (_: Exception) {
            Files.move(temporary.toPath(), stateFile.toPath(), StandardCopyOption.REPLACE_EXISTING)
        }
    }

    private fun restore() {
        if (!stateFile.isFile || stateFile.length() == 0L) return
        runCatching {
            val json = JSONObject(stateFile.readText())
            profile = json.optString("profile", "none")
            val array = json.optJSONArray("urls") ?: JSONArray()
            urls = (0 until array.length()).map { array.getString(it) }
            targetBytes = json.optLong("targetBytes")
            downloadedBytes = json.optLong("downloadedBytes")
            missingCount = json.optInt("missingCount", urls.size)
            damagedCount = json.optInt("damagedCount")
            outdatedCount = json.optInt("outdatedCount")
            preloadAuthorized = json.optBoolean("preloadAuthorized", false)
            userPaused = json.optBoolean("userPaused", false)
            val restored = json.optString("state")
            state = if (restored == GameResourceDownloadState.COMPLETE.wireName) {
                GameResourceDownloadState.COMPLETE
            } else {
                GameResourceDownloadState.PAUSED
            }
            pauseRequested = state == GameResourceDownloadState.PAUSED
        }
    }
}
