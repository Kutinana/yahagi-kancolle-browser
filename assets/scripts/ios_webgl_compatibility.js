/* yahagi-ios-webgl-compatibility-v1 */
(() => {
  'use strict';
  const host = location.hostname.toLowerCase();
  if (location.protocol !== 'https:' || (location.port && location.port !== '443') ||
      !(host === 'ooi.moe' || ['dmm.com', 'dmm.co.jp', 'kancolle-server.com'].some(
        root => host === root || host.endsWith('.' + root)))) return;
  if (window.__yahagiIOSWebGLCompatibilityInstalled) return;
  window.__yahagiIOSWebGLCompatibilityInstalled = true;

  const report = state => {
    try {
      window.webkit.messageHandlers.YahagiWebViewRuntime.postMessage({state});
    } catch (_) {}
  };
  const patched = new WeakSet();
  const apply = pixi => {
    const settings = pixi && pixi.settings;
    if (!settings || patched.has(settings) ||
        typeof settings.CAN_UPLOAD_SAME_BUFFER !== 'boolean' ||
        typeof settings.PRECISION_FRAGMENT !== 'string') return;
    // Preserve Pixi's iOS buffer path even with a desktop UA/platform. Use the
    // fragment precision recommended by Pixi for Apple GPUs, before shaders exist.
    patched.add(settings);
    try {
      settings.CAN_UPLOAD_SAME_BUFFER = false;
      settings.PRECISION_FRAGMENT = 'highp';
      report('pixiIOSCompatibilityV1');
    } catch (_) {
      report('pixiCompatibilityHookUnavailable');
    }
  };

  // Pixi 4's UMD bundle assigns its complete namespace before the game creates
  // its renderer. A timer/onload hook can miss that first shader compilation.
  const descriptor = Object.getOwnPropertyDescriptor(window, 'PIXI');
  if (!descriptor || (descriptor.configurable && 'value' in descriptor && descriptor.writable)) {
    let pixi = window.PIXI;
    Object.defineProperty(window, 'PIXI', {
      configurable: true,
      enumerable: descriptor ? descriptor.enumerable : true,
      get() { apply(pixi); return pixi; },
      set(value) { pixi = value; apply(value); },
    });
    apply(pixi);
  } else {
    report('pixiCompatibilityHookUnavailable');
  }

  // These events do not bubble. Observe in the capture phase without cancelling
  // them: Pixi remains responsible for restoring its own GPU resources.
  for (const [event, state] of [
    ['webglcontextlost', 'webglContextLost'],
    ['webglcontextrestored', 'webglContextRestored'],
    ['webglcontextcreationerror', 'webglContextCreationFailed'],
  ]) {
    document.addEventListener(event, () => report(state), true);
  }
})();
