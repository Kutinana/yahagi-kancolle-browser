package app.yahagi.kancollebrowser.browser

import java.util.UUID

internal object GameFrameReloadBridgeScript {
    const val objectName = "YahagiGameFrameReload"

    val source: String =
        """
        (() => {
          'use strict';
          if (window.__yahagiGameFrameReloadInstalled) return;
          const bridge = window.YahagiGameFrameReload;
          if (!bridge || typeof bridge.postMessage !== 'function') return;
          window.__yahagiGameFrameReloadInstalled = true;

          const post = (payload) => bridge.postMessage(JSON.stringify(payload));
          const reportTarget = () => post({
            kind: 'target',
            available: document.getElementById('htmlWrap') !== null,
          });

          bridge.onmessage = (event) => {
            let data;
            try {
              data = typeof event.data === 'string'
                ? JSON.parse(event.data)
                : event.data;
            } catch (_) {
              return;
            }
            if (!data || data.kind !== 'reload' || typeof data.requestId !== 'string') {
              return;
            }
            const game = document.getElementById('htmlWrap');
            if (!game) return;

            let result = 'reloaded';
            try {
              game.contentWindow.location.reload();
            } catch (_) {
              const source = game.getAttribute('src');
              if (!source) {
                result = 'blocked';
              } else {
                game.setAttribute('src', source);
              }
            }
            post({kind: 'result', requestId: data.requestId, result: result});
          };

          if (document.readyState === 'loading') {
            document.addEventListener('DOMContentLoaded', reportTarget, {once: true});
          } else {
            reportTarget();
          }
        })();
        """.trimIndent()
}

internal class GameFrameReloadRequestCoordinator(
    private val requestIdFactory: () -> String = { UUID.randomUUID().toString() },
) {
    private var pending: PendingRequest? = null

    fun start(onComplete: (String) -> Unit): String {
        val requestId = requestIdFactory()
        pending = PendingRequest(requestId, onComplete)
        return requestId
    }

    fun complete(requestId: String, result: String): Boolean {
        val active = pending ?: return false
        if (active.requestId != requestId) return false
        pending = null
        active.onComplete(result)
        return true
    }

    fun cancel(result: String): Boolean {
        val active = pending ?: return false
        pending = null
        active.onComplete(result)
        return true
    }

    private data class PendingRequest(
        val requestId: String,
        val onComplete: (String) -> Unit,
    )
}
