package app.yahagi.kancollebrowser.browser

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class GameResourceCacheRulesTest {
    @Test
    fun `accepts versioned official static asset`() {
        val url = "https://w17k.kancolle-server.com/kcs2/resources/ship/full/a.png?version=21"

        assertTrue(GameResourceCacheRules.shouldCache(url, "GET"))
        assertEquals(
            "/kcs2/resources/ship/full/a.png?version=21",
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
                "http://w10k.kancolle-server.com/kcs/sound/kc123/001.mp3",
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
    }

    @Test
    fun `cache key ignores official server host but preserves query`() {
        val first = GameResourceCacheKey.from(
            "https://w01k.kancolle-server.com/kcs2/resources/a.png?version=1&x=2",
        )
        val second = GameResourceCacheKey.from(
            "http://w49k.kancolle-server.com/kcs2/resources/a.png?version=1&x=2",
        )

        assertEquals(first, second)
        assertEquals("/kcs2/resources/a.png?version=1&x=2", first?.value)
        assertNull(GameResourceCacheKey.from("https://example.com/kcs2/resources/a.png"))
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
