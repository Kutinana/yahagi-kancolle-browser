package app.yahagi.kancollebrowser.browser

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class GameFrameReloadManagerTest {
    @Test
    fun nativeWebViewLifecycleCanConfigureBridgeDirectly() {
        val bridge = FakeGameFrameReloadBridge(supported = true)
        val manager = GameFrameReloadManager(bridge)

        manager.configure()

        assertEquals(1, bridge.configureCalls)
    }

    @Test
    fun configureAttachesBridgeBeforeNavigation() {
        val bridge = FakeGameFrameReloadBridge(supported = true)
        val manager = GameFrameReloadManager(bridge)
        val result = RecordingResult()

        manager.onMethodCall(MethodCall("configure", null), result)

        assertEquals(1, bridge.configureCalls)
        assertTrue(result.completed)
        assertNull(result.successValue)
    }

    @Test
    fun reloadReturnsUnsupportedWhenFrameInjectionIsUnavailable() {
        val bridge = FakeGameFrameReloadBridge(supported = false)
        val manager = GameFrameReloadManager(bridge)
        val result = RecordingResult()

        manager.onMethodCall(MethodCall("reload", null), result)

        assertEquals("unsupported", result.successValue)
        assertEquals(0, bridge.reloadCalls)
    }

    @Test
    fun reloadForwardsBridgeResult() {
        val bridge = FakeGameFrameReloadBridge(
            supported = true,
            reloadResult = "reloaded",
        )
        val manager = GameFrameReloadManager(bridge)
        val result = RecordingResult()

        manager.onMethodCall(MethodCall("reload", null), result)

        assertEquals(1, bridge.reloadCalls)
        assertEquals("reloaded", result.successValue)
    }

    @Test
    fun unknownMethodIsNotImplemented() {
        val manager = GameFrameReloadManager(
            FakeGameFrameReloadBridge(supported = true),
        )
        val result = RecordingResult()

        manager.onMethodCall(MethodCall("unknown", null), result)

        assertTrue(result.notImplemented)
        assertFalse(result.completed)
    }
}

private class FakeGameFrameReloadBridge(
    private val supported: Boolean,
    private val reloadResult: String = "blocked",
) : GameFrameReloadBridgePort {
    var configureCalls = 0
    var reloadCalls = 0

    override fun isSupported(): Boolean = supported

    override fun configure() {
        configureCalls += 1
    }

    override fun reload(onComplete: (String) -> Unit) {
        reloadCalls += 1
        onComplete(reloadResult)
    }

    override fun dispose() = Unit
}

private class RecordingResult : MethodChannel.Result {
    var completed = false
    var successValue: Any? = null
    var notImplemented = false

    override fun success(result: Any?) {
        completed = true
        successValue = result
    }

    override fun error(
        errorCode: String,
        errorMessage: String?,
        errorDetails: Any?,
    ) {
        throw AssertionError("Unexpected error: $errorCode $errorMessage")
    }

    override fun notImplemented() {
        notImplemented = true
    }
}
