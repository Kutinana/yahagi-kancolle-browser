package app.yahagi.kancollebrowser.browser

import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.nio.file.Files
import java.nio.file.StandardCopyOption
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

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
    val capacityBlocked: Boolean,
)

class GameResourceDownloadCoordinator(
    private val engine: GameResourceCacheEngine,
    private val modeProvider: () -> GameResourceCacheMode,
    private val stateFile: File,
) {
    private val executor = Executors.newSingleThreadExecutor { runnable ->
        Thread(runnable, "game-resource-preloader").apply { isDaemon = true }
    }
    private val workerRunning = AtomicBoolean(false)
    @Volatile private var pauseRequested = false
    private var profile = "none"
    private var urls = emptyList<String>()
    private var targetBytes = 0L
    private var downloadedBytes = 0L
    private var startedAt = 0L
    private var missingCount = 0
    private var damagedCount = 0
    private var state = GameResourceDownloadState.IDLE

    init {
        restore()
    }

    @Synchronized
    fun setManifest(profile: String, candidates: List<String>, targetBytes: Long) {
        this.profile = profile
        urls = candidates.asSequence()
            .filter { GameResourceCacheRules.shouldCache(it, "GET") }
            .distinct()
            .toList()
        this.targetBytes = targetBytes.coerceAtLeast(0)
        downloadedBytes = 0
        missingCount = urls.count { !engine.hasCached(it) }
        damagedCount = 0
        state = if (missingCount == 0 && urls.isNotEmpty()) {
            GameResourceDownloadState.COMPLETE
        } else {
            GameResourceDownloadState.IDLE
        }
        pauseRequested = false
        persist()
    }

    @Synchronized
    fun startDownload(): Boolean {
        val mode = modeProvider()
        if (mode == GameResourceCacheMode.NONE || urls.isEmpty()) return false
        if (mode == GameResourceCacheMode.FULL && targetBytes > engine.status().maxBytes) {
            state = GameResourceDownloadState.CAPACITY_BLOCKED
            pauseRequested = true
            persist()
            return false
        }
        pauseRequested = false
        state = GameResourceDownloadState.DOWNLOADING
        if (startedAt == 0L) startedAt = System.currentTimeMillis()
        persist()
        if (workerRunning.compareAndSet(false, true)) executor.execute(::downloadLoop)
        return true
    }

    @Synchronized
    fun pauseDownload(): Boolean {
        pauseRequested = true
        state = GameResourceDownloadState.PAUSED
        persist()
        return true
    }

    fun checkIntegrity(): GameResourceDownloadStatus {
        synchronized(this) {
            state = GameResourceDownloadState.CHECKING
        }
        val missing = urls.count { !engine.hasCached(it) }
        synchronized(this) {
            missingCount = missing
            damagedCount = 0
            state = when {
                pauseRequested -> GameResourceDownloadState.PAUSED
                missing == 0 && urls.isNotEmpty() -> GameResourceDownloadState.COMPLETE
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
        val cached = engine.status().usedBytes
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
            capacityBlocked = state == GameResourceDownloadState.CAPACITY_BLOCKED,
        )
    }

    fun dispose() {
        pauseDownload()
        executor.shutdownNow()
    }

    private fun downloadLoop() {
        try {
            for (url in urls) {
                if (pauseRequested) return
                if (engine.hasCached(url)) continue
                val before = engine.status()
                val response = engine.fetch(url) ?: continue
                if (response.source == GameResourceResponseSource.NETWORK) {
                    synchronized(this) { downloadedBytes += response.bytes.size }
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
                if (!pauseRequested) {
                    missingCount = urls.count { !engine.hasCached(it) }
                    state = if (missingCount == 0) GameResourceDownloadState.COMPLETE else GameResourceDownloadState.ERROR
                    persist()
                }
            }
        } finally {
            workerRunning.set(false)
            if (!pauseRequested && state == GameResourceDownloadState.DOWNLOADING && workerRunning.compareAndSet(false, true)) {
                executor.execute(::downloadLoop)
            }
        }
    }

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
