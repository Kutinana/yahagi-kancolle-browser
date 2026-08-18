package app.yahagi.kancollebrowser.nativewebview

import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class NativeGameWebViewChannelTest {
    @Test
    fun channelNamesExactlyMatchDartContract() {
        assertEquals(
            "app.yahagi.kancollebrowser/native_game_webview",
            NativeGameWebViewChannel.METHOD_CHANNEL_NAME,
        )
        assertEquals(
            "app.yahagi.kancollebrowser/native_game_webview_events",
            NativeGameWebViewChannel.EVENT_CHANNEL_NAME,
        )
    }

    @Test
    fun createRequiresExactRendererSchemaAndRunsOnMainDispatcher() {
        val host = FakeHost()
        val queued = mutableListOf<() -> Unit>()
        val channel = activeChannel(host, dispatchToMain = queued::add)
        val valid = RecordingResult()

        channel.onMethodCall(MethodCall("create", mapOf("renderer" to "webgl")), valid)

        assertEquals(1, queued.size)
        assertEquals(0, host.createCalls)
        assertNull(valid.successValue)
        queued.removeAt(0).invoke()
        assertEquals(0L, valid.successValue)
        assertEquals(1, host.createCalls)

        listOf(
            null,
            emptyMap<String, Any?>(),
            mapOf("renderer" to "canvas"),
            mapOf("renderer" to "webgl", "extra" to true),
            mapOf(1 to "webgl"),
        ).forEach { arguments ->
            val invalid = RecordingResult()
            channel.onMethodCall(MethodCall("create", arguments), invalid)
            assertEquals("invalid_argument", invalid.errorCode)
            assertTrue(queued.isEmpty())
        }
    }

    @Test
    fun currentDartCommandsUseStrictArgumentsAndRejectStaleGeneration() {
        val host = FakeHost()
        val channel = activeChannel(host)
        assertSuccess(channel, "create", mapOf("renderer" to "webgl"), 0L)

        assertSuccess(
            channel,
            "setBounds",
            mapOf(
                "generationId" to 0,
                "bounds" to mapOf(
                    "left" to -1.5,
                    "top" to 2.0,
                    "width" to 1200.0,
                    "height" to 720.0,
                    "devicePixelRatio" to 2.5,
                ),
            ),
            null,
        )
        assertEquals(NativeGameWebViewBounds(-1.5, 2.0, 1200.0, 720.0, 2.5), host.bounds)
        assertSuccess(channel, "setVisible", mapOf("generationId" to 0, "visible" to true), null)
        assertSuccess(channel, "loadUri", mapOf("generationId" to 0, "uri" to "https://example.com/game"), null)
        assertSuccess(channel, "showLocalHome", generation(0), null)
        assertSuccess(channel, "reload", generation(0), null)
        assertSuccess(channel, "canGoBack", generation(0), true)
        assertSuccess(channel, "goBack", generation(0), null)
        assertSuccess(channel, "runJavaScript", mapOf("generationId" to 0, "javascript" to "1 + 1"), null)
        assertSuccess(channel, "fitGameScreen", generation(0), null)
        assertSuccess(channel, "clearCache", generation(0), null)
        assertSuccess(channel, "clearSession", generation(0), null)

        val invalidCases = listOf(
            "setBounds" to mapOf("generationId" to 0, "bounds" to mapOf("left" to 0.0)),
            "setBounds" to mapOf(
                "generationId" to 0,
                "bounds" to mapOf(
                    "left" to 0,
                    "top" to 0.0,
                    "width" to 1.0,
                    "height" to 1.0,
                    "devicePixelRatio" to 1.0,
                ),
            ),
            "setVisible" to mapOf("generationId" to 0, "visible" to 1),
            "loadUri" to mapOf("generationId" to 0, "uri" to "javascript:alert(1)"),
            "reload" to mapOf("generationId" to 0, "extra" to true),
            "runJavaScript" to mapOf("generationId" to 0, "javascript" to 1),
            "goBack" to mapOf("generationId" to 0.0),
        )
        invalidCases.forEach { (method, arguments) ->
            assertError(channel, method, arguments, "invalid_argument")
        }

        assertError(channel, "reload", generation(99), "stale_generation")
        assertError(channel, "destroy", generation(99), "stale_generation")
    }

    @Test
    fun currentGenerationLayoutRejectionReturnsHostErrorRatherThanStale() {
        val host = FakeHost().apply {
            setBoundsResult = false
            setVisibleResult = false
        }
        val channel = activeChannel(host)
        assertSuccess(channel, "create", mapOf("renderer" to "webgl"), 0L)

        assertError(
            channel,
            "setBounds",
            mapOf(
                "generationId" to 0,
                "bounds" to mapOf(
                    "left" to 0.0,
                    "top" to 0.0,
                    "width" to 1.0,
                    "height" to 1.0,
                    "devicePixelRatio" to 1.0,
                ),
            ),
            "native_webview_error",
        )
        assertError(
            channel,
            "setVisible",
            mapOf("generationId" to 0, "visible" to true),
            "native_webview_error",
        )
    }

    @Test
    fun everyMethodValidatesItsCompleteSchemaBeforeCheckingGeneration() {
        val channel = activeChannel(FakeHost())
        assertSuccess(channel, "create", mapOf("renderer" to "webgl"), 0L)
        val invalidAndStale = listOf(
            "setBounds" to mapOf("generationId" to 99, "bounds" to emptyMap<String, Any?>()),
            "setVisible" to mapOf("generationId" to 99, "visible" to 1),
            "loadUri" to mapOf("generationId" to 99, "uri" to "javascript:alert(1)"),
            "showLocalHome" to mapOf("generationId" to 99, "extra" to true),
            "reload" to mapOf("generationId" to 99, "extra" to true),
            "canGoBack" to mapOf("generationId" to 99, "extra" to true),
            "goBack" to mapOf("generationId" to 99, "extra" to true),
            "runJavaScript" to mapOf("generationId" to 99, "javascript" to 1),
            "fitGameScreen" to mapOf("generationId" to 99, "extra" to true),
            "clearCache" to mapOf("generationId" to 99, "extra" to true),
            "clearSession" to mapOf("generationId" to 99, "extra" to true),
            "destroy" to mapOf("generationId" to 99, "extra" to true),
        )

        invalidAndStale.forEach { (method, arguments) ->
            assertError(channel, method, arguments, "invalid_argument")
        }
    }

    @Test
    fun cachedEngineBrokerKeepsOriginalSinkForDestroyedAndExplicitRecreateAfterRebind() {
        val registry = NativeGameWebViewChannelRegistry<Any>()
        val engine = Any()
        var registrations = 0
        val channel = registry.acquire(engine) { registrations++ }
        val events = RecordingEventSink()
        channel.onListen(null, events)
        lateinit var firstHost: FakeHost
        firstHost = FakeHost { type, generation ->
            when (type) {
                "created" -> channel.created(generation)
                "destroyed" -> channel.destroyed(generation)
            }
        }
        val firstDispatches = mutableListOf<() -> Unit>()
        val firstAttachment = channel.attachActivity(firstDispatches::add)
        channel.attachHost(firstAttachment, firstHost)
        val firstCreate = RecordingResult()
        channel.onMethodCall(MethodCall("create", mapOf("renderer" to "webgl")), firstCreate)
        firstDispatches.removeAt(0).invoke()
        assertEquals(0L, firstCreate.successValue)

        channel.detachActivity(firstAttachment)
        assertEquals(listOf("create:0", "destroy:0"), firstHost.operations)
        assertEquals(mapOf("type" to "destroyed", "generationId" to 0L), events.values.last())

        val rebound = registry.acquire(engine) { registrations++ }
        assertTrue(channel === rebound)
        lateinit var secondHost: FakeHost
        secondHost = FakeHost { type, generation ->
            when (type) {
                "created" -> channel.created(generation)
                "destroyed" -> channel.destroyed(generation)
            }
        }
        val secondDispatches = mutableListOf<() -> Unit>()
        val secondAttachment = rebound.attachActivity(secondDispatches::add)
        rebound.attachHost(secondAttachment, secondHost)
        val secondCreate = RecordingResult()
        rebound.onMethodCall(MethodCall("create", mapOf("renderer" to "webgl")), secondCreate)
        secondDispatches.removeAt(0).invoke()

        assertEquals(1, registrations)
        assertEquals(0L, secondCreate.successValue)
        assertEquals(
            listOf(
                mapOf("type" to "created", "generationId" to 0L),
                mapOf("type" to "destroyed", "generationId" to 0L),
                mapOf("type" to "created", "generationId" to 0L),
            ),
            events.values,
        )
    }

    @Test
    fun destroyedEngineUnregistersAndEndsStreamWhileCachedEngineRemainsRegistered() {
        val registry = NativeGameWebViewChannelRegistry<Any>()
        val cachedEngine = Any()
        val destroyedEngine = Any()
        var registrations = 0
        val cached = registry.acquire(cachedEngine) { registrations++ }
        val destroyed = registry.acquire(destroyedEngine) { registrations++ }
        val sink = RecordingEventSink()
        destroyed.onListen(null, sink)

        assertTrue(registry.peek(cachedEngine) === cached)
        val removed = registry.remove(destroyedEngine)
        removed?.shutdownEngine()

        assertNull(registry.peek(destroyedEngine))
        assertTrue(registry.peek(cachedEngine) === cached)
        assertEquals(2, registrations)
        assertEquals(1, sink.endCalls)
    }

    @Test
    fun clearSessionSerializesLaterCommandsAndIgnoresDuplicateOrDetachedCallback() {
        val host = FakeHost().apply { autoCompleteClearSession = false }
        val channel = activeChannel(host)
        assertSuccess(channel, "create", mapOf("renderer" to "webgl"), 0L)
        val clear = RecordingResult()
        val load = RecordingResult()
        channel.onMethodCall(MethodCall("clearSession", generation(0)), clear)
        channel.onMethodCall(
            MethodCall("loadUri", mapOf("generationId" to 0, "uri" to "https://example.com/game")),
            load,
        )

        assertEquals(1, host.clearSessionCalls)
        assertEquals(0, host.loadUriCalls)
        assertEquals(0, clear.completionCount)
        host.completeClearSession(null)
        assertEquals(1, clear.completionCount)
        assertEquals(1, host.loadUriCalls)
        assertEquals(1, load.completionCount)
        host.completeClearSession(IllegalStateException("duplicate"))
        assertEquals(1, clear.completionCount)

        val detachedHost = FakeHost().apply { autoCompleteClearSession = false }
        val detachedChannel = NativeGameWebViewChannel()
        val attachment = detachedChannel.attachActivity(dispatchToMain = { it() })
        detachedChannel.attachHost(attachment, detachedHost)
        assertSuccess(detachedChannel, "create", mapOf("renderer" to "webgl"), 0L)
        val abandoned = RecordingResult()
        detachedChannel.onMethodCall(MethodCall("clearSession", generation(0)), abandoned)
        detachedChannel.disable()
        detachedHost.completeClearSession(null)
        assertEquals(0, abandoned.completionCount)
    }

    @Test
    fun clearSessionCallbackFailureCompletesOnceWithFixedHostError() {
        val host = FakeHost().apply { autoCompleteClearSession = false }
        val channel = activeChannel(host)
        assertSuccess(channel, "create", mapOf("renderer" to "webgl"), 0L)
        val result = RecordingResult()

        channel.onMethodCall(MethodCall("clearSession", generation(0)), result)
        host.completeClearSession(IllegalStateException("cookie failure"))

        assertEquals("native_webview_error", result.errorCode)
        assertEquals(1, result.completionCount)
    }

    @Test
    fun unknownMethodIsNotImplemented() {
        val result = RecordingResult()

        activeChannel(FakeHost()).onMethodCall(MethodCall("futureTask8Command", emptyMap<String, Any?>()), result)

        assertTrue(result.notImplemented)
    }

    @Test
    fun repeatedCreateDeterministicallyDestroysOldGenerationBeforeCreatingNewOne() {
        lateinit var channel: NativeGameWebViewChannel
        val host = FakeHost { type, generation ->
            when (type) {
                "created" -> channel.created(generation)
                "destroyed" -> channel.destroyed(generation)
            }
        }
        channel = activeChannel(host)
        val events = RecordingEventSink()
        channel.onListen(null, events)

        assertSuccess(channel, "create", mapOf("renderer" to "webgl"), 0L)
        assertSuccess(channel, "create", mapOf("renderer" to "webgl"), 1L)

        assertEquals(listOf("create:0", "destroy:0", "create:1"), host.operations)
        assertEquals(
            listOf(
                mapOf("type" to "created", "generationId" to 0L),
                mapOf("type" to "destroyed", "generationId" to 0L),
                mapOf("type" to "created", "generationId" to 1L),
            ),
            events.values,
        )
    }

    @Test
    fun eventsUseExactMapsAndLateOrCancelledEventsAreSilent() {
        val host = FakeHost()
        val channel = activeChannel(host)
        val events = RecordingEventSink()
        channel.onListen(null, events)
        assertSuccess(channel, "create", mapOf("renderer" to "webgl"), 0L)

        channel.created(0)
        channel.pageStarted(0, "https://example.com/start")
        channel.pageFinished(0, "https://example.com/finish")
        channel.mainFrameError(0, -2, "network")
        channel.navigationBlocked(0, "intent")
        channel.renderProcessGone(0, true)
        channel.destroyed(0)
        channel.pageFinished(0, "https://example.com/late")

        assertEquals(
            listOf(
                mapOf("type" to "created", "generationId" to 0L),
                mapOf("type" to "pageStarted", "generationId" to 0L, "url" to "https://example.com/start"),
                mapOf("type" to "pageFinished", "generationId" to 0L, "url" to "https://example.com/finish"),
                mapOf("type" to "mainFrameError", "generationId" to 0L, "errorCode" to -2, "description" to "network"),
                mapOf("type" to "navigationBlocked", "generationId" to 0L, "scheme" to "intent"),
                mapOf("type" to "renderProcessGone", "generationId" to 0L, "didCrash" to true),
                mapOf("type" to "destroyed", "generationId" to 0L),
            ),
            events.values,
        )

        channel.onCancel(null)
        channel.created(1)
        assertEquals(7, events.values.size)
    }

    @Test
    fun eventSinkFailuresAreIsolatedAndDisableMakesMethodsAndEventsSilent() {
        val host = FakeHost()
        val channel = activeChannel(host)
        channel.onListen(null, ThrowingEventSink())
        assertSuccess(channel, "create", mapOf("renderer" to "webgl"), 0L)

        channel.created(0)
        channel.disable()
        channel.destroyed(0)
        val result = RecordingResult()
        channel.onMethodCall(MethodCall("reload", generation(0)), result)

        assertEquals("activity_destroyed", result.errorCode)
        assertEquals(0, host.reloadCalls)
    }

    @Test
    fun task8DeferredHomeAndFitCommandsAreOnlyRoutedPlaceholders() {
        val host = FakeHost()
        val channel = activeChannel(host)
        assertSuccess(channel, "create", mapOf("renderer" to "webgl"), 0L)

        assertSuccess(channel, "showLocalHome", generation(0), null)
        assertSuccess(channel, "fitGameScreen", generation(0), null)

        assertEquals(1, host.showLocalHomeCalls)
        assertEquals(1, host.fitGameScreenCalls)
    }

    @Test
    fun sharedPreferencesStoreReadsOneSnapshotAndCommitsWholeSnapshotOnce() {
        val preferences = FakeSnapshotPreferences(
            mutableMapOf(
                NativeWebViewStartupGuard.CONSECUTIVE_FAILURES_KEY to 1,
                NativeWebViewStartupGuard.LAST_STARTUP_STARTED_AT_MS_KEY to 10L,
                NativeWebViewStartupGuard.ATTEMPT_SESSION_ID_KEY to "session-a",
                NativeWebViewStartupGuard.RENDERING_MODE_KEY to "nativeActivityExperimental",
            ),
        )
        val processState = NativeWebViewStartupStoreProcessState()
        val store = SharedPreferencesNativeWebViewStartupStore(preferences, processState)

        assertEquals(
            NativeWebViewStartupReadResult.Success(
                NativeWebViewStartupSnapshot(1, 10L, NativeWebViewProcessSessionId("session-a"), "nativeActivityExperimental"),
            ),
            store.read(),
        )
        assertEquals(1, preferences.readCalls)

        val next = NativeWebViewStartupSnapshot(2, null, null, "compatibility")
        assertEquals(NativeWebViewStartupWriteResult.Durable, store.write(next))
        assertEquals(1, preferences.editCalls)
        assertEquals(1, preferences.commitCalls)
        assertEquals(2, preferences.values[NativeWebViewStartupGuard.CONSECUTIVE_FAILURES_KEY])
        assertFalse(preferences.values.containsKey(NativeWebViewStartupGuard.LAST_STARTUP_STARTED_AT_MS_KEY))
        assertFalse(preferences.values.containsKey(NativeWebViewStartupGuard.ATTEMPT_SESSION_ID_KEY))
        assertEquals("compatibility", preferences.values[NativeWebViewStartupGuard.RENDERING_MODE_KEY])
    }

    @Test
    fun failedCommitPoisonsEveryNewAdapterInSameProcessButNotNewProcess() {
        val preferences = FakeSnapshotPreferences(commitResult = false)
        val sameProcess = NativeWebViewStartupStoreProcessState()
        val first = SharedPreferencesNativeWebViewStartupStore(preferences, sameProcess)

        assertEquals(
            NativeWebViewStartupWriteResult.Indeterminate,
            first.write(NativeWebViewStartupSnapshot(1, 0, NativeWebViewProcessSessionId("a"), "nativeActivityExperimental")),
        )
        assertEquals(
            NativeWebViewStartupReadResult.Unavailable,
            SharedPreferencesNativeWebViewStartupStore(preferences, sameProcess).read(),
        )
        assertEquals(0, preferences.readCalls)

        preferences.commitResult = true
        assertTrue(
            SharedPreferencesNativeWebViewStartupStore(
                preferences,
                NativeWebViewStartupStoreProcessState(),
            ).read() is NativeWebViewStartupReadResult.Success,
        )
        assertEquals(1, preferences.readCalls)
    }

    @Test
    fun persistenceExceptionsFailClosedWithoutSwallowingFatalThrowables() {
        val readException = FakeSnapshotPreferences(readFailure = IllegalStateException("read"))
        assertEquals(
            NativeWebViewStartupReadResult.Unavailable,
            SharedPreferencesNativeWebViewStartupStore(readException, NativeWebViewStartupStoreProcessState()).read(),
        )

        val writeException = FakeSnapshotPreferences(commitFailure = IllegalStateException("commit"))
        val state = NativeWebViewStartupStoreProcessState()
        val store = SharedPreferencesNativeWebViewStartupStore(writeException, state)
        assertEquals(
            NativeWebViewStartupWriteResult.Indeterminate,
            store.write(NativeWebViewStartupSnapshot(0, null, null, null)),
        )
        assertEquals(NativeWebViewStartupReadResult.Unavailable, store.read())

        assertThrows<AssertionError> {
            SharedPreferencesNativeWebViewStartupStore(
                FakeSnapshotPreferences(readFailure = AssertionError("fatal")),
                NativeWebViewStartupStoreProcessState(),
            ).read()
        }
    }

    @Test
    fun persistedFallbackIsVisibleAndCompatibilityNeverStarts() {
        val preferences = FakeSnapshotPreferences(
            mutableMapOf(
                NativeWebViewStartupGuard.CONSECUTIVE_FAILURES_KEY to 1,
                NativeWebViewStartupGuard.LAST_STARTUP_STARTED_AT_MS_KEY to 0L,
                NativeWebViewStartupGuard.ATTEMPT_SESSION_ID_KEY to "old",
                NativeWebViewStartupGuard.RENDERING_MODE_KEY to "nativeActivityExperimental",
            ),
        )
        val state = NativeWebViewStartupStoreProcessState()
        val store = SharedPreferencesNativeWebViewStartupStore(preferences, state)

        assertEquals(
            NativeWebViewStartupDecision.FallbackTriggered,
            NativeWebViewStartupGuard(store, NativeWebViewProcessSessionId("new")).beginAttempt(1),
        )
        assertEquals("compatibility", preferences.values[NativeWebViewStartupGuard.RENDERING_MODE_KEY])
        assertEquals(
            NativeWebViewStartupDecision.FallbackActive,
            NativeWebViewStartupGuard(
                SharedPreferencesNativeWebViewStartupStore(preferences, state),
                NativeWebViewProcessSessionId("newer"),
            ).beginAttempt(2),
        )
    }

    @Test
    fun processSessionProviderReusesIdAcrossActivityRecreationAndChangesAcrossProcesses() {
        var sequence = 0
        val activityProcess = NativeWebViewProcessSessionIdProvider {
            NativeWebViewProcessSessionId("process-${sequence++}")
        }

        val firstActivity = activityProcess.current()
        val recreatedActivity = activityProcess.current()
        val restartedProcess = NativeWebViewProcessSessionIdProvider {
            NativeWebViewProcessSessionId("process-${sequence++}")
        }.current()

        assertEquals(firstActivity, recreatedActivity)
        assertEquals("process-0", firstActivity.value)
        assertEquals("process-1", restartedProcess.value)
    }

    @Test
    fun activityStartupCoordinatorGatesExactModeAndRestartsOnceAfterDurableFallback() {
        val compatibilityStore = CountingStore(
            NativeWebViewStartupSnapshot(0, null, null, "compatibility"),
        )
        val compatibility = NativeWebViewActivityStartupCoordinator(
            guard = NativeWebViewStartupGuard(compatibilityStore, NativeWebViewProcessSessionId("a")),
            nowMs = { 1L },
            scheduleTimeout = { _, _ -> },
            cancelTimeout = {},
            requestRestart = {},
        )
        assertFalse(compatibility.begin("compatibility"))
        assertEquals(0, compatibilityStore.reads)

        val fallbackStore = CountingStore(
            NativeWebViewStartupSnapshot(
                1,
                0L,
                NativeWebViewProcessSessionId("old"),
                "nativeActivityExperimental",
            ),
        )
        var restarts = 0
        var durableModeWhenRestarted: String? = null
        val fallback = NativeWebViewActivityStartupCoordinator(
            guard = NativeWebViewStartupGuard(fallbackStore, NativeWebViewProcessSessionId("new")),
            nowMs = { 1L },
            scheduleTimeout = { _, _ -> },
            cancelTimeout = {},
            requestRestart = {
                restarts++
                durableModeWhenRestarted = fallbackStore.snapshot.storedRenderingMode
            },
        )

        assertFalse(fallback.begin("nativeActivityExperimental"))
        assertFalse(fallback.begin("nativeActivityExperimental"))
        assertEquals(1, restarts)
        assertEquals("compatibility", durableModeWhenRestarted)
    }

    @Test
    fun activityStartupCoordinatorSchedulesTimeoutAndClearsItAtReady() {
        val store = CountingStore(
            NativeWebViewStartupSnapshot(0, null, null, "nativeActivityExperimental"),
        )
        var scheduledDelay: Long? = null
        var timeout: (() -> Unit)? = null
        var cancellations = 0
        val coordinator = NativeWebViewActivityStartupCoordinator(
            guard = NativeWebViewStartupGuard(store, NativeWebViewProcessSessionId("process")),
            nowMs = { 100L },
            scheduleTimeout = { delay, callback ->
                scheduledDelay = delay
                timeout = callback
            },
            cancelTimeout = { cancellations++ },
            requestRestart = {},
        )

        assertTrue(coordinator.begin("nativeActivityExperimental"))
        assertEquals(NativeWebViewStartupGuard.STARTUP_TIMEOUT_MS, scheduledDelay)
        coordinator.onPageFinished()
        assertEquals(1, cancellations)
        assertEquals(0, store.snapshot.consecutiveFailures)
        assertNull(store.snapshot.attemptStartedAtMs)

        timeout?.invoke()
        assertNull(store.snapshot.attemptStartedAtMs)
    }

    private fun activeChannel(
        host: NativeGameWebViewHostOperations,
        dispatchToMain: ((() -> Unit) -> Unit) = { it() },
    ): NativeGameWebViewChannel {
        val channel = NativeGameWebViewChannel()
        val attachment = channel.attachActivity(dispatchToMain)
        channel.attachHost(attachment, host)
        return channel
    }

    private fun generation(value: Int) = mapOf<String, Any?>("generationId" to value)

    private fun assertSuccess(
        channel: NativeGameWebViewChannel,
        method: String,
        arguments: Any?,
        expected: Any?,
    ) {
        val result = RecordingResult()
        channel.onMethodCall(MethodCall(method, arguments), result)
        assertEquals(1, result.completionCount)
        assertEquals(expected, result.successValue)
        assertNull(result.errorCode)
        assertFalse(result.notImplemented)
    }

    private fun assertError(
        channel: NativeGameWebViewChannel,
        method: String,
        arguments: Any?,
        code: String,
    ) {
        val result = RecordingResult()
        channel.onMethodCall(MethodCall(method, arguments), result)
        assertEquals(1, result.completionCount)
        assertEquals(code, result.errorCode)
    }

    private inline fun <reified T : Throwable> assertThrows(block: () -> Unit) {
        try {
            block()
        } catch (throwable: Throwable) {
            if (throwable is T) return
            throw AssertionError("Expected ${T::class.java.name}, got ${throwable::class.java.name}", throwable)
        }
        throw AssertionError("Expected ${T::class.java.name}")
    }

    private class RecordingResult : MethodChannel.Result {
        var successValue: Any? = null
        var errorCode: String? = null
        var notImplemented = false
        var completionCount = 0

        override fun success(result: Any?) {
            completionCount++
            successValue = result
        }

        override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
            completionCount++
            this.errorCode = errorCode
        }

        override fun notImplemented() {
            completionCount++
            notImplemented = true
        }
    }

    private class RecordingEventSink : EventChannel.EventSink {
        val values = mutableListOf<Any?>()
        var endCalls = 0

        override fun success(event: Any?) {
            values += event
        }

        override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) = Unit

        override fun endOfStream() {
            endCalls++
        }
    }

    private class ThrowingEventSink : EventChannel.EventSink {
        override fun success(event: Any?) {
            throw IllegalStateException("closed")
        }

        override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) = Unit

        override fun endOfStream() = Unit
    }

    private class FakeHost(
        private val event: (String, Long) -> Unit = { _, _ -> },
    ) : NativeGameWebViewHostOperations {
        override var currentGeneration: Long? = null
            private set
        var createCalls = 0
        var reloadCalls = 0
        var loadUriCalls = 0
        var showLocalHomeCalls = 0
        var fitGameScreenCalls = 0
        var clearSessionCalls = 0
        var autoCompleteClearSession = true
        private var clearSessionCallback: ((Exception?) -> Unit)? = null
        var bounds: NativeGameWebViewBounds? = null
        var setBoundsResult = true
        var setVisibleResult = true
        val operations = mutableListOf<String>()

        override fun create(): Long? {
            val generation = createCalls.toLong()
            createCalls++
            currentGeneration = generation
            operations += "create:$generation"
            event("created", generation)
            return generation
        }

        override fun setBounds(generation: Long, bounds: NativeGameWebViewBounds): Boolean {
            if (generation != currentGeneration) return false
            this.bounds = bounds
            return setBoundsResult
        }

        override fun setVisible(generation: Long, visible: Boolean) =
            generation == currentGeneration && setVisibleResult

        override fun loadUri(uri: String) {
            loadUriCalls++
        }

        override fun showLocalHome() {
            showLocalHomeCalls++
        }

        override fun reload() {
            reloadCalls++
        }

        override fun canGoBack() = true

        override fun goBack() = Unit

        override fun runJavaScript(javascript: String) = Unit

        override fun fitGameScreen() {
            fitGameScreenCalls++
        }

        override fun clearCache() = Unit

        override fun clearSession(onComplete: (Exception?) -> Unit) {
            clearSessionCalls++
            clearSessionCallback = onComplete
            if (autoCompleteClearSession) completeClearSession(null)
        }

        fun completeClearSession(error: Exception?) {
            clearSessionCallback?.invoke(error)
        }

        override fun destroy(generation: Long): Boolean {
            if (generation != currentGeneration) return false
            operations += "destroy:$generation"
            currentGeneration = null
            event("destroyed", generation)
            return true
        }
    }

    private class FakeSnapshotPreferences(
        val values: MutableMap<String, Any?> = mutableMapOf(),
        var commitResult: Boolean = true,
        private val readFailure: Throwable? = null,
        private val commitFailure: Throwable? = null,
    ) : NativeWebViewSnapshotPreferences {
        var readCalls = 0
        var editCalls = 0
        var commitCalls = 0

        override fun readAll(): Map<String, Any?> {
            readCalls++
            readFailure?.let { throw it }
            return values.toMap()
        }

        override fun edit(): NativeWebViewSnapshotEditor {
            editCalls++
            val pending = values.toMutableMap()
            return object : NativeWebViewSnapshotEditor {
                override fun putInt(key: String, value: Int) = apply { pending[key] = value }

                override fun putLong(key: String, value: Long) = apply { pending[key] = value }

                override fun putString(key: String, value: String) = apply { pending[key] = value }

                override fun remove(key: String) = apply { pending.remove(key) }

                override fun commit(): Boolean {
                    commitCalls++
                    commitFailure?.let { throw it }
                    if (commitResult) {
                        values.clear()
                        values.putAll(pending)
                    }
                    return commitResult
                }
            }
        }
    }

    private class CountingStore(
        var snapshot: NativeWebViewStartupSnapshot,
    ) : NativeWebViewStartupStore {
        var reads = 0

        override fun read(): NativeWebViewStartupReadResult {
            reads++
            return NativeWebViewStartupReadResult.Success(snapshot)
        }

        override fun write(nextSnapshot: NativeWebViewStartupSnapshot): NativeWebViewStartupWriteResult {
            snapshot = nextSnapshot
            return NativeWebViewStartupWriteResult.Durable
        }
    }
}
