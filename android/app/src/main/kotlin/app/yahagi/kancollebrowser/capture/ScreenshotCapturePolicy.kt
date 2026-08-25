package app.yahagi.kancollebrowser.capture

data class ScreenshotViewCandidate(
    val index: Int,
    val visible: Boolean,
    val attached: Boolean,
    val width: Int,
    val height: Int,
    val windowX: Int,
    val windowY: Int,
)

data class CaptureRect(
    val left: Int,
    val top: Int,
    val right: Int,
    val bottom: Int,
)

enum class ScreenshotCaptureAttempt {
    PIXEL_COPY_RECT,
    PIXEL_COPY_WINDOW,
    WEB_VIEW_DRAW,
}

enum class ScreenshotOutput(
    val requiresStoragePermission: Boolean,
    val persistsToGallery: Boolean,
) {
    GALLERY(requiresStoragePermission = true, persistsToGallery = true),
    MEMORY_PREVIEW(requiresStoragePermission = false, persistsToGallery = false),
}

object ScreenshotCapturePolicy {
    fun captureAttempts(supportsPixelCopy: Boolean): List<ScreenshotCaptureAttempt> =
        if (supportsPixelCopy) {
            listOf(
                ScreenshotCaptureAttempt.PIXEL_COPY_RECT,
                ScreenshotCaptureAttempt.PIXEL_COPY_WINDOW,
                ScreenshotCaptureAttempt.WEB_VIEW_DRAW,
            )
        } else {
            listOf(ScreenshotCaptureAttempt.WEB_VIEW_DRAW)
        }

    fun select(candidates: List<ScreenshotViewCandidate>): ScreenshotViewCandidate? =
        candidates
            .asSequence()
            .filter { candidate ->
                candidate.visible &&
                    candidate.attached &&
                    candidate.width > 0 &&
                    candidate.height > 0
            }
            .maxByOrNull { candidate ->
                candidate.width.toLong() * candidate.height.toLong()
            }

    fun captureRect(candidate: ScreenshotViewCandidate): CaptureRect = CaptureRect(
        left = candidate.windowX,
        top = candidate.windowY,
        right = candidate.windowX + candidate.width,
        bottom = candidate.windowY + candidate.height,
    )
}
