package app.yahagi.kancollebrowser.browser

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.security.MessageDigest

class GameResourceCacheRulesTest {
    @Test
    fun `oversized URL is rejected before URI parsing`() {
        val url = "https://w17k.kancolle-server.com/kcs2/resources/a.png?" + "x".repeat(3_000)

        assertFalse(GameResourceCacheRules.shouldCache(url, "GET"))
    }

    @Test
    fun `accepts versioned official static asset`() {
        val url = "https://w17k.kancolle-server.com/kcs2/resources/ship/full/a.png?version=21"

        assertTrue(GameResourceCacheRules.shouldCache(url, "GET"))
        assertEquals(
            "https://w17k.kancolle-server.com/kcs2/resources/ship/full/a.png?version=21",
            GameResourceCacheKey.from(url)?.value,
        )
    }

    @Test
    fun `accepts current images and legacy sounds`() {
        assertTrue(
            GameResourceCacheRules.shouldCache(
                "https://w01y.kancolle-server.com/kcs2/js/main.js?version=123",
                "GET",
            ),
        )
        assertTrue(
            GameResourceCacheRules.shouldCache(
                "https://w01y.kancolle-server.com/kcs2/version.json",
                "GET",
            ),
        )
        assertTrue(
            GameResourceCacheRules.shouldCache(
                "https://w02k.kancolle-server.com/kcs2/img/common/common.png",
                "GET",
            ),
        )
        assertTrue(
            GameResourceCacheRules.shouldCache(
                "https://w10k.kancolle-server.com/kcs/sound/kc123/001.mp3",
                null,
            ),
        )
        assertTrue(
            GameResourceCacheRules.shouldCache(
                "https://w01y.kancolle-server.com/kcs2/resources/ship/full/a.png",
                "GET",
            ),
        )
        assertTrue(
            GameResourceCacheRules.shouldCache(
                "https://w00g.kancolle-server.com/html/maintenance.html",
                "GET",
            ),
        )
        assertTrue(
            GameResourceCacheRules.shouldCache(
                "https://w00g.kancolle-server.com/kcscontents/image/banner.png",
                "GET",
            ),
        )
        assertTrue(
            GameResourceCacheRules.shouldCache(
                "https://w00g.kancolle-server.com/kcs2/hc.html",
                "GET",
            ),
        )
    }

    @Test
    fun `rejects dynamic and unsafe requests`() {
        assertFalse(
            GameResourceCacheRules.shouldCache(
                "https://w17k.kancolle-server.com/kcsapi/api_port/port",
                "GET",
            ),
        )
        assertFalse(
            GameResourceCacheRules.shouldCache(
                "https://www.dmm.com/netgame/social/-/gadgets/=/app_id=854854/",
                "GET",
            ),
        )
        assertFalse(
            GameResourceCacheRules.shouldCache(
                "https://w17k.kancolle-server.com/kcs2/resources/a.php",
                "GET",
            ),
        )
        assertFalse(
            GameResourceCacheRules.shouldCache(
                "https://w17k.kancolle-server.com/kcs2/resources/a.png",
                "POST",
            ),
        )
        assertFalse(
            GameResourceCacheRules.shouldCache(
                "https://user:secret@w17k.kancolle-server.com/kcs2/resources/a.png",
                "GET",
            ),
        )
        assertFalse(
            GameResourceCacheRules.shouldCache(
                "https://w17k.kancolle-server.com/kcs2/resources/a.unknown",
                "GET",
            ),
        )
        assertFalse(
            GameResourceCacheRules.shouldCache(
                "http://w17k.kancolle-server.com/kcs2/resources/a.png",
                "GET",
            ),
        )
        assertFalse(
            GameResourceCacheRules.shouldCache(
                "https://w17k.kancolle-server.com:8443/kcs2/resources/a.png",
                "GET",
            ),
        )
    }

    @Test
    fun `OOI modes never enter Yahagi local resource cache`() {
        assertFalse(GameResourceCacheRules.shouldCache("https://ooi.moe/", "GET"))
        assertFalse(GameResourceCacheRules.shouldCache("https://ooi.moe/browser", "GET"))
        assertFalse(GameResourceCacheRules.shouldCache("https://ooi.moe/poi", "GET"))
        assertFalse(GameResourceCacheRules.shouldCache("https://ooi.moe/connector", "POST"))
        assertFalse(GameResourceCacheRules.shouldCache("https://ooi.moe/kcsapi/api_port/port", "POST"))
        assertTrue(
            GameResourceCacheRules.shouldCache(
                "https://w17k.kancolle-server.com/kcs2/resources/ship/full/a.png",
                "GET",
            ),
        )
    }

