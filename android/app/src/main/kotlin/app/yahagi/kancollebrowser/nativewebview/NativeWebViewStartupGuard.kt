package app.yahagi.kancollebrowser.nativewebview

interface NativeWebViewStartupStore {
    var consecutiveFailures: Int
    var attemptStartedAtMs: Long?
    var storedRenderingMode: String?
}

enum class NativeWebViewStartupDecision {
    STARTED,
    STARTED_AFTER_FAILURE,
    ALREADY_IN_PROGRESS,
    SUCCESS_RECORDED,
    FAILURE_RECORDED,
    FALLBACK_TRIGGERED,
    NO_OP,

    ;

    val shouldFallback: Boolean
        get() = this == FALLBACK_TRIGGERED
}

class NativeWebViewStartupGuard(
    private val store: NativeWebViewStartupStore,
) {
    fun beginAttempt(nowMs: Long): NativeWebViewStartupDecision {
        requireValidNow(nowMs)

        val startedAtMs = store.attemptStartedAtMs
        if (startedAtMs != null && startedAtMs < 0L) {
            store.attemptStartedAtMs = nowMs
            return NativeWebViewStartupDecision.STARTED
        }
        if (startedAtMs != null) {
            if (!hasTimedOut(startedAtMs, nowMs)) {
                return NativeWebViewStartupDecision.ALREADY_IN_PROGRESS
            }

            val failureDecision = recordFailure()
            if (failureDecision == NativeWebViewStartupDecision.FALLBACK_TRIGGERED) {
                return failureDecision
            }
            store.attemptStartedAtMs = nowMs
            return NativeWebViewStartupDecision.STARTED_AFTER_FAILURE
        }

        store.attemptStartedAtMs = nowMs
        return NativeWebViewStartupDecision.STARTED
    }

    fun recordPageFinished(): NativeWebViewStartupDecision {
        if (store.attemptStartedAtMs == null) {
            return NativeWebViewStartupDecision.NO_OP
        }

        store.attemptStartedAtMs = null
        store.consecutiveFailures = 0
        return NativeWebViewStartupDecision.SUCCESS_RECORDED
    }

    fun recordRenderProcessGone(): NativeWebViewStartupDecision {
        if (store.attemptStartedAtMs == null) {
            return NativeWebViewStartupDecision.NO_OP
        }

        return recordFailure()
    }

    fun recordStartupTimeout(nowMs: Long): NativeWebViewStartupDecision {
        requireValidNow(nowMs)

        val startedAtMs = store.attemptStartedAtMs ?: return NativeWebViewStartupDecision.NO_OP
        if (!hasTimedOut(startedAtMs, nowMs)) {
            return NativeWebViewStartupDecision.NO_OP
        }

        return recordFailure()
    }

    fun cancelAttempt(): NativeWebViewStartupDecision {
        store.attemptStartedAtMs = null
        return NativeWebViewStartupDecision.NO_OP
    }

    private fun recordFailure(): NativeWebViewStartupDecision {
        store.attemptStartedAtMs = null
        val failures = store.consecutiveFailures.coerceAtLeast(0)
        if (failures >= FAILURE_THRESHOLD - 1) {
            store.storedRenderingMode = FALLBACK_RENDERING_MODE
            store.consecutiveFailures = 0
            return NativeWebViewStartupDecision.FALLBACK_TRIGGERED
        }

        store.consecutiveFailures = failures + 1
        return NativeWebViewStartupDecision.FAILURE_RECORDED
    }

    private fun hasTimedOut(startedAtMs: Long, nowMs: Long): Boolean {
        if (startedAtMs < 0L || nowMs < startedAtMs) {
            return false
        }
        return nowMs - startedAtMs >= STARTUP_TIMEOUT_MS
    }

    private fun requireValidNow(nowMs: Long) {
        require(nowMs >= 0L) { "nowMs must be non-negative" }
    }

    companion object {
        const val FAILURE_THRESHOLD = 2
        const val STARTUP_TIMEOUT_MS = 30_000L
        const val FALLBACK_RENDERING_MODE = "compatibility"
        const val CONSECUTIVE_FAILURES_KEY = "nativeWebView.consecutiveStartupFailures"
        const val LAST_STARTUP_STARTED_AT_MS_KEY = "nativeWebView.lastStartupStartedAtMs"
        const val RENDERING_MODE_KEY = "flutter.game.renderingMode"
    }
}
