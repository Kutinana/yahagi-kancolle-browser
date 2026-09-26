package app.yahagi.kancollebrowser.composition

import java.util.zip.CRC32

object CompositionImagePolicy {
    const val MAX_BYTES = 16 * 1024 * 1024
    const val MAX_PIXELS = 16_000_000L
    private val signature = byteArrayOf(137.toByte(), 80, 78, 71, 13, 10, 26, 10)

    /** Checks framing and bounds before the platform decoder can allocate pixels. */
    fun validate(bytes: ByteArray) {
        require(bytes.size in 45..MAX_BYTES) { "The PNG must be at most 16 MiB." }
        require(signature.indices.all { bytes[it] == signature[it] }) {
            "Only PNG images can be saved."
        }
        var offset = signature.size
        var hasImageData = false
        while (offset <= bytes.size - 12) {
            val length = unsignedInt(bytes, offset)
            require(length <= bytes.size - offset - 12L) { "The PNG is truncated." }
            val chunkLength = length.toInt()
            val type = String(bytes, offset + 4, 4, Charsets.US_ASCII)
            if (offset == signature.size) {
                require(type == "IHDR" && chunkLength == 13) { "The PNG header is invalid." }
                val width = unsignedInt(bytes, offset + 8)
                val height = unsignedInt(bytes, offset + 12)
                require(width in 1..MAX_PIXELS && height in 1..MAX_PIXELS &&
                    width * height <= MAX_PIXELS) { "The PNG exceeds 16 million pixels." }
            } else {
                require(type != "IHDR") { "The PNG has multiple headers." }
            }
            val crc = CRC32().apply { update(bytes, offset + 4, chunkLength + 4) }
            require(crc.value == unsignedInt(bytes, offset + 8 + chunkLength)) {
                "The PNG data is corrupt."
            }
            offset += chunkLength + 12
            if (type == "IDAT") hasImageData = true
            if (type == "IEND") {
                require(chunkLength == 0 && hasImageData && offset == bytes.size) {
                    "The PNG image data or ending is invalid."
                }
                return
            }
        }
        throw IllegalArgumentException("The PNG is incomplete.")
    }

    private fun unsignedInt(bytes: ByteArray, offset: Int): Long =
        (0..3).fold(0L) { value, index ->
            (value shl 8) or (bytes[offset + index].toLong() and 0xff)
        }
}

data class CompositionImageDestination(
    val fileName: String,
    val relativeDirectory: String,
) {
    val displayLocation: String get() = "$relativeDirectory/$fileName"

    companion object {
        fun create(timestamp: String): CompositionImageDestination =
            CompositionImageDestination(
                fileName = "Yahagi-composition-$timestamp.png",
                relativeDirectory = "Pictures/Yahagi/Compositions",
            )
    }
}
