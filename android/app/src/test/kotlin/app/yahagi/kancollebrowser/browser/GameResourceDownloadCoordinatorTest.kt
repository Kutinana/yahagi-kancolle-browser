package app.yahagi.kancollebrowser.browser

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.File
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger
import java.util.concurrent.CopyOnWriteArrayList

class GameResourceDownloadCoordinatorTest {
    @get:Rule
    val temporaryFolder = TemporaryFolder()

    @Test
    fun `manifest is deduplicated and download completes`() {
        val calls = AtomicInteger()
        val fixture = fixture(fetcher = GameResourceFetcher { _, _, _ ->
            calls.incrementAndGet()
            response(byteArrayOf(1))
        })
        val url = official("/kcs2/resources/a.png")
        fixture.coordinator.setManifest("light", listOf(url, url), 1)

        assertTrue(fixture.coordinator.startDownload())
        awaitState(fixture.coordinator, GameResourceDownloadState.COMPLETE)

        assertEquals(1, calls.get())
        assertEquals(0, fixture.coordinator.status().missingCount)
        fixture.coordinator.dispose()
    }

    @Test
    fun `pause finishes active item but does not take another until resume`() {
        val firstStarted = CountDownLatch(1)
        val releaseFirst = CountDownLatch(1)
        val calls = AtomicInteger()
        val fixture = fixture(fetcher = GameResourceFetcher { _, _, _ ->
            if (calls.incrementAndGet() == 1) {
                firstStarted.countDown()
                releaseFirst.await(5, TimeUnit.SECONDS)
            }
            response(byteArrayOf(1))
        })
        fixture.coordinator.setManifest(
            "light",
            listOf(official("/kcs2/resources/a.png"), official("/kcs2/resources/b.png")),
            2,
        )
        fixture.coordinator.startDownload()
        assertTrue(firstStarted.await(5, TimeUnit.SECONDS))

        fixture.coordinator.pauseDownload()
        releaseFirst.countDown()
        awaitState(fixture.coordinator, GameResourceDownloadState.PAUSED)
        Thread.sleep(100)
        assertEquals(1, calls.get())

        assertTrue(fixture.coordinator.startDownload())
        awaitState(fixture.coordinator, GameResourceDownloadState.COMPLETE)
        assertEquals(2, calls.get())
        fixture.coordinator.dispose()
    }

    @Test
    fun `full mode blocks at capacity without deleting cached files`() {
        val fixture = fixture(
            mode = GameResourceCacheMode.FULL,
            maxBytes = 1,
            fetcher = GameResourceFetcher { _, _, _ -> response(byteArrayOf(1, 2)) },
        )
        val url = official("/kcs2/resources/a.png")
        fixture.coordinator.setManifest("full", listOf(url), 2)

        assertFalse(fixture.coordinator.startDownload())
        assertEquals(GameResourceDownloadState.CAPACITY_BLOCKED, fixture.coordinator.status().state)
        assertTrue(fixture.coordinator.status().capacityBlocked)
        assertEquals(0, fixture.engine.status().fileCount)
        fixture.coordinator.dispose()
    }

    @Test
    fun `paused manifest snapshot is restored`() {
        val stateFile = temporaryFolder.newFile("download-state.json")
        val fixture = fixture(stateFile = stateFile)
        fixture.coordinator.setManifest(
            "light",
            listOf(official("/kcs2/resources/a.png"), official("/kcs2/resources/a.png")),
            9,
        )
        fixture.coordinator.pauseDownload()
        fixture.coordinator.dispose()

        val restored = GameResourceDownloadCoordinator(fixture.engine, { GameResourceCacheMode.LIGHT }, stateFile)
        val status = restored.status()
        assertEquals(GameResourceDownloadState.PAUSED, status.state)
        assertEquals(1, status.missingCount)
        assertEquals(9, status.targetBytes)
        restored.setManifest(
            "light",
            listOf(official("/kcs2/resources/a.png")),
            9,
        )
        assertFalse(restored.startAutoUpdate())
        assertEquals(GameResourceDownloadState.PAUSED, restored.status().state)
        restored.dispose()
    }

    @Test
    fun `bulk download waits for wifi and resumes when network changes`() {
        var network = GameResourceNetworkState(connected = true, metered = true)
        val fixture = fixture(networkProvider = { network })
        fixture.coordinator.setManifest(
            "light",
            listOf(official("/kcs2/resources/a.png")),
            1,
        )

        assertFalse(fixture.coordinator.startDownload())
        assertTrue(fixture.coordinator.status().waitingForWifi)

        network = GameResourceNetworkState(connected = true, metered = false)
        fixture.coordinator.onNetworkChanged()
        awaitState(fixture.coordinator, GameResourceDownloadState.COMPLETE)
        fixture.coordinator.dispose()
    }

    @Test
    fun `confirmed mobile data download is allowed for current run`() {
        val fixture = fixture(
            networkProvider = {
                GameResourceNetworkState(connected = true, metered = true)
            },
        )
        fixture.coordinator.setManifest(
            "light",
            listOf(official("/kcs2/resources/a.png")),
            1,
        )

        assertTrue(fixture.coordinator.startDownload(allowMetered = true))
        awaitState(fixture.coordinator, GameResourceDownloadState.COMPLETE)
        fixture.coordinator.dispose()
    }

