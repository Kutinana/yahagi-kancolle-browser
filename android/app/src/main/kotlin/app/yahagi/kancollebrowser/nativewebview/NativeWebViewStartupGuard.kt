package app.yahagi.kancollebrowser.nativewebview

data class NativeWebViewStartupSnapshot(
    val consecutiveFailures: Int,
    val attemptStartedAtMs: Long?,
    val attemptSessionId: String?,
    val storedRenderingMode: String?,
)

interface NativeWebViewStartupStore {
    fun read(): NativeWebViewStartupSnapshot?

    /** A failed write must leave the stored snapshot unchanged. */
    fun write(nextSnapshot: NativeWebViewStartupSnapshot): Boolean
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

    data object Cancelled : NativeWebViewStartupDecision

    data object NoActiveAttempt : NativeWebViewStartupDecision

    data class NotTimedOut(
        val remainingMs: Long,
    ) : NativeWebViewStartupDecision

    data object PersistenceFailed : NativeWebViewStartupDecision
}

class NativeWebViewStartupGuard(
    private val store: NativeWebViewStartupStore,
    private val sessionId: String,
) {
    init {
        require(sessionId.isNotEmpty()) { "sessionId must not be empty" }
    }

    fun beginAttempt(nowMs: Long): NativeWebViewStartupDecision {
        requireValidNow(nowMs)
        val snapshot = store.read() ?: return NativeWebViewStartupDecision.PersistenceFailed
        val startedAtMs = snapshot.attemptStartedAtMs
        if (startedAtMs == null) {
            return writeStarted(snapshot, nowMs, previousFailureRecorded = false)
        }

        if (snapshot.attemptSessionId == sessionId && startedAtMs >= 0L && nowMs >= startedAtMs) {
            // These timestamps come from one process session's monotonic clock only.
            val elapsedMs = nowMs - startedAtMs
            if (elapsedMs < STARTUP_TIMEOUT_MS) {
                return NativeWebViewStartupDecision.AlreadyInProgress(STARTUP_TIMEOUT_MS - elapsedMs)
            }
            return writeFailureAndStart(snapshot, nowMs)
        }

        if (snapshot.attemptSessionId == sessionId) {
            // Same-session clock rollback/corruption: recover without charging a failure.
            return writeStarted(snapshot, nowMs, previousFailureRecorded = false)
        }

        // Sessions are process-local. Never compare monotonic timestamps across sessions.
        return writeFailureAndStart(snapshot, nowMs)
    }

    fun recordPageFinished(): NativeWebViewStartupDecision {
        val snapshot = store.read() ?: return NativeWebViewStartupDecision.PersistenceFailed
        if (!isCurrentAttempt(snapshot)) {
            return NativeWebViewStartupDecision.NoActiveAttempt
        }

        val nextSnapshot = snapshot.copy(
            consecutiveFailures = 0,
            attemptStartedAtMs = null,
            attemptSessionId = null,
        )
        return write(nextSnapshot, NativeWebViewStartupDecision.Succeeded)
    }

    fun recordRenderProcessGone(): NativeWebViewStartupDecision {
        val snapshot = store.read() ?: return NativeWebViewStartupDecision.PersistenceFailed
        if (!isCurrentAttempt(snapshot)) {
            return NativeWebViewStartupDecision.NoActiveAttempt
        }

        return writeFailure(snapshot)
    }

    fun recordStartupTimeout(nowMs: Long): NativeWebViewStartupDecision {
        requireValidNow(nowMs)
        val snapshot = store.read() ?: return NativeWebViewStartupDecision.PersistenceFailed
        if (!isCurrentAttempt(snapshot)) {
            return NativeWebViewStartupDecision.NoActiveAttempt
        }

        val startedAtMs = snapshot.attemptStartedAtMs!!
        if (nowMs < startedAtMs) {
            return NativeWebViewStartupDecision.NotTimedOut(STARTUP_TIMEOUT_MS)
        }
        val elapsedMs = nowMs - startedAtMs
        if (elapsedMs < STARTUP_TIMEOUT_MS) {
            return NativeWebViewStartupDecision.NotTimedOut(STARTUP_TIMEOUT_MS - elapsedMs)
        }
        return writeFailure(snapshot)
    }

    fun cancelAttempt(): NativeWebViewStartupDecision {
        val snapshot = store.read() ?: return NativeWebViewStartupDecision.PersistenceFailed
        if (snapshot.attemptStartedAtMs == null && snapshot.attemptSessionId == null) {
            return NativeWebViewStartupDecision.NoActiveAttempt
        }

        val nextSnapshot = snapshot.copy(attemptStartedAtMs = null, attemptSessionId = null)
        return write(nextSnapshot, NativeWebViewStartupDecision.Cancelled)
    }

    private fun writeStarted(
        snapshot: NativeWebViewStartupSnapshot,
        nowMs: Long,
        previousFailureRecorded: Boolean,
    ): NativeWebViewStartupDecision {
        val nextSnapshot = snapshot.copy(
            consecutiveFailures = normalizedFailures(snapshot),
            attemptStartedAtMs = nowMs,
            attemptSessionId = sessionId,
        )
        return write(nextSnapshot, NativeWebViewStartupDecision.Started(previousFailureRecorded))
    }

    private fun writeFailureAndStart(
        snapshot: NativeWebViewStartupSnapshot,
        nowMs: Long,
    ): NativeWebViewStartupDecision {
        val failures = normalizedFailures(snapshot)
        if (failures >= FAILURE_THRESHOLD - 1) {
            return writeFallback(snapshot)
        }

        val nextSnapshot = snapshot.copy(
            consecutiveFailures = failures + 1,
            attemptStartedAtMs = nowMs,
            attemptSessionId = sessionId,
        )
        return write(nextSnapshot, NativeWebViewStartupDecision.Started(previousFailureRecorded = true))
    }

    private fun writeFailure(snapshot: NativeWebViewStartupSnapshot): NativeWebViewStartupDecision {
        val failures = normalizedFailures(snapshot)
        if (failures >= FAILURE_THRESHOLD - 1) {
            return writeFallback(snapshot)
        }

        val nextSnapshot = snapshot.copy(
            consecutiveFailures = failures + 1,
            attemptStartedAtMs = null,
            attemptSessionId = null,
        )
        return write(nextSnapshot, NativeWebViewStartupDecision.FailureRecorded)
    }

    private fun writeFallback(snapshot: NativeWebViewStartupSnapshot): NativeWebViewStartupDecision =
        write(
            snapshot.copy(
                consecutiveFailures = 0,
                attemptStartedAtMs = null,
                attemptSessionId = null,
                storedRenderingMode = FALLBACK_RENDERING_MODE,
            ),
            NativeWebViewStartupDecision.FallbackTriggered,
        )

    private fun write(
        nextSnapshot: NativeWebViewStartupSnapshot,
        successDecision: NativeWebViewStartupDecision,
    ): NativeWebViewStartupDecision =
        if (store.write(nextSnapshot)) successDecision else NativeWebViewStartupDecision.PersistenceFailed

    private fun isCurrentAttempt(snapshot: NativeWebViewStartupSnapshot): Boolean =
        snapshot.attemptStartedAtMs != null && snapshot.attemptSessionId == sessionId

    private fun normalizedFailures(snapshot: NativeWebViewStartupSnapshot): Int =
        snapshot.consecutiveFailures.coerceAtLeast(0)

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
