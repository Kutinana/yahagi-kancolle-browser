package app.yahagi.kancollebrowser.capture

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class ScreenshotCapturePolicyTest {
    @Test
    fun memoryPreviewSkipsStoragePermissionAndGalleryPersistence() {
        assertEquals(false, ScreenshotOutput.MEMORY_PREVIEW.requiresStoragePermission)
        assertEquals(false, ScreenshotOutput.MEMORY_PREVIEW.persistsToGallery)
        assertEquals(true, ScreenshotOutput.GALLERY.requiresStoragePermission)
        assertEquals(true, ScreenshotOutput.GALLERY.persistsToGallery)
    }

    @Test
    fun rejectsHiddenDetachedAndZeroSizedCandidates() {
        val candidates = listOf(
            candidate(index = 0, visible = false),
            candidate(index = 1, attached = false),
            candidate(index = 2, width = 0),
            candidate(index = 3, height = 0),
        )

        assertNull(ScreenshotCapturePolicy.select(candidates))
    }

    @Test
    fun selectsTheLargestVisibleAttachedCandidate() {
        val selected = ScreenshotCapturePolicy.select(
            listOf(
                candidate(index = 0, width = 400, height = 300),
                candidate(index = 1, width = 1200, height = 720),
                candidate(index = 2, width = 800, height = 600),
            ),
        )

        assertEquals(1, selected?.index)
    }

    @Test
    fun calculatesThePixelCopySourceRectangleInWindowCoordinates() {
        val selected = candidate(
            index = 7,
            width = 1200,
            height = 720,
            windowX = 16,
            windowY = 48,
        )

        assertEquals(
            CaptureRect(left = 16, top = 48, right = 1216, bottom = 768),
            ScreenshotCapturePolicy.captureRect(selected),
        )
    }

    @Test
    fun fallsBackFromRectPixelCopyToWindowCropAndWebViewDraw() {
        assertEquals(
            listOf(
                ScreenshotCaptureAttempt.PIXEL_COPY_RECT,
                ScreenshotCaptureAttempt.PIXEL_COPY_WINDOW,
                ScreenshotCaptureAttempt.WEB_VIEW_DRAW,
            ),
            ScreenshotCapturePolicy.captureAttempts(supportsPixelCopy = true),
        )
        assertEquals(
            listOf(ScreenshotCaptureAttempt.WEB_VIEW_DRAW),
            ScreenshotCapturePolicy.captureAttempts(supportsPixelCopy = false),
        )
    }

    private fun candidate(
        index: Int,
        visible: Boolean = true,
        attached: Boolean = true,
        width: Int = 100,
        height: Int = 100,
        windowX: Int = 0,
        windowY: Int = 0,
    ) = ScreenshotViewCandidate(
        index = index,
        visible = visible,
        attached = attached,
        width = width,
        height = height,
        windowX = windowX,
        windowY = windowY,
    )
}
