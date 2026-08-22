package app.yahagi.kancollebrowser.browser

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger

class GameResourceCacheEngineTest {
    @get:Rule
    val temporaryFolder = TemporaryFolder()

    @Test
    fun `second exact request is served from disk`() {
        val fetcher = QueueFetcher(result(byteArrayOf(1, 2, 3)))
        val engine = engine(fetcher)
        val url = official("/kcs2/resources/a.png?version=21")

        val first = engine.fetch(url)
        val second = engine.fetch(url)

        assertArrayEquals(first?.bytes, second?.bytes)
        assertEquals(1, fetcher.calls.get())
        assertEquals(GameResourceResponseSource.NETWORK, first?.source)
        assertEquals(GameResourceResponseSource.CACHE, second?.source)
    }

    @Test
    fun `query version change downloads a new asset`() {
        val fetcher = QueueFetcher(result(byteArrayOf(1)), result(byteArrayOf(2)))
        val engine = engine(fetcher)

        val first = engine.fetch(official("/kcs2/resources/a.png?version=1"))
        val second = engine.fetch(official("/kcs2/resources/a.png?version=2"))

        assertArrayEquals(byteArrayOf(1), first?.bytes)
        assertArrayEquals(byteArrayOf(2), second?.bytes)
        assertEquals(2, fetcher.calls.get())
    }

    @Test
    fun `concurrent requests for one key download once`() {
        val started = CountDownLatch(1)
        val release = CountDownLatch(1)
        val fetcher = object : GameResourceFetcher {
            val calls = AtomicInteger()
            override fun fetch(
                url: String,
                requestHeaders: Map<String, String>,
                cached: GameResourceCacheEntry?,
            ): GameResourceFetchResult {
                calls.incrementAndGet()
                started.countDown()
                release.await(5, TimeUnit.SECONDS)
                return result(byteArrayOf(7))
            }
        }
        val engine = engine(fetcher)
        val pool = Executors.newFixedThreadPool(2)
        val first = pool.submit<GameResourceResponse?> { engine.fetch(official("/kcs2/resources/a.png")) }
        assertTrue(started.await(5, TimeUnit.SECONDS))
        val second = pool.submit<GameResourceResponse?> { engine.fetch(official("/kcs2/resources/a.png")) }
        release.countDown()

        assertArrayEquals(byteArrayOf(7), first.get(5, TimeUnit.SECONDS)?.bytes)
        assertArrayEquals(byteArrayOf(7), second.get(5, TimeUnit.SECONDS)?.bytes)
        assertEquals(1, fetcher.calls.get())
        pool.shutdownNow()
    }

    @Test
    fun `failed strict revalidation keeps exact cached file`() {
        val fetcher = QueueFetcher(result(byteArrayOf(4)), null)
        val engine = engine(fetcher)
        val url = official("/gadget_html5/js/kcs_const.js?version=8")

        assertArrayEquals(byteArrayOf(4), engine.fetch(url)?.bytes)
        val fallback = engine.fetch(url)

        assertArrayEquals(byteArrayOf(4), fallback?.bytes)
        assertEquals(GameResourceResponseSource.CACHE, fallback?.source)
        assertEquals(2, fetcher.calls.get())
    }

    @Test
    fun `none mode bypasses engine without network`() {
        val fetcher = QueueFetcher(result(byteArrayOf(1)))
        val engine = engine(fetcher, mode = GameResourceCacheMode.NONE)

        assertNull(engine.fetch(official("/kcs2/resources/a.png")))
        assertEquals(0, fetcher.calls.get())
    }

    @Test
    fun `unversioned resource revalidates after ttl and keeps 304 cache`() {
        var now = 1L
        val fetcher = QueueFetcher(
            result(byteArrayOf(1)),
            result(byteArrayOf(), statusCode = 304),
        )
        val engine = engine(fetcher, clock = { now })
        val url = official("/kcs2/resources/a.png")

        engine.fetch(url)
        engine.fetch(url)
        assertEquals(1, fetcher.calls.get())

        now += GameResourceCacheEngine.UNVERSIONED_TTL_MS
        val revalidated = engine.fetch(url)

        assertEquals(2, fetcher.calls.get())
        assertEquals(GameResourceResponseSource.CACHE, revalidated?.source)
    }

