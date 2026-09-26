package app.yahagi.kancollebrowser.browser

/** Receives only physical wheel input forwarded by the Android host. */
internal object GameMouseWheelScript {
    const val objectName = "YahagiMouseWheel"
    val origins = setOf("https://*.kancolle-server.com")
    val source = """
        (() => {
          'use strict';
          const bridge = window.YahagiMouseWheel;
          if (!bridge || window.__yahagiMouseWheelInstalled) return;
          window.__yahagiMouseWheelInstalled = true;
          const token = String(Date.now()) + ':' + Math.random();
          let active = false;
          const canvas = () => {
            if (!location.pathname.startsWith('/kcs2/')) return null;
            const target = document.querySelector('canvas');
            if (!target || !target.isConnected) return null;
            const rect = target.getBoundingClientRect();
            return rect.width > 0 && rect.height > 0 ? target : null;
          };
          const report = () => {
            const available = !!canvas();
            if (active === available) return;
            active = available;
            bridge.postMessage(JSON.stringify({token, available}));
          };
          bridge.onmessage = (event) => {
            let data;
            try { data = JSON.parse(event.data); } catch (_) { return; }
            if (!data || data.token !== token || data.kind !== 'wheel' ||
                ![data.x, data.y, data.deltaX, data.deltaY].every(Number.isFinite) ||
                data.x < 0 || data.x >= 1 || data.y < 0 || data.y >= 1 ||
                data.deltaY === 0 || document.hidden) return;
            const target = canvas();
            if (!target) return;
            const rect = target.getBoundingClientRect();
            target.dispatchEvent(new WheelEvent('wheel', {
              bubbles: true, cancelable: true, view: window,
              clientX: rect.left + rect.width * data.x,
              clientY: rect.top + rect.height * data.y,
              deltaX: data.deltaX, deltaY: data.deltaY, deltaMode: 0,
            }));
          };
          const observer = new MutationObserver(report);
          observer.observe(document, {
            childList: true, subtree: true, attributes: true,
            attributeFilter: ['style', 'class', 'width', 'height'],
          });
          window.addEventListener('resize', report);
          window.addEventListener('pageshow', report);
          window.addEventListener('pagehide', () => {
            active = false;
            bridge.postMessage(JSON.stringify({token, available: false}));
          });
          report();
        })();
    """.trimIndent()
}
