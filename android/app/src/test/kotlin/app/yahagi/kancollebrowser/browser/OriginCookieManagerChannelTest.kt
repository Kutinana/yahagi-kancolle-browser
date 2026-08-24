package app.yahagi.kancollebrowser.browser

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class OriginCookieManagerChannelTest {
    @Test
    fun clearsOnlyValidCookieNamesWithoutExposingValues() {
        val store = FakeOriginCookieStore(
            "owner=owner-secret; token=token-secret; play_mode=1; bad name=leak",
        )
        val channel = OriginCookieManagerChannel(store)
        val result = OriginCookieRecordingResult()

        channel.onMethodCall(validCall(), result)

        assertEquals(null, result.successValue)
        assertNull(result.errorCode)
        assertTrue(store.flushed)
        assertEquals(6, store.expiredCookies.size)
        assertTrue(store.expiredCookies.all { it.first == "https://ooi.moe" })
        assertTrue(store.expiredCookies.count { it.second.startsWith("owner=") } == 2)
        assertTrue(store.expiredCookies.count { it.second.startsWith("token=") } == 2)
        assertTrue(store.expiredCookies.count { it.second.startsWith("play_mode=") } == 2)
        assertFalse(store.expiredCookies.any { it.second.contains("secret") })
        assertFalse(store.expiredCookies.any { it.second.startsWith("bad name=") })
    }

    @Test
    fun emptyCookieHeaderCompletesWithoutWritingCookies() {
        val store = FakeOriginCookieStore(null)
        val result = OriginCookieRecordingResult()

        OriginCookieManagerChannel(store).onMethodCall(validCall(), result)

        assertEquals(null, result.successValue)
        assertTrue(store.expiredCookies.isEmpty())
        assertTrue(store.flushed)
    }

    @Test
    fun rejectsEveryOriginExceptExactOoiHttpsOrigin() {
        val invalidOrigins = listOf(
            "http://ooi.moe",
            "https://sub.ooi.moe",
            "https://ooi.moe.example.org",
            "https://ooi.moe:8443",
            "https://user@ooi.moe",
            "https://ooi.moe/",
            "https://ooi.moe/path",
            "https://ooi.moe?query=1",
            "https://ooi.moe#fragment",
        )

        for (origin in invalidOrigins) {
            val store = FakeOriginCookieStore("token=secret")
            val result = OriginCookieRecordingResult()
            OriginCookieManagerChannel(store).onMethodCall(
                MethodCall(
                    "clearCookiesForOrigin",
                    mapOf("origin" to origin),
                ),
                result,
            )

            assertEquals("invalid_origin", result.errorCode)
            assertTrue(store.expiredCookies.isEmpty())
            assertFalse(store.flushed)
            assertFalse(result.errorMessage.orEmpty().contains("secret"))
        }
    }

    @Test
    fun requiresExactMethodAndArgumentSchema() {
        val store = FakeOriginCookieStore("token=secret")
        val channel = OriginCookieManagerChannel(store)

        val unknown = OriginCookieRecordingResult()
        channel.onMethodCall(MethodCall("unknown", null), unknown)
        assertTrue(unknown.notImplemented)

        val malformed = OriginCookieRecordingResult()
        channel.onMethodCall(
            MethodCall(
                "clearCookiesForOrigin",
                mapOf("origin" to "https://ooi.moe", "extra" to true),
            ),
            malformed,
        )
        assertEquals("invalid_argument", malformed.errorCode)
        assertTrue(store.expiredCookies.isEmpty())
    }

    private fun validCall() = MethodCall(
        "clearCookiesForOrigin",
        mapOf("origin" to "https://ooi.moe"),
    )
}

private class FakeOriginCookieStore(
    private val header: String?,
) : OriginCookieStore {
    val expiredCookies = mutableListOf<Pair<String, String>>()
    var flushed = false

    override fun getCookieHeader(origin: String): String? = header

    override fun setExpiredCookie(origin: String, cookie: String) {
        expiredCookies += origin to cookie
    }

    override fun flush() {
        flushed = true
    }
}

private class OriginCookieRecordingResult : MethodChannel.Result {
    var successValue: Any? = Unit
    var errorCode: String? = null
    var errorMessage: String? = null
    var notImplemented = false

    override fun success(result: Any?) {
        successValue = result
    }

    override fun error(code: String, message: String?, details: Any?) {
        errorCode = code
        errorMessage = message
    }

    override fun notImplemented() {
        notImplemented = true
    }
}
