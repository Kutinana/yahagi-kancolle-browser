const String gamePageAlignmentScript = r'''
(() => {
  const styleId = '__yahagi_mobile_fixed_canvas__';
  const fixedCanvasCss = `
    html, body {
      margin: 0 !important;
      padding: 0 !important;
      min-width: 1200px !important;
      min-height: 720px !important;
      overflow: hidden !important;
      overscroll-behavior: none !important;
      touch-action: none !important;
    }

    #w,
    #main-ntg {
      position: fixed !important;
      inset: 0 !important;
      z-index: 2147483640 !important;
      width: 1200px !important;
      height: 720px !important;
      margin: 0 !important;
      padding: 0 !important;
    }

    #game_frame,
    #game-container {
      display: block !important;
      width: 1200px !important;
      height: 720px !important;
      position: fixed !important;
      top: 0 !important;
      left: 0 !important;
      z-index: 2147483641 !important;
      margin: 0 !important;
      padding: 0 !important;
      border: 0 !important;
      transform: none !important;
      transform-origin: 0 0 !important;
      overscroll-behavior: none !important;
      touch-action: none !important;
    }

    .naviapp,
    #ntg-recommend,
    #spacing_top,
    aside,
    footer,
    ul:has([aria-label="close"]) {
      display: none !important;
    }
  `;

  const cleanupGamePresentation = () => {
    document.getElementById(styleId)?.remove();

    if (window.__yahagiMobileScrollLock) {
      window.removeEventListener('scroll', window.__yahagiMobileScrollLock);
    }
    if (window.__yahagiMobileAlignGame) {
      window.removeEventListener('load', window.__yahagiMobileAlignGame);
    }

    document.getElementById('game_frame')?.removeAttribute('scrolling');
    delete window.__yahagiMobileScrollLock;
    delete window.__yahagiMobileAlignGame;
  };

  const isGamePage =
    location.pathname.includes('kancolle') ||
    location.pathname.includes('854854') ||
    location.hostname === 'osapi.dmm.com' ||
    location.pathname.includes('/kcs');
  const isAccountPage =
    location.hostname === 'accounts.dmm.com' ||
    location.hostname === 'accounts.dmm.co.jp';

  const hasAuthenticationControls = () =>
    Boolean(
      document.querySelector(
        'input[type="password"], form[action*="/login"]',
      ),
    ) ||
    Array.from(document.links).some((link) => {
      const href = link.href.toLowerCase();
      return href.includes('/login') || href.includes('accounts.dmm.');
    });

  const notifyPresentationState = (hasGameSurface) => {
    const nextState = hasGameSurface ? 'game' : 'web';
    if (window.__yahagiMobilePresentationState === nextState) return;
    window.__yahagiMobilePresentationState = nextState;
    if (window.YahagiPresentation) {
      window.YahagiPresentation.postMessage(nextState);
    }
  };

  const applyGamePresentation = () => {
    let style = document.getElementById(styleId);
    if (!style) {
      style = document.createElement('style');
      style.id = styleId;
      document.head.appendChild(style);
    }
    if (style.textContent !== fixedCanvasCss) {
      style.textContent = fixedCanvasCss;
    }

    window.__yahagiMobileAlignGame = () => {
      window.scrollTo(0, 0);
      document.documentElement.scrollTop = 0;
      document.body.scrollTop = 0;

      const gameFrame = document.getElementById('game_frame');
      if (gameFrame) {
        gameFrame.setAttribute('scrolling', 'no');
        try {
          gameFrame.contentWindow?.scrollTo(0, 0);
        } catch (_) {
          // A cross-origin game frame is still locked by touch-action above.
        }
      }
    };

    if (window.__yahagiMobileScrollLock) {
      window.removeEventListener('scroll', window.__yahagiMobileScrollLock);
    }
    window.__yahagiMobileScrollLock = () => {
      window.__yahagiMobileAlignGame();
    };
    window.addEventListener('scroll', window.__yahagiMobileScrollLock, {
      passive: true,
    });

    if (document.readyState === 'complete') {
      window.__yahagiMobileAlignGame();
    } else {
      window.addEventListener('load', window.__yahagiMobileAlignGame);
    }
  };

  window.__yahagiMobileSyncPresentation = () => {
    const hasGameSurface = Boolean(
      document.querySelector('#game_frame, #game-container'),
    );
    const shouldUseGamePresentation =
      isGamePage &&
      !isAccountPage &&
      hasGameSurface &&
      !hasAuthenticationControls();

    if (shouldUseGamePresentation) {
      applyGamePresentation();
    } else {
      cleanupGamePresentation();
    }
    notifyPresentationState(shouldUseGamePresentation);
    return shouldUseGamePresentation;
  };

  window.__yahagiMobilePresentationObserver?.disconnect();
  if (isGamePage && !isAccountPage) {
    window.__yahagiMobilePresentationObserver = new MutationObserver(() => {
      window.__yahagiMobileSyncPresentation();
    });
    window.__yahagiMobilePresentationObserver.observe(document.documentElement, {
      childList: true,
      subtree: true,
    });
  }

  return window.__yahagiMobileSyncPresentation();
})();
''';
