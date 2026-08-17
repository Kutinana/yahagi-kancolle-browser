package app.yahagi.kancollebrowser.browser

import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.nio.file.Files
import java.nio.file.StandardCopyOption
import java.util.concurrent.Executors
import java.util.concurrent.RejectedExecutionException
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

class GameResourcePreparedManifest internal constructor(
    val profile: String,
    val urls: List<String>,
    val targetBytes: Long,
    internal val validByteLengths: Map<String, Long>,
    internal val missingCount: Int,
    internal val damagedCount: Int,
    internal val outdatedCount: Int,
    internal val temporaryFile: File,
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
    private val disposed = AtomicBoolean(false)
    private val generation = AtomicLong(0)
    @Volatile private var pauseRequested = false
    @Volatile private var networkPaused = false
    @Volatile private var allowMetered = false
    @Volatile private var userPaused = false
    private var profile = "none"
    private var urls = emptyList<String>()
    private var manifestLoaded = false
    private val manifestFile = File(
        stateFile.parentFile ?: File("."),
        "${stateFile.name}.manifest.json",
    )
    private val manifestBackupFile = File(
        stateFile.parentFile ?: File("."),
        "${stateFile.name}.manifest.json.bak",
    )
    private var targetBytes = 0L
    private var downloadedBytes = 0L
    private var startedAt = 0L
    private var missingCount = 0
    private var damagedCount = 0
    private var outdatedCount = 0
    private var validByteLengths = linkedMapOf<String, Long>()
    private var state = GameResourceDownloadState.IDLE
    private var preloadAuthorized = false

    init {
        restore()
    }

    fun setManifest(profile: String, candidates: List<String>, targetBytes: Long) {
        val prepared = prepareManifest(profile, candidates, targetBytes)
        try {
            applyPreparedManifest(prepared)
        } finally {
            discardPreparedManifest(prepared)
        }
    }

    fun prepareManifest(
        profile: String,
        candidates: List<String>,
        targetBytes: Long,
    ): GameResourcePreparedManifest {
        check(!disposed.get()) { "Resource cache coordinator is disposed" }
        val filteredUrls = candidates.asSequence()
            .filter { GameResourceCacheRules.shouldCache(it, "GET") }
            .distinct()
            .toList()
        val validLengths = linkedMapOf<String, Long>()
        var missing = 0
        var damaged = 0
        var outdated = 0
        filteredUrls.forEach { url ->
            val inspection = engine.inspect(url)
            when (inspection.state) {
                GameResourceInspectionState.VALID -> validLengths[url] = inspection.byteLength
                GameResourceInspectionState.MISSING -> missing++
                GameResourceInspectionState.DAMAGED -> damaged++
                GameResourceInspectionState.OUTDATED -> outdated++
            }
        }
        val temporary = writeManifestTemporary(profile, filteredUrls, targetBytes.coerceAtLeast(0))
        return GameResourcePreparedManifest(
            profile = profile,
            urls = filteredUrls,
            targetBytes = targetBytes.coerceAtLeast(0),
            validByteLengths = validLengths,
            missingCount = missing,
            damagedCount = damaged,
            outdatedCount = outdated,
            temporaryFile = temporary,
        )
    }

    @Synchronized
    fun applyPreparedManifest(prepared: GameResourcePreparedManifest) {
        check(applyPreparedManifestIf(prepared) { true }) {
            "Resource cache coordinator is disposed"
        }
    }

    @Synchronized
    fun applyPreparedManifestIf(
        prepared: GameResourcePreparedManifest,
        isCurrent: () -> Boolean,
    ): Boolean {
        if (disposed.get() || !isCurrent()) return false
        val hadManifest = manifestFile.isFile
        installPreparedManifest(prepared.temporaryFile)
        if (disposed.get() || !isCurrent()) {
            restorePreviousManifest(hadManifest)
            return false
        }
        val previous = snapshotState()
        val profileChanged = this.profile != prepared.profile
        generation.incrementAndGet()
        this.profile = prepared.profile
        urls = prepared.urls
        manifestLoaded = true
        this.targetBytes = prepared.targetBytes
        downloadedBytes = 0
        if (profileChanged) {
            preloadAuthorized = false
            userPaused = false
        }
        validByteLengths = LinkedHashMap(prepared.validByteLengths)
        missingCount = prepared.missingCount
        damagedCount = prepared.damagedCount
        outdatedCount = prepared.outdatedCount
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
        if (disposed.get() || !isCurrent()) {
            generation.incrementAndGet()
            restoreState(previous)
            restorePreviousManifest(hadManifest)
            persist()
            return false
        }
        return true
    }

    fun discardPreparedManifest(prepared: GameResourcePreparedManifest) {
        prepared.temporaryFile.delete()
    }

    @Synchronized
    fun configureModeChange(isDisabled: Boolean, isCurrent: () -> Boolean): Boolean {
        if (disposed.get() || !isCurrent()) return false
        generation.incrementAndGet()
        pauseRequested = true
        networkPaused = false
        if (isDisabled) {
            userPaused = true
            state = GameResourceDownloadState.PAUSED
        } else {
            state = GameResourceDownloadState.IDLE
        }
        persist()
        return true
    }

    @Synchronized
    fun startDownload(allowMetered: Boolean = false): Boolean {
        if (disposed.get()) return false
        preloadAuthorized = true
        userPaused = false
        return startDownloadInternal(allowMetered)
    }

    @Synchronized
    fun startAutoUpdate(): Boolean {
        if (disposed.get()) return false
        if (!preloadAuthorized || userPaused) return false
        return startDownloadInternal(allowMetered = false)
    }

    private fun startDownloadInternal(allowMetered: Boolean): Boolean {
        val mode = modeProvider()
        ensureManifestLoaded()
        if (mode == GameResourceCacheMode.NONE || urls.isEmpty()) return false
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
            scheduleDownload(currentGeneration)
        }
        return true
    }

    @Synchronized
    fun pauseDownload(): Boolean {
        if (disposed.get()) return false
        userPaused = true
        networkPaused = false
        pauseRequested = true
        state = GameResourceDownloadState.PAUSED
        persist()
        return true
    }

    fun onNetworkChanged() {
        if (disposed.get()) return
        try {
            executor.execute { handleNetworkChanged() }
        } catch (_: RejectedExecutionException) {
            // A connectivity callback may already be in flight during disposal.
        }
    }

    @Synchronized
    private fun handleNetworkChanged() {
        if (disposed.get()) return
        ensureManifestLoaded(refreshInspection = true)
        if (!canUseCurrentNetwork()) {
            if (preloadAuthorized && !userPaused) {
                networkPaused = true
                pauseRequested = true
                state = GameResourceDownloadState.PAUSED
                persist()
            }
            return
        }
        if (!preloadAuthorized || userPaused) return
        startDownloadInternal(allowMetered = false)
    }

    fun checkIntegrity(): GameResourceDownloadStatus {
        synchronized(this) {
            ensureManifestLoaded()
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
        ensureManifestLoaded(refreshInspection = true)
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
        if (!disposed.compareAndSet(false, true)) return
        pauseRequested = true
        generation.incrementAndGet()
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
                synchronized(this) { persist() }
            }
            synchronized(this) {
                if (!pauseRequested && workerGeneration == generation.get()) {
                    refreshInspectionCounts()
                    state = if (missingCount == 0 && damagedCount == 0 && outdatedCount == 0) {
                        GameResourceDownloadState.COMPLETE
                    } else {
                        GameResourceDownloadState.IDLE
                    }
                    persist()
                }
            }
        } finally {
            workerRunning.set(false)
            if (!disposed.get() && !pauseRequested && state == GameResourceDownloadState.DOWNLOADING && workerRunning.compareAndSet(false, true)) {
                val currentGeneration = generation.get()
                scheduleDownload(currentGeneration)
            }
        }
    }

    private fun scheduleDownload(workerGeneration: Long) {
        try {
            executor.execute { downloadLoop(workerGeneration) }
        } catch (_: RejectedExecutionException) {
            workerRunning.set(false)
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

    private fun ensureManifestLoaded(refreshInspection: Boolean = false) {
        if (manifestLoaded) return
        manifestLoaded = loadManifest(manifestFile) || loadManifest(manifestBackupFile)
        if (manifestLoaded && refreshInspection) {
            refreshInspectionCounts()
            state = when {
                userPaused || networkPaused -> GameResourceDownloadState.PAUSED
                missingCount == 0 && damagedCount == 0 && outdatedCount == 0 && urls.isNotEmpty() ->
                    GameResourceDownloadState.COMPLETE
                else -> GameResourceDownloadState.IDLE
            }
        }
    }

    private fun loadManifest(file: File): Boolean {
        if (!file.isFile || file.length() == 0L) return false
        return runCatching {
            val json = JSONObject(file.readText())
            if (json.optString("profile") != profile) return@runCatching false
            val array = json.optJSONArray("urls") ?: return@runCatching false
            urls = (0 until array.length())
                .asSequence()
                .map(array::getString)
                .filter { GameResourceCacheRules.shouldCache(it, "GET") }
                .distinct()
                .toList()
            targetBytes = json.optLong("targetBytes", targetBytes).coerceAtLeast(0L)
            true
        }.getOrDefault(false)
    }

    private fun writeManifestTemporary(
        profile: String,
        urls: List<String>,
        targetBytes: Long,
    ): File {
        manifestFile.parentFile?.mkdirs()
        val array = JSONArray()
        urls.forEach(array::put)
        val json = JSONObject()
            .put("version", 1)
            .put("profile", profile)
            .put("targetBytes", targetBytes)
            .put("urls", array)
        val parent = manifestFile.parentFile ?: File(".")
        val temporary = File.createTempFile("${manifestFile.name}.", ".tmp", parent)
        try {
            temporary.writeText(json.toString())
        } catch (error: Exception) {
            temporary.delete()
            throw error
        }
        return temporary
    }

    private fun installPreparedManifest(temporary: File) {
        if (manifestFile.isFile) {
            Files.copy(
                manifestFile.toPath(),
                manifestBackupFile.toPath(),
                StandardCopyOption.REPLACE_EXISTING,
            )
        }
        try {
            Files.move(
                temporary.toPath(),
                manifestFile.toPath(),
                StandardCopyOption.ATOMIC_MOVE,
                StandardCopyOption.REPLACE_EXISTING,
            )
        } catch (_: Exception) {
            Files.move(
                temporary.toPath(),
                manifestFile.toPath(),
                StandardCopyOption.REPLACE_EXISTING,
            )
        }
    }

    private fun restorePreviousManifest(hadManifest: Boolean) {
        if (hadManifest && manifestBackupFile.isFile) {
            Files.copy(
                manifestBackupFile.toPath(),
                manifestFile.toPath(),
                StandardCopyOption.REPLACE_EXISTING,
            )
        } else {
            manifestFile.delete()
        }
    }

    private fun snapshotState() = CoordinatorStateSnapshot(
        profile = profile,
        urls = urls,
        manifestLoaded = manifestLoaded,
        targetBytes = targetBytes,
        downloadedBytes = downloadedBytes,
        missingCount = missingCount,
        damagedCount = damagedCount,
        outdatedCount = outdatedCount,
        validByteLengths = validByteLengths,
        state = state,
        preloadAuthorized = preloadAuthorized,
        pauseRequested = pauseRequested,
        networkPaused = networkPaused,
        allowMetered = allowMetered,
        userPaused = userPaused,
    )

    private fun restoreState(snapshot: CoordinatorStateSnapshot) {
        profile = snapshot.profile
        urls = snapshot.urls
        manifestLoaded = snapshot.manifestLoaded
        targetBytes = snapshot.targetBytes
        downloadedBytes = snapshot.downloadedBytes
        missingCount = snapshot.missingCount
        damagedCount = snapshot.damagedCount
        outdatedCount = snapshot.outdatedCount
        validByteLengths = snapshot.validByteLengths
        state = snapshot.state
        preloadAuthorized = snapshot.preloadAuthorized
        pauseRequested = snapshot.pauseRequested
        networkPaused = snapshot.networkPaused
        allowMetered = snapshot.allowMetered
        userPaused = snapshot.userPaused
    }

    @Synchronized
    private fun persist() {
        stateFile.parentFile?.mkdirs()
        val json = JSONObject()
            .put("version", 2)
            .put("profile", profile)
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
        if (stateFile.length() > MAX_STATE_FILE_BYTES) {
            stateFile.delete()
            return
        }
        runCatching {
            val json = JSONObject(stateFile.readText())
            profile = json.optString("profile", "none")
            urls = emptyList()
            manifestLoaded = false
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
            networkPaused = preloadAuthorized && !userPaused && state != GameResourceDownloadState.COMPLETE
        }
    }

    companion object {
        private const val MAX_STATE_FILE_BYTES = 256L * 1024L
    }

    private data class CoordinatorStateSnapshot(
        val profile: String,
        val urls: List<String>,
        val manifestLoaded: Boolean,
        val targetBytes: Long,
        val downloadedBytes: Long,
        val missingCount: Int,
        val damagedCount: Int,
        val outdatedCount: Int,
        val validByteLengths: LinkedHashMap<String, Long>,
        val state: GameResourceDownloadState,
        val preloadAuthorized: Boolean,
        val pauseRequested: Boolean,
        val networkPaused: Boolean,
        val allowMetered: Boolean,
        val userPaused: Boolean,
    )
}
