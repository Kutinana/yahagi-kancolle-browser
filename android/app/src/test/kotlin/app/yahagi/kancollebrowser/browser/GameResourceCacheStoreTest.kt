package app.yahagi.kancollebrowser.browser

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

class GameResourceCacheStoreTest {
    @get:Rule
    val temporaryFolder = TemporaryFolder()

    @Test
    fun `default capacity is fifty decimal gigabytes`() {
        assertEquals(50_000_000_000L, GameResourceCacheStore.DEFAULT_MAX_BYTES)
    }

    @Test
    fun `temporary policy expires entries after seven idle days`() {
        var now = 1L
        val root = temporaryFolder.newFolder("expiry")
        val store = GameResourceCacheStore(
            root,
            GameResourceCacheIndex(root.resolve("index.json")),
            clock = { now },
            policyProvider = {
                GameResourceCachePolicy(
                    maxBytes = 10,
                    maxIdleAgeMs = GameResourceCacheStore.TEMPORARY_MAX_IDLE_AGE_MS,
                )
            },
        )
        val key = GameResourceCacheKey("/kcs2/resources/a.png")
        store.commit(key, byteArrayOf(1), mimeType = "image/png")

        now += GameResourceCacheStore.TEMPORARY_MAX_IDLE_AGE_MS

        assertNull(store.read(key))
        assertFalse(store.contains(key))
    }

    @Test
    fun `enforce policy shrinks cache by least recent access`() {
        var now = 1L
        var policy = GameResourceCachePolicy(maxBytes = 10)
        val root = temporaryFolder.newFolder("shrink")
        val store = GameResourceCacheStore(
            root,
            GameResourceCacheIndex(root.resolve("index.json")),
            clock = { now++ },
            policyProvider = { policy },
        )
        val oldest = GameResourceCacheKey("/kcs2/resources/old.png")
        val newest = GameResourceCacheKey("/kcs2/resources/new.png")
        store.commit(oldest, byteArrayOf(1, 2, 3, 4), mimeType = "image/png")
        store.commit(newest, byteArrayOf(5, 6, 7, 8), mimeType = "image/png")

        policy = GameResourceCachePolicy(maxBytes = 4)
        store.enforcePolicy()

        assertFalse(store.contains(oldest))
        assertTrue(store.contains(newest))
        assertEquals(4L, store.totalBytes())
    }

    @Test
    fun `full policy keeps old entries`() {
        var now = 1L
        val root = temporaryFolder.newFolder("persistent")
        val store = GameResourceCacheStore(
            root,
            GameResourceCacheIndex(root.resolve("index.json")),
            clock = { now },
            policyProvider = { GameResourceCachePolicy(maxBytes = 10) },
        )
        val key = GameResourceCacheKey("/kcs2/resources/a.png")
        store.commit(key, byteArrayOf(1), mimeType = "image/png")

        now += GameResourceCacheStore.TEMPORARY_MAX_IDLE_AGE_MS * 2

        assertArrayEquals(byteArrayOf(1), store.read(key)?.bytes)
    }

    @Test
    fun `atomic commit survives index reload`() {
        val root = temporaryFolder.newFolder("cache")
        val key = GameResourceCacheKey("/kcs2/resources/a.png?version=21")
        val store = GameResourceCacheStore(
            root,
            GameResourceCacheIndex(root.resolve("index.json")),
            maxBytes = 10_000,
        )

        store.commit(key, byteArrayOf(1, 2, 3), version = "21", mimeType = "image/png")

        val reloaded = GameResourceCacheStore(
            root,
            GameResourceCacheIndex(root.resolve("index.json")),
            maxBytes = 10_000,
        )
        assertArrayEquals(byteArrayOf(1, 2, 3), reloaded.read(key)?.bytes)
    }

