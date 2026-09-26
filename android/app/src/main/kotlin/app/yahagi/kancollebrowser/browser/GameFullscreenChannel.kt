package app.yahagi.kancollebrowser.browser

import android.annotation.SuppressLint
import android.app.Activity
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.ColorFilter
import android.graphics.Paint
import android.graphics.PixelFormat
import android.graphics.drawable.Drawable
import android.graphics.drawable.GradientDrawable
import android.text.TextUtils
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.ViewConfiguration
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.TextView
import android.widget.Toast
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** An app-owned control above both Activity WebViews and Flutter PlatformViews.
 * Only its 34 x 34 logical-pixel circle takes touches; the game stays usable.
 */
internal class GameFullscreenChannel(
    private val activity: Activity,
    engine: FlutterEngine,
) : MethodChannel.MethodCallHandler {
    private val channel = MethodChannel(engine.dartExecutor.binaryMessenger, "app.yahagi.kancollebrowser/game_fullscreen")
    private var button: ImageView? = null
    private var questNotice: TextView? = null
    private var pendingQuestMessage = ""
    private var scale = 1f
    private var minX = 0f
    private var maxX = 0f
    private var minY = 0f
    private var maxY = 0f
    private var hintShown = false
    private var hintToast: Toast? = null
    private val gesture = FullscreenExitGesture(ViewConfiguration.get(activity).scaledTouchSlop.toFloat())

    init { channel.setMethodCallHandler(this) }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method == "questNotice") {
            try {
                pendingQuestMessage = call.argument<String>("message").orEmpty()
                showQuestNotice(pendingQuestMessage)
                result.success(null)
            } catch (error: Exception) {
                result.error("quest_notice_unavailable", error.message, null)
            }
            return
        }
        if (call.method != "update") {
            result.notImplemented()
            return
        }
        if (call.argument<Boolean>("active") != true) {
            removeButton()
            result.success(null)
            return
        }
        try {
            update(call)
            result.success(null)
        } catch (error: Exception) {
            removeButton()
            result.error("fullscreen_control_unavailable", error.message, null)
        }
    }

    private fun update(call: MethodCall) {
        fun number(key: String): Float = requireNotNull(call.argument<Number>(key)).toFloat().also {
            require(it.isFinite())
        }
        scale = number("scale").also { require(it > 0) }
        minX = number("minX") * scale
        maxX = number("maxX") * scale
        minY = number("minY") * scale
        maxY = number("maxY") * scale
        require(maxX >= minX && maxY >= minY)
        val root = requireNotNull(activity.findViewById<FrameLayout>(android.R.id.content))
        val view = button ?: createButton().also {
            button = it
            root.addView(it)
        }
        view.contentDescription = call.argument<String>("description") ?: call.argument<String>("label")
        view.layoutParams = FrameLayout.LayoutParams(
            (number("width") * scale).toInt().coerceAtLeast(1),
            (number("height") * scale).toInt().coerceAtLeast(1),
            Gravity.TOP or Gravity.LEFT,
        ).apply {
            leftMargin = (number("x") * scale).coerceIn(minX, maxX).toInt()
            topMargin = (number("y") * scale).coerceIn(minY, maxY).toInt()
        }
        view.translationX = 0f
        view.translationY = 0f
        view.bringToFront()
        showQuestNotice(pendingQuestMessage)
        val hint = call.argument<String>("hint").orEmpty()
        if (hint.isNotEmpty() && !hintShown) {
            hintShown = true
            hintToast = Toast.makeText(activity, hint, Toast.LENGTH_LONG).also { it.show() }
        }
    }

    @SuppressLint("ClickableViewAccessibility")
    private fun createButton(): ImageView {
        val density = activity.resources.displayMetrics.density
        val paddingPx = (7 * density).toInt()
        val view = ImageView(activity).apply {
            setImageDrawable(ExitIcon())
            scaleType = ImageView.ScaleType.FIT_CENTER
            setPadding(paddingPx, paddingPx, paddingPx, paddingPx)
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(0xcc122431.toInt())
                setStroke((density).toInt().coerceAtLeast(1), 0x668197a5)
            }
            // Elevation keeps the control above WebViews created after it.
            elevation = 10000 * density
            isClickable = true
            isFocusable = true
            importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_YES
            setOnClickListener { channel.invokeMethod("exit", null) }
        }
        var rawDownX = 0f
        var rawDownY = 0f
        var startX = 0f
        var startY = 0f
        var dragging = false
        view.setOnTouchListener { _, event ->
            when (event.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    rawDownX = event.rawX
                    rawDownY = event.rawY
                    startX = view.x
                    startY = view.y
                    dragging = false
                    gesture.begin(rawDownX, rawDownY)
                    view.isPressed = true
                }
                MotionEvent.ACTION_MOVE -> {
                    dragging = gesture.move(event.rawX, event.rawY)
                    if (dragging) {
                        view.isPressed = false
                        view.x = (startX + event.rawX - rawDownX).coerceIn(minX, maxX)
                        view.y = (startY + event.rawY - rawDownY).coerceIn(minY, maxY)
                    }
                }
                MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                    view.isPressed = false
                    if (gesture.finish(cancelled = event.actionMasked == MotionEvent.ACTION_CANCEL)) {
                        view.performClick()
                    } else if (dragging) {
                        channel.invokeMethod("moved", mapOf("x" to view.x / scale, "y" to view.y / scale))
                    }
                    dragging = false
                }
            }
            true
        }
        return view
    }

    private fun removeButton() {
        pendingQuestMessage = ""
        showQuestNotice("")
        button?.let { (it.parent as? FrameLayout)?.removeView(it) }
        button = null
        gesture.finish(cancelled = true)
        hintToast?.cancel()
        hintToast = null
    }

    private fun showQuestNotice(message: String) {
        if (message.isEmpty() || button == null) {
            questNotice?.let { (it.parent as? FrameLayout)?.removeView(it) }
            questNotice = null
            return
        }
        val root = requireNotNull(activity.findViewById<FrameLayout>(android.R.id.content))
        val density = activity.resources.displayMetrics.density
        val view = questNotice ?: TextView(activity).apply {
            setTextColor(Color.WHITE)
            textSize = 14f
            gravity = Gravity.CENTER
            maxLines = 2
            ellipsize = TextUtils.TruncateAt.END
            maxWidth = (activity.resources.displayMetrics.widthPixels - 80 * density).toInt().coerceAtLeast((160 * density).toInt())
            isClickable = false
            isFocusable = false
            importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_YES
            setPadding((12 * density).toInt(), (7 * density).toInt(), (12 * density).toInt(), (7 * density).toInt())
            background = GradientDrawable().apply {
                cornerRadius = 8 * density
                setColor(0xee203743.toInt())
                setStroke(density.toInt().coerceAtLeast(1), 0xffd4a85f.toInt())
            }
            elevation = 9999 * density
            questNotice = this
            root.addView(this)
        }
        view.text = message
        view.layoutParams = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.WRAP_CONTENT,
            FrameLayout.LayoutParams.WRAP_CONTENT,
            Gravity.TOP or Gravity.CENTER_HORIZONTAL,
        ).apply { topMargin = (8 * density).toInt() }
        view.bringToFront()
        button?.bringToFront()
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        removeButton()
    }

    private class ExitIcon : Drawable() {
        private val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.WHITE
            style = Paint.Style.STROKE
            strokeWidth = 2f
        }
        override fun getIntrinsicWidth(): Int = 24
        override fun getIntrinsicHeight(): Int = 24
        override fun draw(canvas: Canvas) {
            val checkpoint = canvas.save()
            canvas.translate(bounds.left.toFloat(), bounds.top.toFloat())
            canvas.scale(bounds.width() / 24f, bounds.height() / 24f)
            canvas.drawLines(floatArrayOf(
                4f, 9f, 9f, 9f, 9f, 9f, 9f, 4f,
                15f, 4f, 15f, 9f, 15f, 9f, 20f, 9f,
                4f, 15f, 9f, 15f, 9f, 15f, 9f, 20f,
                15f, 20f, 15f, 15f, 15f, 15f, 20f, 15f,
            ), paint)
            canvas.restoreToCount(checkpoint)
        }
        override fun setAlpha(alpha: Int) { paint.alpha = alpha }
        override fun setColorFilter(colorFilter: ColorFilter?) { paint.colorFilter = colorFilter }
        @Deprecated("Deprecated in Java")
        override fun getOpacity(): Int = PixelFormat.TRANSLUCENT
    }
}
