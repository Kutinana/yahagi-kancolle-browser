package app.yahagi.kancollebrowser.browser

/** Once touch slop is exceeded, releasing can only finish a drag, never click. */
internal class FullscreenExitGesture(private val touchSlop: Float) {
    private var downX = 0f
    private var downY = 0f
    private var dragged = false
    private var active = false

    fun begin(x: Float, y: Float) {
        downX = x
        downY = y
        dragged = false
        active = true
    }

    fun move(x: Float, y: Float): Boolean {
        if (!active) return false
        val dx = x - downX
        val dy = y - downY
        if (dx * dx + dy * dy > touchSlop * touchSlop) dragged = true
        return dragged
    }

    fun finish(cancelled: Boolean): Boolean {
        val click = active && !dragged && !cancelled
        active = false
        return click
    }
}
