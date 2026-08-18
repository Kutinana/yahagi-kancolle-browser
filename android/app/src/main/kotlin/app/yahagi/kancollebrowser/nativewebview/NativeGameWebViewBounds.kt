package app.yahagi.kancollebrowser.nativewebview

import kotlin.math.roundToInt

data class NativeGameWebViewBounds(
    val left: Double,
    val top: Double,
    val width: Double,
    val height: Double,
    val devicePixelRatio: Double,
) {
    init {
        require(left.isFinite())
        require(top.isFinite())
        require(width.isFinite() && width > 0.0)
        require(height.isFinite() && height > 0.0)
        require(devicePixelRatio.isFinite() && devicePixelRatio > 0.0)
    }

    fun toPhysicalBounds(rootWidth: Int, rootHeight: Int): PhysicalBounds? {
        if (rootWidth <= 0 || rootHeight <= 0) {
            return null
        }

        val logicalRight = left + width
        val logicalBottom = top + height
        val physicalLeft = roundedCoordinate(left * devicePixelRatio) ?: return null
        val physicalTop = roundedCoordinate(top * devicePixelRatio) ?: return null
        val physicalRight = roundedCoordinate(logicalRight * devicePixelRatio) ?: return null
        val physicalBottom = roundedCoordinate(logicalBottom * devicePixelRatio) ?: return null

        val clippedLeft = physicalLeft.coerceIn(0, rootWidth)
        val clippedTop = physicalTop.coerceIn(0, rootHeight)
        val clippedRight = physicalRight.coerceIn(0, rootWidth)
        val clippedBottom = physicalBottom.coerceIn(0, rootHeight)
        if (clippedRight <= clippedLeft || clippedBottom <= clippedTop) {
            return null
        }

        return PhysicalBounds(clippedLeft, clippedTop, clippedRight, clippedBottom)
    }

    private fun roundedCoordinate(value: Double): Int? {
        if (!value.isFinite() || value < Int.MIN_VALUE.toDouble() || value > Int.MAX_VALUE.toDouble()) {
            return null
        }
        return value.roundToInt()
    }
}

class PhysicalBounds internal constructor(
    val left: Int,
    val top: Int,
    val right: Int,
    val bottom: Int,
) {
    init {
        require(left >= 0)
        require(top >= 0)
        require(right > left)
        require(bottom > top)
        require(right.toLong() - left.toLong() <= Int.MAX_VALUE.toLong())
        require(bottom.toLong() - top.toLong() <= Int.MAX_VALUE.toLong())
    }

    val width: Int
        get() = (right.toLong() - left.toLong()).toInt()

    val height: Int
        get() = (bottom.toLong() - top.toLong()).toInt()

    override fun equals(other: Any?): Boolean =
        other is PhysicalBounds &&
            left == other.left &&
            top == other.top &&
            right == other.right &&
            bottom == other.bottom

    override fun hashCode(): Int {
        var result = left
        result = 31 * result + top
        result = 31 * result + right
        return 31 * result + bottom
    }

    override fun toString(): String = "PhysicalBounds(left=$left, top=$top, right=$right, bottom=$bottom)"
}
