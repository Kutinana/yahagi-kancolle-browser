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
        restored.dispose()
    }

    private fun fixture(
        mode: GameResourceCacheMode = GameResourceCacheMode.LIGHT,
        maxBytes: Long = 10_000,
        stateFile: File = temporaryFolder.newFile(),
        fetcher: GameResourceFetcher = GameResourceFetcher { _, _, _ -> response(byteArrayOf(1)) },
    ): Fixture {
        val root = temporaryFolder.newFolder()
        val store = GameResourceCacheStore(root, GameResourceCacheIndex(root.resolve("index.json")), maxBytes)
        val engine = GameResourceCacheEngine(store, fetcher) { mode }
        return Fixture(engine, GameResourceDownloadCoordinator(engine, { mode }, stateFile))
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