    @Test
    fun `cache key includes official server host and preserves query`() {
        val first = GameResourceCacheKey.from(
            "https://w01k.kancolle-server.com/kcs2/resources/a.png?version=1&x=2",
        )
        val second = GameResourceCacheKey.from(
            "https://w49k.kancolle-server.com/kcs2/resources/a.png?version=1&x=2",
        )

        assertFalse(first == second)
        assertEquals("https://w01k.kancolle-server.com/kcs2/resources/a.png?version=1&x=2", first?.value)
        assertNull(GameResourceCacheKey.from("https://example.com/kcs2/resources/a.png"))
    }

    @Test
    fun `boot scripts remain separated by request identity`() {
        val url = "https://w00g.kancolle-server.com/gadget_html5/js/kcs_const.js"
        val first = GameResourceCacheKey.from(url, mapOf("Cookie" to "account=A"))
        val second = GameResourceCacheKey.from(url, mapOf("Cookie" to "account=B"))
        assertFalse(first == second)
        assertFalse(first?.value.orEmpty().contains("account=A"))
    }

    @Test
    fun `resource data remains account scoped while binary images can be shared`() {
        val dataUrl = "https://w00g.kancolle-server.com/kcs2/resources/account.json"
        val imageUrl = "https://w00g.kancolle-server.com/kcs2/resources/ship.png"
        val accountA = mapOf("Cookie" to "account=A")
        val accountB = mapOf("Cookie" to "account=B")

        assertFalse(GameResourceCacheKey.from(dataUrl, accountA) == GameResourceCacheKey.from(dataUrl, accountB))
        assertEquals(GameResourceCacheKey.from(imageUrl, accountA), GameResourceCacheKey.from(imageUrl, accountB))
    }

    @Test
    fun `WebView without cookie interception accepts official static files as in beta2`() {
        val image = "https://w17k.kancolle-server.com/kcs2/resources/ship/full/a.png?version=21"
        val sound = "https://w17k.kancolle-server.com/kcs/sound/kc123/001.mp3"
        val script = "https://w17k.kancolle-server.com/kcs2/js/main.js"
        val data = "https://w17k.kancolle-server.com/kcs2/resources/account.json"

        assertTrue(GameResourceCacheRules.canInterceptWithoutCookieHeaders(image, "GET"))
        assertTrue(GameResourceCacheRules.canInterceptWithoutCookieHeaders(sound, "GET"))
        assertTrue(GameResourceCacheRules.canInterceptWithoutCookieHeaders(script, "GET"))
        assertTrue(GameResourceCacheRules.canInterceptWithoutCookieHeaders(data, "GET"))
        assertFalse(GameResourceCacheRules.canInterceptWithoutCookieHeaders(image, "POST"))
        assertFalse(GameResourceCacheRules.canInterceptWithoutCookieHeaders(
            "https://example.com/kcs2/resources/ship.png", "GET",
        ))
    }

    @Test
    fun `fallback cookie isolates account scoped cache entries on old WebView`() {
        val url = "https://w17k.kancolle-server.com/kcs2/resources/account.json"
        val accountA = GameResourceCacheRules.withFallbackCookie(emptyMap(), "account=A")
        val accountB = GameResourceCacheRules.withFallbackCookie(emptyMap(), "account=B")
        val provided = GameResourceCacheRules.withFallbackCookie(
            mapOf("Cookie" to "account=provided"), "account=ignored",
        )

        assertFalse(GameResourceCacheKey.from(url, accountA) == GameResourceCacheKey.from(url, accountB))
        assertEquals("account=provided", provided["Cookie"])
    }

    @Test
    fun `large request headers bypass cache without constructing a variant string`() {
        val cookie = "x".repeat(100_000)
        val dataUrl = "https://w00g.kancolle-server.com/kcs2/resources/account.json"
        val imageUrl = "https://w00g.kancolle-server.com/kcs2/resources/ship.png"

        assertNull(GameResourceCacheKey.from(dataUrl, mapOf("Cookie" to cookie)))
        assertNull(GameResourceCacheKey.from(imageUrl, mapOf("Cookie" to cookie)))
    }

    @Test
    fun `bounded header hash keeps existing account cache keys`() {
        val url = "https://w00g.kancolle-server.com/gadget_html5/js/kcs_const.js"
        val variant = "accept:application/javascript\ncookie:account=A\nuser-agent:WebView"
        val hash = MessageDigest.getInstance("SHA-256")
            .digest(variant.toByteArray(Charsets.UTF_8))
            .joinToString("") { "%02x".format(it) }

        assertEquals("$url|headers=$hash", GameResourceCacheKey.from(url, mapOf(
            "User-Agent" to "WebView",
            "Cookie" to "account=A",
            "Accept" to "application/javascript",
        ))?.value)
    }

    @Test
    fun `marks client boot files for strict validation`() {
        assertTrue(
            GameResourceCacheRules.isAlwaysValidated(
                "https://w00g.kancolle-server.com/gadget_html5/js/kcs_const.js",
            ),
        )
        assertFalse(
            GameResourceCacheRules.isAlwaysValidated(
                "https://w17k.kancolle-server.com/kcs2/resources/ship/full/a.png",
            ),
        )
    }
}
