package app.yahagi.kancollebrowser.nativewebview

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class NativeWebViewStartupGuardTest {
    @Test
    fun sameProcessSessionSurvivesActivityRecreationWithoutCountingFailure() {
        val store = FakeStore(snapshot = snapshot(attemptStartedAtMs = 100, attemptSessionId = session("a")))

        assertEquals(NativeWebViewStartupDecision.AlreadyInProgress(29_999), guard(store, "a").beginAttempt(101))
        assertEquals(NativeWebViewStartupDecision.AlreadyInProgress(29_999), guard(store, "a").beginAttempt(101))
        assertEquals(0, store.writes.size)
    }

    @Test
    fun differentProcessSessionImmediatelyCountsOldAttemptAndStartsAtomically() {
        val store = FakeStore(snapshot = snapshot(attemptStartedAtMs = 100, attemptSessionId = session("old")))

        assertEquals(NativeWebViewStartupDecision.Started(true), guard(store, "new").beginAttempt(101))
        assertEquals(snapshot(failures = 1, attemptStartedAtMs = 101, attemptSessionId = session("new")), store.snapshot)
        assertEquals(1, store.writes.size)
    }

    @Test
    fun currentSessionTimeoutReplacesAttemptInOneDurableWrite() {
        val store = FakeStore(snapshot = snapshot(attemptStartedAtMs = 100, attemptSessionId = session("a")))

        assertEquals(NativeWebViewStartupDecision.Started(true), guard(store, "a").beginAttempt(30_100))
        assertEquals(snapshot(failures = 1, attemptStartedAtMs = 30_100, attemptSessionId = session("a")), store.snapshot)
        assertEquals(1, store.writes.size)
    }

    @Test
    fun sameSessionClockRollbackStartsCleanAttemptWithoutFailure() {
        val store = FakeStore(snapshot = snapshot(failures = 1, attemptStartedAtMs = 1_000, attemptSessionId = session("a")))

        assertEquals(NativeWebViewStartupDecision.Started(false), guard(store, "a").beginAttempt(999))
        assertEquals(snapshot(failures = 1, attemptStartedAtMs = 999, attemptSessionId = session("a")), store.snapshot)
    }

    @Test
    fun fallbackClosesFurtherStartsForSameAndNewGuardWithoutWriting() {
        val store = FakeStore(snapshot = snapshot(failures = 1, attemptStartedAtMs = 0, attemptSessionId = session("a")))
        val firstGuard = guard(store, "a")

        assertEquals(NativeWebViewStartupDecision.FallbackTriggered, firstGuard.recordRenderProcessGone())
        val writeCount = store.writes.size
        assertEquals(NativeWebViewStartupDecision.FallbackActive, firstGuard.beginAttempt(1))
        assertEquals(NativeWebViewStartupDecision.FallbackActive, guard(store, "new").beginAttempt(1))
        assertEquals(writeCount, store.writes.size)
    }

    @Test
    fun pageFinishedRenderGoneAndTimeoutIgnoreOldSessionEvents() {
        val old = snapshot(failures = 1, attemptStartedAtMs = 100, attemptSessionId = session("old"))
        val pageStore = FakeStore(snapshot = old)
        val renderStore = FakeStore(snapshot = old)
        val timeoutStore = FakeStore(snapshot = old)

        assertEquals(NativeWebViewStartupDecision.NoActiveAttempt, guard(pageStore, "new").recordPageFinished())
        assertEquals(NativeWebViewStartupDecision.NoActiveAttempt, guard(renderStore, "new").recordRenderProcessGone())
        assertEquals(NativeWebViewStartupDecision.NoActiveAttempt, guard(timeoutStore, "new").recordStartupTimeout(30_100))
        assertTrue(pageStore.writes.isEmpty() && renderStore.writes.isEmpty() && timeoutStore.writes.isEmpty())
    }

    @Test
    fun timeoutReportsRemainingThenRecordsFailure() {
        val store = FakeStore(snapshot = snapshot(attemptStartedAtMs = 100, attemptSessionId = session("a")))
        val guard = guard(store, "a")

        assertEquals(NativeWebViewStartupDecision.NotTimedOut(1), guard.recordStartupTimeout(30_099))
        assertEquals(NativeWebViewStartupDecision.FailureRecorded, guard.recordStartupTimeout(30_100))
        assertEquals(snapshot(failures = 1), store.snapshot)
    }

    @Test
    fun cancelClearsAnyMarkerWithoutRecordingFailure() {
        val store = FakeStore(snapshot = snapshot(failures = 1, attemptStartedAtMs = 10, attemptSessionId = session("old")))

        assertEquals(NativeWebViewStartupDecision.Cancelled, guard(store, "new").cancelAttempt())
        assertEquals(snapshot(failures = 1), store.snapshot)
    }

    @Test
    fun failedWriteReturnsPersistenceFailedAndDoesNotClaimStart() {
        val original = snapshot()
        val store = FakeStore(snapshot = original, writeResult = NativeWebViewStartupWriteResult.Failed)

        val decision = guard(store, "a").beginAttempt(0)

        assertEquals(NativeWebViewStartupDecision.PersistenceFailed, decision)
        assertFalse(decision.shouldStart || decision.shouldFallback)
        assertEquals(original, store.snapshot)
    }

    @Test
    fun indeterminateWriteFailsClosedEvenWhenMemoryMayHaveChanged() {
        val store = FakeStore(
            snapshot = snapshot(),
            writeResult = NativeWebViewStartupWriteResult.Indeterminate,
            applyIndeterminateInMemory = true,
        )

        val decision = guard(store, "a").beginAttempt(0)

        assertEquals(NativeWebViewStartupDecision.PersistenceIndeterminate, decision)
        assertFalse(decision.shouldStart || decision.shouldFallback)
        assertEquals(snapshot(attemptStartedAtMs = 0, attemptSessionId = session("a")), store.snapshot)
    }

    @Test
    fun unavailableAndThrowingReadsFailWithoutThrowing() {
        val unavailable = FakeStore(readResult = NativeWebViewStartupReadResult.Unavailable)
        val throwing = FakeStore(throwOnRead = true)

        assertEquals(NativeWebViewStartupDecision.PersistenceFailed, guard(unavailable, "a").beginAttempt(0))
        assertEquals(NativeWebViewStartupDecision.PersistenceFailed, guard(throwing, "a").beginAttempt(0))
    }

    @Test
    fun throwingWriteIsIndeterminateAndDoesNotThrow() {
        val store = FakeStore(throwOnWrite = true)

        assertEquals(NativeWebViewStartupDecision.PersistenceIndeterminate, guard(store, "a").beginAttempt(0))
    }

    @Test
    fun negativeFailuresAreNormalizedAndLargeCountFallsBack() {
        val negativeStore = FakeStore(snapshot = snapshot(failures = -20, attemptStartedAtMs = 0, attemptSessionId = session("a")))
        val largeStore = FakeStore(snapshot = snapshot(failures = Int.MAX_VALUE, attemptStartedAtMs = 0, attemptSessionId = session("a")))

        assertEquals(NativeWebViewStartupDecision.FailureRecorded, guard(negativeStore, "a").recordRenderProcessGone())
        assertEquals(1, negativeStore.snapshot.consecutiveFailures)
        assertEquals(NativeWebViewStartupDecision.FallbackTriggered, guard(largeStore, "a").recordRenderProcessGone())
        assertEquals(0, largeStore.snapshot.consecutiveFailures)
    }

    @Test
    fun rejectsInvalidNowAndEmptyProcessSession() {
        assertIllegalArgument { NativeWebViewProcessSessionId("") }
        assertIllegalArgument { guard(FakeStore(), "a").beginAttempt(-1) }
        assertIllegalArgument { guard(FakeStore(), "a").recordStartupTimeout(-1) }
    }

    private fun guard(store: NativeWebViewStartupStore, sessionId: String): NativeWebViewStartupGuard =
        NativeWebViewStartupGuard(store, session(sessionId))

    private fun session(value: String) = NativeWebViewProcessSessionId(value)

    private fun snapshot(
        failures: Int = 0,
        attemptStartedAtMs: Long? = null,
        attemptSessionId: NativeWebViewProcessSessionId? = null,
        renderingMode: String? = null,
    ) = NativeWebViewStartupSnapshot(failures, attemptStartedAtMs, attemptSessionId, renderingMode)

    private fun assertIllegalArgument(block: () -> Unit) {
        try {
            block()
        } catch (_: IllegalArgumentException) {
            return
        }
        throw AssertionError("Expected IllegalArgumentException")
    }

    private class FakeStore(
        var snapshot: NativeWebViewStartupSnapshot = NativeWebViewStartupSnapshot(0, null, null, null),
        private var readResult: NativeWebViewStartupReadResult? = null,
        private val writeResult: NativeWebViewStartupWriteResult = NativeWebViewStartupWriteResult.Durable,
        private val applyIndeterminateInMemory: Boolean = false,
        private val throwOnRead: Boolean = false,
        private val throwOnWrite: Boolean = false,
    ) : NativeWebViewStartupStore {
        val writes = mutableListOf<NativeWebViewStartupSnapshot>()

        override fun read(): NativeWebViewStartupReadResult {
            if (throwOnRead) error("read failure")
            return readResult ?: NativeWebViewStartupReadResult.Success(snapshot)
        }

        override fun write(nextSnapshot: NativeWebViewStartupSnapshot): NativeWebViewStartupWriteResult {
            if (throwOnWrite) error("write failure")
            writes += nextSnapshot
            if (writeResult == NativeWebViewStartupWriteResult.Durable || applyIndeterminateInMemory) {
                snapshot = nextSnapshot
            }
            return writeResult
        }
    }
}
