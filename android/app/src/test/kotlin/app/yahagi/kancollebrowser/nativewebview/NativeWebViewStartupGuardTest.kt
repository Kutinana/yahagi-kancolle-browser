package app.yahagi.kancollebrowser.nativewebview

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class NativeWebViewStartupGuardTest {
    @Test
    fun firstFailureIsRecordedWithoutFallback() {
        val store = FakeStore()
        val guard = NativeWebViewStartupGuard(store)

        assertEquals(NativeWebViewStartupDecision.STARTED, guard.beginAttempt(100))
        assertEquals(NativeWebViewStartupDecision.FAILURE_RECORDED, guard.recordRenderProcessGone())
        assertEquals(1, store.consecutiveFailures)
        assertNull(store.attemptStartedAtMs)
        assertNull(store.storedRenderingMode)
    }

    @Test
    fun secondConsecutiveFailureFallsBackOnceAndResetsState() {
        val store = FakeStore()
        val guard = NativeWebViewStartupGuard(store)
        guard.beginAttempt(0)
        guard.recordRenderProcessGone()
        guard.beginAttempt(1)

        val decision = guard.recordRenderProcessGone()

        assertEquals(NativeWebViewStartupDecision.FALLBACK_TRIGGERED, decision)
        assertTrue(decision.shouldFallback)
        assertEquals(NativeWebViewStartupGuard.FALLBACK_RENDERING_MODE, store.storedRenderingMode)
        assertEquals(0, store.consecutiveFailures)
        assertNull(store.attemptStartedAtMs)
        assertEquals(NativeWebViewStartupDecision.NO_OP, guard.recordRenderProcessGone())
    }

    @Test
    fun successfulPageLoadClearsPriorFailuresAndIsIdempotentWithoutAttempt() {
        val store = FakeStore(consecutiveFailures = 1)
        val guard = NativeWebViewStartupGuard(store)
        guard.beginAttempt(10)

        assertEquals(NativeWebViewStartupDecision.SUCCESS_RECORDED, guard.recordPageFinished())
        assertEquals(0, store.consecutiveFailures)
        assertNull(store.attemptStartedAtMs)
        assertEquals(NativeWebViewStartupDecision.NO_OP, guard.recordPageFinished())
    }

    @Test
    fun timeoutUsesThirtySecondBoundaryWithoutPrematureFailure() {
        val store = FakeStore()
        val guard = NativeWebViewStartupGuard(store)
        guard.beginAttempt(100)

        assertEquals(NativeWebViewStartupDecision.NO_OP, guard.recordStartupTimeout(30_099))
        assertEquals(NativeWebViewStartupDecision.FAILURE_RECORDED, guard.recordStartupTimeout(30_100))
    }

    @Test
    fun beginAttemptRecoversExpiredPersistedAttemptAndStartsANewOne() {
        val store = FakeStore(attemptStartedAtMs = 100)
        val guard = NativeWebViewStartupGuard(store)

        assertEquals(NativeWebViewStartupDecision.STARTED_AFTER_FAILURE, guard.beginAttempt(30_100))
        assertEquals(1, store.consecutiveFailures)
        assertEquals(30_100L, store.attemptStartedAtMs)
    }

    @Test
    fun activeAttemptIsNotDuplicatedBeforeItsTimeout() {
        val store = FakeStore(attemptStartedAtMs = 100)
        val guard = NativeWebViewStartupGuard(store)

        assertEquals(NativeWebViewStartupDecision.ALREADY_IN_PROGRESS, guard.beginAttempt(30_099))
        assertEquals(100L, store.attemptStartedAtMs)
        assertEquals(0, store.consecutiveFailures)
    }

    @Test
    fun cancellationClearsAttemptWithoutRecordingAFailure() {
        val store = FakeStore()
        val guard = NativeWebViewStartupGuard(store)
        guard.beginAttempt(1)

        assertEquals(NativeWebViewStartupDecision.NO_OP, guard.cancelAttempt())
        assertNull(store.attemptStartedAtMs)
        assertEquals(0, store.consecutiveFailures)
    }

    @Test
    fun clockRollbackDoesNotCauseTimeoutAndNegativeNowIsRejected() {
        val store = FakeStore(attemptStartedAtMs = 1_000)
        val guard = NativeWebViewStartupGuard(store)

        assertEquals(NativeWebViewStartupDecision.NO_OP, guard.recordStartupTimeout(999))
        assertIllegalArgument { guard.beginAttempt(-1) }
        assertIllegalArgument { guard.recordStartupTimeout(-1) }
    }

    @Test
    fun invalidPersistedAttemptTimestampDoesNotBlockANewAttempt() {
        val store = FakeStore(attemptStartedAtMs = -1)
        val guard = NativeWebViewStartupGuard(store)

        assertEquals(NativeWebViewStartupDecision.STARTED, guard.beginAttempt(100))
        assertEquals(100L, store.attemptStartedAtMs)
    }

    @Test
    fun negativePersistedFailuresAreCorrectedBeforeCounting() {
        val store = FakeStore(consecutiveFailures = -20)
        val guard = NativeWebViewStartupGuard(store)
        guard.beginAttempt(0)

        assertEquals(NativeWebViewStartupDecision.FAILURE_RECORDED, guard.recordRenderProcessGone())
        assertEquals(1, store.consecutiveFailures)
    }

    @Test
    fun abnormallyLargePersistedFailureCountCannotOverflow() {
        val store = FakeStore(consecutiveFailures = Int.MAX_VALUE)
        val guard = NativeWebViewStartupGuard(store)
        guard.beginAttempt(0)

        assertEquals(NativeWebViewStartupDecision.FALLBACK_TRIGGERED, guard.recordRenderProcessGone())
        assertEquals(0, store.consecutiveFailures)
    }

    private fun assertIllegalArgument(block: () -> Unit) {
        try {
            block()
        } catch (_: IllegalArgumentException) {
            return
        }
        throw AssertionError("Expected IllegalArgumentException")
    }

    private class FakeStore(
        override var consecutiveFailures: Int = 0,
        override var attemptStartedAtMs: Long? = null,
        override var storedRenderingMode: String? = null,
    ) : NativeWebViewStartupStore
}
