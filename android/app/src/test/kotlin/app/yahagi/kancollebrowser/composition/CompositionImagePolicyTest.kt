package app.yahagi.kancollebrowser.composition

import java.util.Base64
import java.util.zip.CRC32
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test

class CompositionImagePolicyTest {
    @Test
    fun acceptsACompletePng() {
        CompositionImagePolicy.validate(png())
    }

    @Test
    fun rejectsOtherImageFormatsAndMissingBytes() {
        assertThrows(IllegalArgumentException::class.java) {
            CompositionImagePolicy.validate(byteArrayOf())
        }
        val otherFormat = png().also { it[0] = 0xff.toByte(); it[1] = 0xd8.toByte() }
        assertThrows(IllegalArgumentException::class.java) {
            CompositionImagePolicy.validate(otherFormat)
        }
    }

    @Test
    fun rejectsOversizedPayloadBeforeDecoding() {
        val oversized = png().copyOf(16 * 1024 * 1024 + 1)
        assertThrows(IllegalArgumentException::class.java) {
            CompositionImagePolicy.validate(oversized)
        }
    }

    @Test
    fun rejectsDimensionsThatExceedTheDecodedPixelBudget() {
        assertThrows(IllegalArgumentException::class.java) {
            CompositionImagePolicy.validate(withDimensions(png(), 8000, 8000))
        }
        assertThrows(IllegalArgumentException::class.java) {
            CompositionImagePolicy.validate(withDimensions(png(), Int.MAX_VALUE, 2))
        }
        assertThrows(IllegalArgumentException::class.java) {
            CompositionImagePolicy.validate(withDimensions(png(), 0, 1))
        }
    }

    @Test
    fun rejectsTruncatedChunksCorruptionAndTrailingContent() {
        val valid = png()
        val corrupted = valid.copyOf().also { it[50] = (it[50].toInt() xor 1).toByte() }
        for (invalid in listOf(valid.copyOf(20), valid.dropLast(1).toByteArray(), corrupted, valid + 0)) {
            assertThrows(IllegalArgumentException::class.java) {
                CompositionImagePolicy.validate(invalid)
            }
        }
    }

    @Test
    fun separatesCompositionImagesFromOrdinaryScreenshots() {
        val destination = CompositionImageDestination.create("20260912-120000-123")
        assertEquals("Yahagi-composition-20260912-120000-123.png", destination.fileName)
        assertEquals("Pictures/Yahagi/Compositions", destination.relativeDirectory)
        assertEquals(
            "Pictures/Yahagi/Compositions/Yahagi-composition-20260912-120000-123.png",
            destination.displayLocation,
        )
    }

    // A real, complete 1 x 1 transparent PNG; no Android decoder is needed by these JVM tests.
    private fun png(): ByteArray = Base64.getDecoder().decode(
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAAXNSR0IArs4c6Q" +
            "AAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAAALSURB" +
            "VBhXY2AAAgAABQABqtXIUQAAAABJRU5ErkJggg==",
    )

    private fun withDimensions(source: ByteArray, width: Int, height: Int): ByteArray {
        val bytes = source.copyOf()
        putInt(bytes, 16, width)
        putInt(bytes, 20, height)
        val crc = CRC32().apply { update(bytes, 12, 17) }.value
        putInt(bytes, 29, crc.toInt())
        return bytes
    }

    private fun putInt(bytes: ByteArray, offset: Int, value: Int) {
        for (index in 0..3) bytes[offset + index] = (value ushr (24 - 8 * index)).toByte()
    }
}
