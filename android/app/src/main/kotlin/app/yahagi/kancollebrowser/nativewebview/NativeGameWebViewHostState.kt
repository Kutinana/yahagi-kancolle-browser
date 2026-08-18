package app.yahagi.kancollebrowser.nativewebview

enum class NativeGameWebViewHostPhase {
    ABSENT,
    CREATING,
    READY,
    DESTROYING,
}

class NativeGameWebViewHostState(
    initialLastGenerationId: Long = -1L,
) {
    init {
        require(initialLastGenerationId >= -1L)
    }

    var phase: NativeGameWebViewHostPhase = NativeGameWebViewHostPhase.ABSENT
        private set

    var generationId: Long? = null
        private set

    private var lastGenerationId = initialLastGenerationId

    fun beginCreate(): Long {
        check(phase == NativeGameWebViewHostPhase.ABSENT) {
            "A native game WebView already exists or is transitioning"
        }
        check(lastGenerationId != Long.MAX_VALUE) {
            "Native game WebView generation id is exhausted"
        }

        val newGenerationId = lastGenerationId + 1L
        lastGenerationId = newGenerationId
        generationId = newGenerationId
        phase = NativeGameWebViewHostPhase.CREATING
        return newGenerationId
    }

    fun markReady(generationId: Long): Boolean {
        if (!isCurrentGeneration(generationId) || phase != NativeGameWebViewHostPhase.CREATING) {
            return false
        }

        phase = NativeGameWebViewHostPhase.READY
        return true
    }

    fun accepts(generationId: Long): Boolean =
        isCurrentGeneration(generationId) &&
            (phase == NativeGameWebViewHostPhase.CREATING || phase == NativeGameWebViewHostPhase.READY)

    fun beginDestroy(generationId: Long): Boolean {
        if (!accepts(generationId)) {
            return false
        }

        phase = NativeGameWebViewHostPhase.DESTROYING
        return true
    }

    fun completeDestroy(generationId: Long): Boolean {
        if (!isCurrentGeneration(generationId) || phase != NativeGameWebViewHostPhase.DESTROYING) {
            return false
        }

        this.generationId = null
        phase = NativeGameWebViewHostPhase.ABSENT
        return true
    }

    private fun isCurrentGeneration(candidate: Long): Boolean =
        candidate >= 0L && generationId == candidate
}
