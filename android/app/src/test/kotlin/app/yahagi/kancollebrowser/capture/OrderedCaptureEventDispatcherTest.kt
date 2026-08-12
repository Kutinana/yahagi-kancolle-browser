package app.yahagi.kancollebrowser.capture

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.nio.ByteBuffer
import java.util.ArrayDeque
import java.util.concurrent.Executor

class OrderedCaptureEventDispatcherTest {
    @Test
    fun preservesValidationAndDeliveryOrderAcrossBothProtocols() {
        val worker = QueuedExecutor()
        val main = QueuedExecutor()
        val delivered = mutableListOf<Map<String, Any?>>()
        val dispatcher = OrderedCaptureEventDispatcher(
            validator = CaptureMessageValidator(clock = { "now" }),
            worker = worker,
            postToMain = main::execute,
            deliver = delivered::add,
        )

        dispatcher.submit(validStringMessage("/kcsapi/api_port/port"), "https://game")
        dispatcher.submit(validBinaryMessage("/kcsapi/api_req_hensei/change"), "https://game")
        worker.runAll()

        assertTrue(delivered.isEmpty())
        main.runAll()
        assertEquals(
            listOf(
                "/kcsapi/api_port/port",
                "/kcsapi/api_req_hensei/change",
            ),
            delivered.map { it["path"] },
        )
        assertEquals(listOf(1L, 2L), delivered.map { it["sequence"] })
        assertTrue(delivered.first().containsKey("responseBody"))
        assertTrue(delivered.last().containsKey("responseBodyBytes"))
    }

    @Test
    fun invalidationDropsQueuedAndAlreadyPostedEvents() {
        val worker = QueuedExecutor()
        val main = QueuedExecutor()
        val delivered = mutableListOf<Map<String, Any?>>()
        val dispatcher = OrderedCaptureEventDispatcher(
            validator = CaptureMessageValidator(),
            worker = worker,
            postToMain = main::execute,
            deliver = delivered::add,
        )

        dispatcher.submit(validStringMessage("/kcsapi/api_port/port"), "https://game")
        worker.runAll()
        dispatcher.invalidatePending()
        main.runAll()

        dispatcher.submit(validStringMessage("/kcsapi/api_get_member/basic"), "https://game")
        dispatcher.invalidatePending()
        worker.runAll()
        main.runAll()

        assertTrue(delivered.isEmpty())
    }

    private fun validStringMessage(path: String): String =
        """
        {
          "version": 1,
          "kind": "kcsapi_response",
          "method": "POST",
          "path": "$path",
          "requestParams": {},
          "responseBody": "svdata={\"api_result\":1}",
          "statusCode": 200,
          "transport": "xhr"
        }
        """.trimIndent()

    private fun validBinaryMessage(path: String): ByteArray {
        val metadata =
            """
            {
              "version": 1,
              "kind": "kcsapi_response",
              "method": "POST",
              "path": "$path",
              "requestParams": {},
              "statusCode": 200,
              "transport": "fetch"
            }
            """.trimIndent().toByteArray(Charsets.UTF_8)
        val responseBody = "svdata={\"api_result\":1}".toByteArray(Charsets.UTF_8)
        return ByteBuffer.allocate(4 + metadata.size + responseBody.size)
            .putInt(metadata.size)
            .put(metadata)
            .put(responseBody)
            .array()
    }
}

private class QueuedExecutor : Executor {
    private val tasks = ArrayDeque<Runnable>()

    override fun execute(command: Runnable) {
        tasks.addLast(command)
    }

    fun runAll() {
        while (tasks.isNotEmpty()) tasks.removeFirst().run()
    }
}