    @Test
    fun `temporary and corrupted files are never cache hits`() {
        val root = temporaryFolder.newFolder("cache")
        val key = GameResourceCacheKey("/kcs2/resources/a.png")
        val store = GameResourceCacheStore(root, GameResourceCacheIndex(root.resolve("index.json")), 10_000)
        root.resolve("tmp").mkdirs()
        root.resolve("tmp/orphan.part").writeBytes(byteArrayOf(9))
        assertNull(store.read(key))

        val entry = store.commit(key, byteArrayOf(1, 2, 3), mimeType = "image/png")
        root.resolve("files/${entry.fileName}").writeBytes(byteArrayOf(1))

        assertNull(store.read(key))
        assertFalse(store.contains(key))
    }

    @Test
    fun `metadata inspection avoids checksumming until explicit integrity check`() {
        val root = temporaryFolder.newFolder("cache")
        val key = GameResourceCacheKey("/kcs2/resources/a.png")
        val store = GameResourceCacheStore(root, GameResourceCacheIndex(root.resolve("index.json")), 10_000)
        val entry = store.commit(key, byteArrayOf(1, 2, 3), mimeType = "image/png")
        root.resolve("files/${entry.fileName}").writeBytes(byteArrayOf(4, 5, 6))

        assertEquals(GameResourceStoredState.VALID, store.inspectMetadata(key).state)
        assertEquals(GameResourceStoredState.DAMAGED, store.inspect(key).state)
    }

    @Test
    fun `eviction removes least recently used unprotected files`() {
        var now = 1L
        val root = temporaryFolder.newFolder("cache")
        val store = GameResourceCacheStore(
            root,
            GameResourceCacheIndex(root.resolve("index.json")),
            maxBytes = 6,
            clock = { now++ },
        )
        val oldest = GameResourceCacheKey("/kcs2/resources/old.png")
        val protected = GameResourceCacheKey("/kcs2/resources/protected.png")
        store.commit(oldest, byteArrayOf(1, 2, 3), mimeType = "image/png")
        store.commit(protected, byteArrayOf(4, 5, 6), mimeType = "image/png")

        val removed = store.evictToFit(requiredBytes = 3, protectedKeys = setOf(protected))

        assertEquals(listOf(oldest), removed)
        assertNull(store.read(oldest))
        assertTrue(store.contains(protected))
        assertFalse(store.wouldExceedCapacity(3))
    }

    @Test
    fun `eviction applies independently of cache profile`() {
        val root = temporaryFolder.newFolder("cache")
        val store = GameResourceCacheStore(root, GameResourceCacheIndex(root.resolve("index.json")), 5)
        val key = GameResourceCacheKey("/kcs2/resources/a.png")
        store.commit(key, byteArrayOf(1, 2, 3), mimeType = "image/png")

        assertEquals(listOf(key), store.evictToFit(3))
        assertFalse(store.contains(key))
        assertFalse(store.wouldExceedCapacity(3))
    }

    @Test
    fun `concurrent commits cannot exceed hard capacity`() {
        val root = temporaryFolder.newFolder("cache")
        val store = GameResourceCacheStore(root, GameResourceCacheIndex(root.resolve("index.json")), 3)
        val ready = CountDownLatch(2)
        val release = CountDownLatch(1)
        val pool = Executors.newFixedThreadPool(2)
        val futures = (1..2).map { id ->
            pool.submit {
                ready.countDown()
                release.await(5, TimeUnit.SECONDS)
                store.commitWithEviction(
                    GameResourceCacheKey("/kcs2/resources/$id.png"),
                    byteArrayOf(id.toByte(), id.toByte()),
                    mimeType = "image/png",
                )
            }
        }
        assertTrue(ready.await(5, TimeUnit.SECONDS))

        release.countDown()
        futures.forEach { it.get(5, TimeUnit.SECONDS) }

        assertTrue(store.totalBytes() <= 3)
        assertEquals(1, store.entries().size)
        pool.shutdownNow()
    }
}
