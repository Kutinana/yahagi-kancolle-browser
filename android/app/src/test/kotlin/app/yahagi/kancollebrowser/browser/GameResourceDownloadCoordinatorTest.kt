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
    fun `mode change stops exposing the previous manifest totals`() {
        val url = official("/kcs2/resources/a.png")
        val fixture = fixture(fetcher = GameResourceFetcher { _, _, _ -> response(byteArrayOf(1)) })
        fixture.engine.fetch(url)
        fixture.coordinator.setManifest("light", listOf(url), 580_000_000)
        assertEquals(580_000_000, fixture.coordinator.status().targetBytes)

        assertTrue(
            fixture.coordinator.configureModeChange(
                profile = "full",
                isDisabled = false,
            ) { true },
        )

        val pendingFull = fixture.coordinator.status()
        assertEquals(0, pendingFull.targetBytes)
        assertEquals(0, pendingFull.cachedBytes)
        assertEquals(0, pendingFull.missingCount)
        assertTrue(fixture.engine.hasCached(url))
        fixture.coordinator.dispose()
    }

    @Test
    fun `same mode configuration keeps the restored manifest totals`() {
        val fixture = fixture()
        fixture.coordinator.setManifest(
            "light",
            listOf(official("/kcs2/resources/a.png")),
            580_000_000,
        )

        assertTrue(
            fixture.coordinator.configureModeChange(
                profile = "light",
                isDisabled = false,
            ) { true },
        )

        assertEquals(580_000_000, fixture.coordinator.status().targetBytes)
        assertEquals(1, fixture.coordinator.status().missingCount)
        fixture.coordinator.dispose()
    }

    @Test
    fun `mode change does not revive an old backup manifest after restart`() {
        val stateFile = temporaryFolder.newFile("mode-change-state.json")
        val fixture = fixture(stateFile = stateFile)
        val url = official("/kcs2/resources/a.png")
        fixture.engine.fetch(url)
        fixture.coordinator.setManifest("full", listOf(url), 5_800_000_000)
        fixture.coordinator.setManifest("light", listOf(url), 580_000_000)
        assertTrue(
            fixture.coordinator.configureModeChange(
                profile = "full",
                isDisabled = false,
            ) { true },
        )
        fixture.coordinator.dispose()

        val restored = GameResourceDownloadCoordinator(
            fixture.engine,
            { GameResourceCacheMode.FULL },
            stateFile,
        )

        assertEquals(0, restored.status().targetBytes)
        assertEquals(0, restored.status().cachedBytes)
        assertTrue(fixture.engine.hasCached(url))
        restored.dispose()
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
    fun `clear cancellation prevents an in flight response from being stored`() {
        val started = CountDownLatch(1)
        val release = CountDownLatch(1)
        val url = official("/kcs2/resources/in-flight.png")
        val fixture = fixture(fetcher = GameResourceFetcher { _, _, _ ->
            started.countDown()
            release.await(5, TimeUnit.SECONDS)
            response(byteArrayOf(1))
        })
        fixture.coordinator.setManifest("light", listOf(url), 1)
        fixture.coordinator.startDownload()
        assertTrue(started.await(5, TimeUnit.SECONDS))

        fixture.coordinator.cancelDownload()
        fixture.engine.clear()
        release.countDown()
        awaitState(fixture.coordinator, GameResourceDownloadState.PAUSED)

        assertFalse(fixture.engine.hasCached(url))
        fixture.coordinator.dispose()
    }

    @Test
    fun `full mode uses lru eviction and continues downloading`() {
        val fixture = fixture(
            mode = GameResourceCacheMode.FULL,
            maxBytes = 3,
            fetcher = GameResourceFetcher { _, _, _ -> response(byteArrayOf(1, 2)) },
        )
        val old = official("/kcs2/resources/old.png")
        val url = official("/kcs2/resources/a.png")
        fixture.engine.fetch(old)
        fixture.coordinator.setManifest("full", listOf(url), 2)

        assertTrue(fixture.coordinator.startDownload())
        awaitState(fixture.coordinator, GameResourceDownloadState.COMPLETE)
        assertFalse(fixture.engine.hasCached(old))
        assertTrue(fixture.engine.hasCached(url))
        assertFalse(fixture.coordinator.status().capacityBlocked)
        fixture.coordinator.dispose()
    }

    @Test
    fun `missing resource is skipped silently while later resources download`() {
        val missing = official("/kcs2/resources/missing.png")
        val available = official("/kcs2/resources/available.png")
        val fixture = fixture(fetcher = GameResourceFetcher { url, _, _ ->
            if (url == missing) {
                GameResourceFetchResult(404, "Not Found", emptyMap(), byteArrayOf())
            } else {
                response(byteArrayOf(1))
            }
        })
        fixture.coordinator.setManifest("full", listOf(missing, available), 2)

        assertTrue(fixture.coordinator.startDownload())
        awaitState(fixture.coordinator, GameResourceDownloadState.IDLE)

        assertEquals(1, fixture.coordinator.status().missingCount)
        assertTrue(fixture.engine.hasCached(available))
        fixture.coordinator.dispose()
    }

    @Test
    fun `baseline expected length mismatch stays missing without stopping queue`() {
        val mismatch = official("/kcs2/resources/mismatch.png")
        val available = official("/kcs2/resources/available.png")
        val fixture = fixture(fetcher = GameResourceFetcher { _, _, _ -> response(byteArrayOf(1)) })
        fixture.coordinator.setManifest(
            "full",
            listOf(mismatch, available),
            3,
            expectedLengths = listOf(2, 1),
        )

        assertTrue(fixture.coordinator.startDownload())
        awaitState(fixture.coordinator, GameResourceDownloadState.IDLE)

        assertEquals(1, fixture.coordinator.status().missingCount)
        assertTrue(fixture.engine.hasCached(available))
        fixture.coordinator.dispose()
    }

    @Test
    fun `new expected length marks existing cache outdated and replaces it`() {
        val url = official("/kcs2/resources/changed.png")
        val responses = ArrayDeque(
            listOf(response(byteArrayOf(1)), response(byteArrayOf(2, 3))),
        )
        val fixture = fixture(fetcher = GameResourceFetcher { _, _, _ -> responses.removeFirst() })
        fixture.engine.fetch(url, expectedLength = 1)

        fixture.coordinator.setManifest("full", listOf(url), 2, expectedLengths = listOf(2))
        assertEquals(1, fixture.coordinator.status().outdatedCount)
        assertTrue(fixture.coordinator.startDownload())
        awaitState(fixture.coordinator, GameResourceDownloadState.COMPLETE)

        assertEquals(2, fixture.coordinator.status().cachedBytes)
        assertEquals(0, fixture.coordinator.status().outdatedCount)
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
    fun `manifest urls are not rewritten with frequently updated state`() {
        val stateFile = temporaryFolder.newFile("download-state.json")
        val fixture = fixture(stateFile = stateFile)
        val url = official("/kcs2/resources/large-manifest-entry.png")

        fixture.coordinator.setManifest("full", listOf(url), 9)

        assertFalse(stateFile.readText().contains(url))
        fixture.coordinator.dispose()
        val restored = GameResourceDownloadCoordinator(
            fixture.engine,
            { GameResourceCacheMode.FULL },
            stateFile,
        )
        assertEquals(1, restored.status().missingCount)
        assertEquals(9, restored.status().targetBytes)
        assertTrue(restored.startDownload())
        awaitState(restored, GameResourceDownloadState.COMPLETE)
        restored.dispose()
    }

    @Test
    fun `first status after restart restores cached bytes from manifest snapshot`() {
        val stateFile = temporaryFolder.newFile("download-state.json")
        val fixture = fixture(stateFile = stateFile)
        val url = official("/kcs2/resources/cached.png")
        fixture.engine.fetch(url)
        fixture.coordinator.setManifest("light", listOf(url), 1)
        fixture.coordinator.dispose()

        val restored = GameResourceDownloadCoordinator(
            fixture.engine,
            { GameResourceCacheMode.LIGHT },
            stateFile,
        )

        assertEquals(1, restored.status().cachedBytes)
        assertEquals(0, restored.status().missingCount)
        restored.dispose()
    }

    @Test
    fun `restart status uses persisted snapshot until explicit integrity check`() {
        val stateFile = temporaryFolder.newFile("download-state.json")
        val fixture = fixture(stateFile = stateFile)
        val url = official("/kcs2/resources/cached.png")
        fixture.engine.fetch(url)
        fixture.coordinator.setManifest("light", listOf(url), 1)
        val entry = fixture.engine.entries().single()
        fixture.coordinator.dispose()
        fixture.root.resolve("files/${entry.fileName}").delete()

        val restored = GameResourceDownloadCoordinator(
            fixture.engine,
            { GameResourceCacheMode.LIGHT },
            stateFile,
        )

        assertEquals(1, restored.status().cachedBytes)
        assertEquals(0, restored.status().missingCount)
        val checked = restored.checkIntegrity()
        assertEquals(0, checked.cachedBytes)
        assertEquals(1, checked.damagedCount)
        restored.dispose()
    }

    @Test
    fun `authorized download resumes after restart when wifi returns`() {
        val stateFile = temporaryFolder.newFile("download-state.json")
        var network = GameResourceNetworkState(connected = true, metered = true)
        val fixture = fixture(stateFile = stateFile, networkProvider = { network })
        fixture.coordinator.setManifest(
            "light",
            listOf(official("/kcs2/resources/resume.png")),
            1,
        )
        assertFalse(fixture.coordinator.startDownload())
        fixture.coordinator.dispose()

        network = GameResourceNetworkState(connected = true, metered = false)
        val restored = GameResourceDownloadCoordinator(
            fixture.engine,
            { GameResourceCacheMode.LIGHT },
            stateFile,
            { network },
        )
        restored.onNetworkChanged()

        awaitState(restored, GameResourceDownloadState.COMPLETE)
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
        fixture.root.resolve("files/${entry.fileName}").writeBytes(byteArrayOf(9))
        fixture.coordinator.setManifest("light", listOf(url), 1)

        assertEquals(0, fixture.coordinator.status().damagedCount)

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
        assertFalse(fixture.engine.hasCached(oldFirst))
        assertTrue(visited.contains(current))
        fixture.coordinator.dispose()
    }

    @Test
    fun `superseded prepared manifest is rolled back`() {
        val stateFile = temporaryFolder.newFile("download-state.json")
        val fixture = fixture(stateFile = stateFile)
        val original = official("/kcs2/resources/original.png")
        val stale = official("/kcs2/resources/stale.png")
        fixture.coordinator.setManifest("light", listOf(original), 1)
        val prepared = fixture.coordinator.prepareManifest("full", listOf(stale), 9)
        val checks = AtomicInteger()

        val applied = fixture.coordinator.applyPreparedManifestIf(prepared) {
            checks.incrementAndGet() == 1
        }
        fixture.coordinator.discardPreparedManifest(prepared)

        assertFalse(applied)
        assertEquals(1, fixture.coordinator.status().targetBytes)
        fixture.coordinator.dispose()
        val restored = GameResourceDownloadCoordinator(
            fixture.engine,
            { GameResourceCacheMode.LIGHT },
            stateFile,
        )
        assertEquals(1, restored.status().targetBytes)
        assertEquals(1, restored.status().missingCount)
        restored.dispose()
    }

    @Test
    fun `network callback after dispose is ignored`() {
        val fixture = fixture()
        fixture.coordinator.dispose()

        fixture.coordinator.onNetworkChanged()

        assertFalse(fixture.coordinator.startDownload())
    }

    @Test
    fun `superseded mode configuration has no side effects`() {
        val fixture = fixture()
        fixture.coordinator.setManifest(
            "light",
            listOf(official("/kcs2/resources/current.png")),
            1,
        )

        assertFalse(
            fixture.coordinator.configureModeChange(
                profile = "none",
                isDisabled = true,
            ) { false },
        )

        assertEquals(GameResourceDownloadState.IDLE, fixture.coordinator.status().state)
        assertTrue(fixture.coordinator.startDownload())
        awaitState(fixture.coordinator, GameResourceDownloadState.COMPLETE)
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
