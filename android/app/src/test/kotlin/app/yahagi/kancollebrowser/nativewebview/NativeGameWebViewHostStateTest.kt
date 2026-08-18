package app.yahagi.kancollebrowser.nativewebview

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class NativeGameWebViewHostStateTest {
    @Test
    fun createsReadyAndDestroysOneGenerationExactlyOnce() {
        val state = NativeGameWebViewHostState()

        val generation = state.beginCreate()

        assertEquals(0L, generation)
        assertEquals(NativeGameWebViewHostPhase.CREATING, state.phase)
        assertTrue(state.markReady(generation))
        assertTrue(state.accepts(generation))
        assertTrue(state.beginDestroy(generation))
        assertEquals(NativeGameWebViewHostPhase.DESTROYING, state.phase)
        assertFalse(state.beginDestroy(generation))
        assertFalse(state.accepts(generation))
        assertTrue(state.completeDestroy(generation))
        assertEquals(NativeGameWebViewHostPhase.ABSENT, state.phase)
        assertFalse(state.completeDestroy(generation))
    }

    @Test
    fun rejectsOldGenerationOperationsAfterReplacement() {
        val state = NativeGameWebViewHostState()
        val firstGeneration = state.beginCreate()
        state.markReady(firstGeneration)
        state.beginDestroy(firstGeneration)
        state.completeDestroy(firstGeneration)
        val currentGeneration = state.beginCreate()

        assertEquals(1L, currentGeneration)
        assertFalse(state.markReady(firstGeneration))
        assertFalse(state.accepts(firstGeneration))
        assertFalse(state.beginDestroy(firstGeneration))
        assertFalse(state.completeDestroy(firstGeneration))
        assertTrue(state.accepts(currentGeneration))
    }

    @Test
    fun onlyAbsentStateCanBeginCreation() {
        val state = NativeGameWebViewHostState()
        state.beginCreate()

        assertIllegalState { state.beginCreate() }
    }

    @Test
    fun rejectsInvalidPhaseTransitionsAndUnknownGenerations() {
        val state = NativeGameWebViewHostState()
        val generation = state.beginCreate()

        assertFalse(state.markReady(generation + 1))
        assertFalse(state.beginDestroy(generation + 1))
        assertFalse(state.completeDestroy(generation))
        assertTrue(state.markReady(generation))
        assertFalse(state.completeDestroy(generation))
    }

    @Test
    fun refusesToWrapGenerationAfterLongMaxValue() {
        val state = NativeGameWebViewHostState(initialLastGenerationId = Long.MAX_VALUE)

        assertIllegalState { state.beginCreate() }
    }

    private fun assertIllegalState(block: () -> Unit) {
        try {
            block()
        } catch (_: IllegalStateException) {
            return
        }
        throw AssertionError("Expected IllegalStateException")
    }
}
