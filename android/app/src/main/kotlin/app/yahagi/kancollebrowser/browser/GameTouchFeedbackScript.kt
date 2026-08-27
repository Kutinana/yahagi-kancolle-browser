package app.yahagi.kancollebrowser.browser

import app.yahagi.kancollebrowser.capture.CaptureOriginPolicy

internal data class GameDocumentStartScript(
    val source: String,
    val allowedOriginRules: Set<String>,
)

/** Removes Chromium's native press highlight without consuming game input. */
internal object GameTouchFeedbackScript {
    val allowedOriginRules: Set<String> = setOf("https://*.kancolle-server.com")

    val source: String =
        """
        (() => {
          'use strict';
          if (window.__yahagiTapHighlightDisabled) return;
          window.__yahagiTapHighlightDisabled = true;

          const apply = () => {
            const root = document.documentElement;
            if (!root) return false;
            root.style.setProperty(
              '-webkit-tap-highlight-color',
              'transparent',
              'important'
            );
            return true;
          };

          if (!apply()) {
            const observer = new MutationObserver(() => {
              if (!apply()) return;
              observer.disconnect();
            });
            observer.observe(document, {childList: true});
          }
        })();
        """.trimIndent()
}

/** Scripts installed by the standard, compatibility, and Canvas Platform Views. */
internal fun platformGameDocumentStartScripts(
    reloadOriginRules: Set<String> = CaptureOriginPolicy().allowedOriginRules,
): List<GameDocumentStartScript> =
    listOf(
        GameDocumentStartScript(
            source = GameFrameReloadBridgeScript.source,
            allowedOriginRules = reloadOriginRules,
        ),
        GameDocumentStartScript(
            source = GameTouchFeedbackScript.source,
            allowedOriginRules = GameTouchFeedbackScript.allowedOriginRules,
        ),
    )
