package app.yahagi.kancollebrowser.nativewebview

@JvmInline
value class NativeWebViewProcessSessionId(
    val value: String,
) {
    init {
        require(value.isNotEmpty()) { "session id must not be empty" }
    }
}

data class NativeWebViewStartupSnapshot(
    val consecutiveFailures: Int,
    val attemptStartedAtMs: Long?,
    val attemptSessionId: NativeWebViewProcessSessionId?,
    val storedRenderingMode: String?,
)

sealed interface NativeWebViewStartupReadResult {
    data class Success(
        val snapshot: NativeWebViewStartupSnapshot,
    ) : NativeWebViewStartupReadResult

    data object Unavailable : NativeWebViewStartupReadResult
}

sealed interface NativeWebViewStartupWriteResult {
    data object Durable : NativeWebViewStartupWriteResult

    /** The process may have observed the update, but its durable state is unknown. */
    data object Indeterminate : NativeWebViewStartupWriteResult

    /** The adapter knows that it did not commit the update. */
    data object Failed : NativeWebViewStartupWriteResult
}

interface NativeWebViewStartupStore {
    /**
     * Reads one complete snapshot. Adapters must return [NativeWebViewStartupReadResult.Unavailable]
     * rather than leak storage exceptions.
     */
    fun read(): NativeWebViewStartupReadResult

    /**
     * Atomically writes one complete snapshot. If a backing commit returns false, return
     * [NativeWebViewStartupWriteResult.Indeterminate], poison this process's subsequent reads as
     * unavailable, and let a new process reload disk state.
     */
    fun write(nextSnapshot: NativeWebViewStartupSnapshot): NativeWebViewStartupWriteResult
}

sealed interface NativeWebViewStartupDecision {
    val shouldFallback: Boolean
        get() = false

    val shouldStart: Boolean
        get() = false

    data class Started(
        val previousFailureRecorded: Boolean,
    ) : NativeWebViewStartupDecision {
        override val shouldStart: Boolean
            get() = true
    }

    data class AlreadyInProgress(
        val remainingMs: Long,
    ) : NativeWebViewStartupDecision

    data object Succeeded : NativeWebViewStartupDecision
    data object FailureRecorded : NativeWebViewStartupDecision

    data object FallbackTriggered : NativeWebViewStartupDecision {
        override val shouldFallback: Boolean
            get() = true
    }

    /** Compatibility fallback is already durable; do not restart native WebView startup. */
    data object FallbackActive : NativeWebViewStartupDecision

    data object Cancelled : NativeWebViewStartupDecision
    data object NoActiveAttempt : NativeWebViewStartupDecision

    data class NotTimedOut(
        val remainingMs: Long,
    ) : NativeWebViewStartupDecision

    data object PersistenceFailed : NativeWebViewStartupDecision
    data object PersistenceIndeterminate : NativeWebViewStartupDecision
}

