package app.yahagi.kancollebrowser

internal object UiRefreshRatePolicy {
    fun highestSupported(refreshRates: Iterable<Float>): Float =
        refreshRates
            .filter { it.isFinite() && it > 0f }
            .maxOrNull()
            ?: 0f
}