    @Test
    fun `automatic update starts only after first manual authorization`() {
        val fixture = fixture()
        val first = official("/kcs2/resources/a.png?version=1")
        val second = official("/kcs2/resources/b.png?version=1")
        fixture.coordinator.setManifest("light", listOf(first), 1)

        assertFalse(fixture.coordinator.startAutoUpdate())
        assertEquals(GameResourceDownloadState.IDLE, fixture.coordinator.status().state)

        assertTrue(fixture.coordinator.startDownload())
        awaitState(fixture.coordinator, GameResourceDownloadState.COMPLETE)
        fixture.coordinator.setManifest("light", listOf(first, second), 2)
        assertTrue(fixture.coordinator.startAutoUpdate())
        awaitState(fixture.coordinator, GameResourceDownloadState.COMPLETE)
        fixture.coordinator.dispose()
    }

    @Test
    fun `status bytes count only valid files in current manifest`() {
        val fixture = fixture()
        fixture.engine.fetch(official("/kcs2/resources/unrelated.png?version=1"))
        fixture.coordinator.setManifest(
            "light",
            listOf(official("/kcs2/resources/target.png?version=1")),
            10,
        )

        assertEquals(0, fixture.coordinator.status().cachedBytes)
        fixture.coordinator.dispose()
    }

    @Test
    fun `integrity check reports a corrupted manifest file as damaged`() {
        val fixture = fixture()
        val url = official("/kcs2/resources/a.png?version=1")
        fixture.engine.fetch(url)
        val entry = fixture.engine.entries().single()
        fixture.root.resolve("files/${entry.fileName}").writeBytes(byteArrayOf(9, 9))
        fixture.coordinator.setManifest("light", listOf(url), 1)

        val status = fixture.coordinator.checkIntegrity()

        assertEquals(0, status.missingCount)
        assertEquals(1, status.damagedCount)
        fixture.coordinator.dispose()
    }

    @Test
    fun `replacing manifest cancels remaining work from old generation`() {
        val firstStarted = CountDownLatch(1)
        val releaseFirst = CountDownLatch(1)
        val visited = CopyOnWriteArrayList<String>()
        val oldFirst = official("/kcs2/resources/old-a.png?version=1")
        val oldSecond = official("/kcs2/resources/old-b.png?version=1")
        val current = official("/kcs2/resources/current.png?version=1")
        val fixture = fixture(fetcher = GameResourceFetcher { url, _, _ ->
            visited += url
            if (url == oldFirst) {
                firstStarted.countDown()
                releaseFirst.await(5, TimeUnit.SECONDS)
            }
            response(byteArrayOf(1))
        })
        fixture.coordinator.setManifest("full", listOf(oldFirst, oldSecond), 2)
        fixture.coordinator.startDownload()
        assertTrue(firstStarted.await(5, TimeUnit.SECONDS))

        fixture.coordinator.setManifest("light", listOf(current), 1)
        fixture.coordinator.startDownload()
        releaseFirst.countDown()
        awaitState(fixture.coordinator, GameResourceDownloadState.COMPLETE)

        assertFalse(visited.contains(oldSecond))
        assertTrue(visited.contains(current))
        fixture.coordinator.dispose()
    }

    private fun fixture(
        mode: GameResourceCacheMode = GameResourceCacheMode.LIGHT,
        maxBytes: Long = 10_000,
        stateFile: File = temporaryFolder.newFile(),
        fetcher: GameResourceFetcher = GameResourceFetcher { _, _, _ -> response(byteArrayOf(1)) },
        networkProvider: () -> GameResourceNetworkState = {
            GameResourceNetworkState(connected = true, metered = false)
        },
    ): Fixture {
        val root = temporaryFolder.newFolder()
        val store = GameResourceCacheStore(root, GameResourceCacheIndex(root.resolve("index.json")), maxBytes)
        val engine = GameResourceCacheEngine(store, fetcher) { mode }
        return Fixture(
            root,
            engine,
            GameResourceDownloadCoordinator(engine, { mode }, stateFile, networkProvider),
        )
    }

    private fun awaitState(
        coordinator: GameResourceDownloadCoordinator,
        expected: GameResourceDownloadState,
    ) {
        val deadline = System.currentTimeMillis() + 5_000
        while (System.currentTimeMillis() < deadline) {
            if (coordinator.status().state == expected) return
            Thread.sleep(10)
        }
        assertEquals(expected, coordinator.status().state)
    }

    private fun official(path: String) = "https://w17k.kancolle-server.com$path"

    private data class Fixture(
        val root: File,
        val engine: GameResourceCacheEngine,
        val coordinator: GameResourceDownloadCoordinator,
    )

    companion object {
        private fun response(bytes: ByteArray) = GameResourceFetchResult(
            200,
            "OK",
            mapOf("Content-Length" to bytes.size.toString(), "Content-Type" to "image/png"),
            bytes,
        )
    }
}
