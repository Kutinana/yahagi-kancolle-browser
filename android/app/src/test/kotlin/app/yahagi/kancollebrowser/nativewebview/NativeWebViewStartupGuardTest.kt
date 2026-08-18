package app.yahagi.kancollebrowser.nativewebview

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class NativeWebViewStartupGuardTest {
    @Test
    fun firstFailureIsRecordedWithOneAtomicWrite() {
        val store = FakeStore()
        val guard = NativeWebViewStartupGuard(store, "session-a")

        assertEquals(NativeWebViewStartupDecision.Started(false), guard.beginAttempt(100))
        assertEquals(NativeWebViewStartupDecision.FailureRecorded, guard.recordRenderProcessGone())
        assertEquals(NativeWebViewStartupSnapshot(1, null, null, null), store.snapshot)
        assertEquals(2, store.writes.size)
    }

    @Test
    fun secondFailureTriggersFallbackOnceInOneAtomicWrite() {
        val store = FakeStore(NativeWebViewStartupSnapshot(1, 0, "session-a", null))
        val guard = NativeWebViewStartupGuard(store, "session-a")

        val decision = guard.recordRenderProcessGone()

        assertEquals(NativeWebViewStartupDecision.FallbackTriggered, decision)
        assertTrue(decision.shouldFallback)
        assertEquals(
            NativeWebViewStartupSnapshot(0, null, null, NativeWebViewStartupGuard.FALLBACK_RENDERING_MODE),
            store.snapshot,
        )
        assertEquals(1, store.writes.size)
        assertEquals(NativeWebViewStartupDecision.NoActiveAttempt, guard.recordRenderProcessGone())
    }

    @Test
    fun currentSessionInProgressReportsRemainingTimeWithoutWriting() {
        val store = FakeStore(NativeWebViewStartupSnapshot(0, 100, "session-a", null))
        val guard = NativeWebViewStartupGuard(store, "session-a")

        val decision = guard.beginAttempt(30_099)

        assertEquals(NativeWebViewStartupDecision.AlreadyInProgress(1), decision)
        assertFalse(decision.shouldStart)
        assertTrue(store.writes.isEmpty())
    }

    @Test
    fun currentSessionTimeoutRecordsFailureAndStartsReplacementAtomically() {
        val store = FakeStore(NativeWebViewStartupSnapshot(0, 100, "session-a", null))
        val guard = NativeWebViewStartupGuard(store, "session-a")

        assertEquals(NativeWebViewStartupDecision.Started(true), guard.beginAttempt(30_100))
        assertEquals(NativeWebViewStartupSnapshot(1, 30_100, "session-a", null), store.snapshot)
        assertEquals(1, store.writes.size)
    }

    @Test
    fun fastRestartInAnotherSessionRecordsFailureEvenBeforeTimeout() {
        val store = FakeStore(NativeWebViewStartupSnapshot(0, 100, "session-old", null))
        val guard = NativeWebViewStartupGuard(store, "session-new")

        assertEquals(NativeWebViewStartupDecision.Started(true), guard.beginAttempt(101))
        assertEquals(NativeWebViewStartupSnapshot(1, 101, "session-new", null), store.snapshot)
        assertEquals(1, store.writes.size)
    }

    @Test
    fun crossBootSmallerNowStillTreatsOtherSessionAsStale() {
        val store = FakeStore(NativeWebViewStartupSnapshot(0, 99_000, "session-old", null))

        assertEquals(NativeWebViewStartupDecision.Started(true), NativeWebViewStartupGuard(store, "session-new").beginAttempt(5))
        assertEquals(NativeWebViewStartupSnapshot(1, 5, "session-new", null), store.snapshot)
    }

    @Test
    fun clockRollbackInSameSessionStartsCleanAttemptWithoutFailure() {
        val store = FakeStore(NativeWebViewStartupSnapshot(1, 1_000, "session-a", null))

        assertEquals(NativeWebViewStartupDecision.Started(false), NativeWebViewStartupGuard(store, "session-a").beginAttempt(999))
        assertEquals(NativeWebViewStartupSnapshot(1, 999, "session-a", null), store.snapshot)
    }

    @Test
    fun corruptAttemptTimeOrMissingSessionIsHandledAsStale() {
        val corruptTimeStore = FakeStore(NativeWebViewStartupSnapshot(0, -1, "session-old", null))
        val missingSessionStore = FakeStore(NativeWebViewStartupSnapshot(0, 1, null, null))

        assertEquals(NativeWebViewStartupDecision.Started(true), NativeWebViewStartupGuard(corruptTimeStore, "new").beginAttempt(2))
        assertEquals(NativeWebViewStartupSnapshot(1, 2, "new", null), corruptTimeStore.snapshot)
        assertEquals(NativeWebViewStartupDecision.Started(true), NativeWebViewStartupGuard(missingSessionStore, "new").beginAttempt(2))
        assertEquals(NativeWebViewStartupSnapshot(1, 2, "new", null), missingSessionStore.snapshot)
    }

    @Test
    fun pageFinishedClearsFailuresOnlyForCurrentSession() {
        val currentStore = FakeStore(NativeWebViewStartupSnapshot(1, 10, "session-a", null))
        val oldStore = FakeStore(NativeWebViewStartupSnapshot(1, 10, "session-old", null))

        assertEquals(NativeWebViewStartupDecision.Succeeded, NativeWebViewStartupGuard(currentStore, "session-a").recordPageFinished())
        assertEquals(NativeWebViewStartupSnapshot(0, null, null, null), currentStore.snapshot)
        assertEquals(NativeWebViewStartupDecision.NoActiveAttempt, NativeWebViewStartupGuard(oldStore, "session-a").recordPageFinished())
        assertEquals(NativeWebViewStartupSnapshot(1, 10, "session-old", null), oldStore.snapshot)
    }

    @Test
    fun timeoutOnlyProcessesCurrentSessionAndReportsRemainingTime() {
        val currentStore = FakeStore(NativeWebViewStartupSnapshot(0, 100, "session-a", null))
        val oldStore = FakeStore(NativeWebViewStartupSnapshot(0, 100, "session-old", null))
        val currentGuard = NativeWebViewStartupGuard(currentStore, "session-a")

        assertEquals(NativeWebViewStartupDecision.NotTimedOut(1), currentGuard.recordStartupTimeout(30_099))
        assertEquals(NativeWebViewStartupDecision.FailureRecorded, currentGuard.recordStartupTimeout(30_100))
        assertEquals(NativeWebViewStartupDecision.NoActiveAttempt, NativeWebViewStartupGuard(oldStore, "session-a").recordStartupTimeout(30_100))
        assertTrue(oldStore.writes.isEmpty())
    }

    @Test
    fun cancelClearsAnyActiveMarkerWithoutAddingFailure() {
        val store = FakeStore(NativeWebViewStartupSnapshot(1, 10, "session-old", null))

        assertEquals(NativeWebViewStartupDecision.Cancelled, NativeWebViewStartupGuard(store, "session-a").cancelAttempt())
        assertEquals(NativeWebViewStartupSnapshot(1, null, null, null), store.snapshot)
    }

    @Test
    fun readAndWriteFailuresDoNotPretendSuccessOrPartiallyUpdate() {
        val readFailureStore = FakeStore(initialSnapshot = null)
        val writeFailureSnapshot = NativeWebViewStartupSnapshot(0, null, null, null)
        val writeFailureStore = FakeStore(writeFailureSnapshot, failWrites = true)

        assertEquals(NativeWebViewStartupDecision.PersistenceFailed, NativeWebViewStartupGuard(readFailureStore, "a").beginAttempt(0))
        assertEquals(NativeWebViewStartupDecision.PersistenceFailed, NativeWebViewStartupGuard(writeFailureStore, "a").beginAttempt(0))
        assertEquals(writeFailureSnapshot, writeFailureStore.snapshot)
        assertEquals(1, writeFailureStore.writes.size)
    }

    @Test
    fun negativeFailuresAreNormalizedAndCannotOverflow() {
        val negativeStore = FakeStore(NativeWebViewStartupSnapshot(-20, 0, "a", null))
        val largeStore = FakeStore(NativeWebViewStartupSnapshot(Int.MAX_VALUE, 0, "a", null))

        assertEquals(NativeWebViewStartupDecision.FailureRecorded, NativeWebViewStartupGuard(negativeStore, "a").recordRenderProcessGone())
        assertEquals(1, negativeStore.snapshot!!.consecutiveFailures)
        assertEquals(NativeWebViewStartupDecision.FallbackTriggered, NativeWebViewStartupGuard(largeStore, "a").recordRenderProcessGone())
        assertEquals(0, largeStore.snapshot!!.consecutiveFailures)
    }

    @Test
    fun rejectsInvalidNowAndEmptySession() {
        assertIllegalArgument { NativeWebViewStartupGuard(FakeStore(), "") }
        assertIllegalArgument { NativeWebViewStartupGuard(FakeStore(), "a").beginAttempt(-1) }
        assertIllegalArgument { NativeWebViewStartupGuard(FakeStore(), "a").recordStartupTimeout(-1) }
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
        initialSnapshot: NativeWebViewStartupSnapshot? = NativeWebViewStartupSnapshot(0, null, null, null),
        private val failWrites: Boolean = false,
    ) : NativeWebViewStartupStore {
        var snapshot: NativeWebViewStartupSnapshot? = initialSnapshot
        val writes = mutableListOf<NativeWebViewStartupSnapshot>()

        override fun read(): NativeWebViewStartupSnapshot? = snapshot

        override fun write(nextSnapshot: NativeWebViewStartupSnapshot): Boolean {
            writes += nextSnapshot
            if (failWrites) {
                return false
            }
            snapshot = nextSnapshot
            return true
        }
    }
}