    @Test
    fun `manifest length keeps unversioned resource valid after ttl`() {
        var now = 1L
        val fetcher = QueueFetcher(result(byteArrayOf(1)))
        val engine = engine(fetcher, clock = { now })
        val url = official("/kcs2/resources/a.png")

        engine.fetch(url, expectedLength = 1)
        now += GameResourceCacheEngine.UNVERSIONED_TTL_MS

        assertEquals(
            GameResourceInspectionState.VALID,
            engine.inspectMetadata(url, expectedLength = 1).state,
        )
    }

    @Test
    fun `critical entry does not fall back to stale cache when validation fails`() {
        val fetcher = QueueFetcher(result(byteArrayOf(1)), null)
        val engine = engine(fetcher)
        val url = official("/kcs2/version.json")

        assertArrayEquals(byteArrayOf(1), engine.fetch(url)?.bytes)
        assertNull(engine.fetch(url))
        assertEquals(1, engine.entries().size)
    }

    @Test
    fun `manifest length mismatch is returned but never persisted`() {
        val engine = engine(QueueFetcher(result(byteArrayOf(1, 2))))
        val url = official("/kcs2/resources/a.png")

        val response = engine.fetch(url, expectedLength = 3)

        assertArrayEquals(byteArrayOf(1, 2), response?.bytes)
        assertNull(engine.fetch(url, expectedLength = 3, shouldStore = { false }))
        assertEquals(GameResourceInspectionState.MISSING, engine.inspectMetadata(url).state)
    }

    @Test
    fun `changed manifest length bypasses stale cache and stores replacement`() {
        val fetcher = QueueFetcher(
            result(byteArrayOf(1)),
            result(byteArrayOf(2, 3)),
        )
        val engine = engine(fetcher)
        val url = official("/kcs2/resources/a.png")

        engine.fetch(url, expectedLength = 1)
        val replacement = engine.fetch(url, expectedLength = 2)

        assertArrayEquals(byteArrayOf(2, 3), replacement?.bytes)
        assertEquals(GameResourceResponseSource.NETWORK, replacement?.source)
        assertEquals(2, fetcher.calls.get())
        assertEquals(
            GameResourceInspectionState.VALID,
            engine.inspectMetadata(url, expectedLength = 2).state,
        )
    }

    private fun engine(
        fetcher: GameResourceFetcher,
        mode: GameResourceCacheMode = GameResourceCacheMode.LIGHT,
        clock: () -> Long = System::currentTimeMillis,
    ): GameResourceCacheEngine {
        val root = temporaryFolder.newFolder()
        val store = GameResourceCacheStore(
            root,
            GameResourceCacheIndex(root.resolve("index.json")),
            10_000,
            clock,
        )
        return GameResourceCacheEngine(store, fetcher, clock) { mode }
    }

    private fun official(path: String) = "https://w17k.kancolle-server.com$path"

    private fun result(bytes: ByteArray, statusCode: Int = 200) = GameResourceFetchResult(
        statusCode = statusCode,
        reasonPhrase = "OK",
        headers = mapOf("Content-Type" to "image/png", "Content-Length" to bytes.size.toString()),
        bytes = bytes,
    )

    private class QueueFetcher(vararg results: GameResourceFetchResult?) : GameResourceFetcher {
        private val queue = ArrayDeque(results.toList())
        val calls = AtomicInteger()

        override fun fetch(
            url: String,
            requestHeaders: Map<String, String>,
            cached: GameResourceCacheEntry?,
        ): GameResourceFetchResult? {
            calls.incrementAndGet()
            return if (queue.isEmpty()) null else queue.removeFirst()
        }
    }
}