class NativeWebViewStartupGuard(
    private val store: NativeWebViewStartupStore,
    /** Process-scoped token: reuse for Activity recreation; generate a new value after process restart. */
    private val sessionId: NativeWebViewProcessSessionId,
) {
    fun beginAttempt(nowMs: Long): NativeWebViewStartupDecision {
        requireValidNow(nowMs)
        val snapshot = readSnapshot() ?: return NativeWebViewStartupDecision.PersistenceFailed
        if (snapshot.storedRenderingMode == FALLBACK_RENDERING_MODE) {
            return NativeWebViewStartupDecision.FallbackActive
        }
        val startedAtMs = snapshot.attemptStartedAtMs
        if (startedAtMs == null) {
            return writeStarted(snapshot, nowMs, previousFailureRecorded = false)
        }

        if (snapshot.attemptSessionId == sessionId && startedAtMs >= 0L && nowMs >= startedAtMs) {
            // These timestamps come from a single process session's monotonic clock only.
            val elapsedMs = nowMs - startedAtMs
            if (elapsedMs < STARTUP_TIMEOUT_MS) {
                return NativeWebViewStartupDecision.AlreadyInProgress(STARTUP_TIMEOUT_MS - elapsedMs)
            }
            return writeFailureAndStart(snapshot, nowMs)
        }
        if (snapshot.attemptSessionId == sessionId) {
            return writeStarted(snapshot, nowMs, previousFailureRecorded = false)
        }

        // Sessions are process-local. Never compare monotonic timestamps across sessions.
        return writeFailureAndStart(snapshot, nowMs)
    }

    fun recordPageFinished(): NativeWebViewStartupDecision {
        val snapshot = readSnapshot() ?: return NativeWebViewStartupDecision.PersistenceFailed
        if (!isCurrentAttempt(snapshot)) return NativeWebViewStartupDecision.NoActiveAttempt
        return write(
            snapshot.copy(consecutiveFailures = 0, attemptStartedAtMs = null, attemptSessionId = null),
            NativeWebViewStartupDecision.Succeeded,
        )
    }

    fun recordRenderProcessGone(): NativeWebViewStartupDecision {
        val snapshot = readSnapshot() ?: return NativeWebViewStartupDecision.PersistenceFailed
        if (!isCurrentAttempt(snapshot)) return NativeWebViewStartupDecision.NoActiveAttempt
        return writeFailure(snapshot)
    }

    fun recordStartupTimeout(nowMs: Long): NativeWebViewStartupDecision {
        requireValidNow(nowMs)
        val snapshot = readSnapshot() ?: return NativeWebViewStartupDecision.PersistenceFailed
        if (!isCurrentAttempt(snapshot)) return NativeWebViewStartupDecision.NoActiveAttempt
        val startedAtMs = snapshot.attemptStartedAtMs!!
        if (nowMs < startedAtMs) return NativeWebViewStartupDecision.NotTimedOut(STARTUP_TIMEOUT_MS)
        val elapsedMs = nowMs - startedAtMs
        if (elapsedMs < STARTUP_TIMEOUT_MS) return NativeWebViewStartupDecision.NotTimedOut(STARTUP_TIMEOUT_MS - elapsedMs)
        return writeFailure(snapshot)
    }

    fun cancelAttempt(): NativeWebViewStartupDecision {
        val snapshot = readSnapshot() ?: return NativeWebViewStartupDecision.PersistenceFailed
        if (snapshot.attemptStartedAtMs == null && snapshot.attemptSessionId == null) {
            return NativeWebViewStartupDecision.NoActiveAttempt
        }
        return write(snapshot.copy(attemptStartedAtMs = null, attemptSessionId = null), NativeWebViewStartupDecision.Cancelled)
    }

    private fun writeStarted(snapshot: NativeWebViewStartupSnapshot, nowMs: Long, previousFailureRecorded: Boolean) =
        write(
            snapshot.copy(
                consecutiveFailures = normalizedFailures(snapshot),
                attemptStartedAtMs = nowMs,
                attemptSessionId = sessionId,
            ),
            NativeWebViewStartupDecision.Started(previousFailureRecorded),
        )

    private fun writeFailureAndStart(snapshot: NativeWebViewStartupSnapshot, nowMs: Long): NativeWebViewStartupDecision {
        val failures = normalizedFailures(snapshot)
        if (failures >= FAILURE_THRESHOLD - 1) return writeFallback(snapshot)
        return write(
            snapshot.copy(consecutiveFailures = failures + 1, attemptStartedAtMs = nowMs, attemptSessionId = sessionId),
            NativeWebViewStartupDecision.Started(previousFailureRecorded = true),
        )
    }

    private fun writeFailure(snapshot: NativeWebViewStartupSnapshot): NativeWebViewStartupDecision {
        val failures = normalizedFailures(snapshot)
        if (failures >= FAILURE_THRESHOLD - 1) return writeFallback(snapshot)
        return write(
            snapshot.copy(consecutiveFailures = failures + 1, attemptStartedAtMs = null, attemptSessionId = null),
            NativeWebViewStartupDecision.FailureRecorded,
        )
    }

    private fun writeFallback(snapshot: NativeWebViewStartupSnapshot) =
        write(
            snapshot.copy(
                consecutiveFailures = 0,
                attemptStartedAtMs = null,
                attemptSessionId = null,
                storedRenderingMode = FALLBACK_RENDERING_MODE,
            ),
            NativeWebViewStartupDecision.FallbackTriggered,
        )

    private fun readSnapshot(): NativeWebViewStartupSnapshot? =
        try {
            (store.read() as? NativeWebViewStartupReadResult.Success)?.snapshot
        } catch (_: Exception) {
            null
        }

    private fun write(nextSnapshot: NativeWebViewStartupSnapshot, success: NativeWebViewStartupDecision): NativeWebViewStartupDecision =
        try {
            when (store.write(nextSnapshot)) {
                NativeWebViewStartupWriteResult.Durable -> success
                NativeWebViewStartupWriteResult.Failed -> NativeWebViewStartupDecision.PersistenceFailed
                NativeWebViewStartupWriteResult.Indeterminate -> NativeWebViewStartupDecision.PersistenceIndeterminate
            }
        } catch (_: Exception) {
            NativeWebViewStartupDecision.PersistenceIndeterminate
        }

    private fun isCurrentAttempt(snapshot: NativeWebViewStartupSnapshot) =
        snapshot.attemptStartedAtMs != null && snapshot.attemptSessionId == sessionId

    private fun normalizedFailures(snapshot: NativeWebViewStartupSnapshot) = snapshot.consecutiveFailures.coerceAtLeast(0)

    private fun requireValidNow(nowMs: Long) {
        require(nowMs >= 0L) { "nowMs must be non-negative" }
    }

    companion object {
        const val FAILURE_THRESHOLD = 2
        const val STARTUP_TIMEOUT_MS = 30_000L
        const val FALLBACK_RENDERING_MODE = "compatibility"
        const val CONSECUTIVE_FAILURES_KEY = "nativeWebView.consecutiveStartupFailures"
        const val LAST_STARTUP_STARTED_AT_MS_KEY = "nativeWebView.lastStartupStartedAtMs"
        const val ATTEMPT_SESSION_ID_KEY = "nativeWebView.lastStartupAttemptSessionId"
        const val RENDERING_MODE_KEY = "flutter.game.renderingMode"
    }
}
