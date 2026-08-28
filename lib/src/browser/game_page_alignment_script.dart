const String gamePageAlignmentScript = r'''
(() => {
  const styleId = '__yahagi_mobile_fixed_canvas__';
  const ooiBrowserStyleId = '__yahagi_mobile_ooi_browser__';
  const ooiBrowserFrameWidth = 1280;
  const ooiBrowserFrameHeight = 800;
  const ooiBrowserGameWidth = 1200;
  const ooiBrowserGameHeight = 720;
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

  const ooiBrowserCss = `
    html,
    body,
    #ooi-page,
    #ooi-content,
    #ooi-game {
      width: 100vw !important;
      height: 100vh !important;
      min-width: 0 !important;
      min-height: 0 !important;
      margin: 0 !important;
      padding: 0 !important;
      overflow: hidden !important;
    }

    #ooi-content,
    #ooi-game {
      display: block !important;
      position: fixed !important;
      inset: 0 !important;
    }

    #ooi-header,
    #ooi-footer,
    #ooi-game > :not(iframe#externalswf) {
      display: none !important;
    }

    #ooi-game > iframe#externalswf {
      display: block !important;
      position: fixed !important;
      left: var(--yahagi-ooi-left, 0px) !important;
      top: var(--yahagi-ooi-top, 0px) !important;
      width: var(--yahagi-ooi-frame-width, 1280px) !important;
      height: var(--yahagi-ooi-frame-height, 800px) !important;
      transform: scale(var(--yahagi-ooi-scale, 1)) !important;
      transform-origin: top left !important;
      margin: 0 !important;
    }
  `;

  const cleanupOoiBrowserPresentation = () => {
    document.getElementById(ooiBrowserStyleId)?.remove();
    const game = document.getElementById('ooi-game');
    game?.style.removeProperty('--yahagi-ooi-frame-width');
    game?.style.removeProperty('--yahagi-ooi-frame-height');
    game?.style.removeProperty('--yahagi-ooi-scale');
    game?.style.removeProperty('--yahagi-ooi-left');
    game?.style.removeProperty('--yahagi-ooi-top');

    if (window.__yahagiMobileOoiResize) {
      window.removeEventListener('resize', window.__yahagiMobileOoiResize);
    }
    if (
      window.__yahagiMobileAlignGame ===
      window.__yahagiMobileOoiAlignGame
    ) {
      delete window.__yahagiMobileAlignGame;
    }
    delete window.__yahagiMobileOoiResize;
    delete window.__yahagiMobileOoiAlignGame;
  };

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

  const host = location.hostname.toLowerCase();
  const pathname = location.pathname.toLowerCase();
  const isAccountPage =
    host === 'accounts.dmm.com' || host === 'accounts.dmm.co.jp';
  const isKancolleServerPage =
    host === 'kancolle-server.com' ||
    host.endsWith('.kancolle-server.com');
  const isCurrentDmmGamePage =
    host === 'play.games.dmm.com' &&
    (pathname === '/game/kancolle' || pathname === '/game/kancolle/');
  const isLegacyDmmGamePage =
    (host === 'www.dmm.com' ||
      host === 'dmm.com' ||
      host === 'games.dmm.com') &&
    (pathname === '/netgame/social/-/gadgets/=/app_id=854854' ||
      pathname === '/netgame/social/-/gadgets/=/app_id=854854/');
  const isGamePage =
    isCurrentDmmGamePage ||
    isLegacyDmmGamePage ||
    host === 'osapi.dmm.com' ||
    isKancolleServerPage;
  const isOoiBrowserPage =
    location.hostname === 'ooi.moe' && location.pathname === '/kancolle';

  const isVisibleElement = (element) => {
    if (!element || !element.isConnected) return false;
    const style = getComputedStyle(element);
    if (
      style.display === 'none' ||
      style.visibility === 'hidden' ||
      style.visibility === 'collapse'
    ) {
      return false;
    }
    const rect = element.getBoundingClientRect();
    return rect.width > 0 && rect.height > 0;
  };

  const hasBlockingPageDialog = () =>
    Array.from(document.querySelectorAll('dialog[open]')).some(
      isVisibleElement,
    );

  const hasStandaloneGameCanvas = () =>
    Array.from(document.querySelectorAll('canvas')).some(
      (canvas) =>
        canvas.width === 1200 &&
        canvas.height === 720 &&
        isVisibleElement(canvas),
    );

  const notifyPresentationState = (nextState) => {
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

  const applyOoiBrowserPresentation = () => {
    let style = document.getElementById(ooiBrowserStyleId);
    if (!style) {
      style = document.createElement('style');
      style.id = ooiBrowserStyleId;
      document.head.appendChild(style);
    }
    if (style.textContent !== ooiBrowserCss) {
      style.textContent = ooiBrowserCss;
    }

    window.__yahagiMobileOoiAlignGame = () => {
      const game = document.getElementById('ooi-game');
      const frame = game?.querySelector('iframe#externalswf');
      if (!game || !frame) return;

      const viewportWidth = Math.max(
        1,
        window.visualViewport?.width || document.documentElement.clientWidth,
      );
      const viewportHeight = Math.max(
        1,
        window.visualViewport?.height || document.documentElement.clientHeight,
      );
      const scale = Math.min(
        1,
        viewportWidth / ooiBrowserGameWidth,
        viewportHeight / ooiBrowserGameHeight,
      );
      const left = Math.max(
        0,
        (viewportWidth - ooiBrowserGameWidth * scale) / 2,
      );
      const top = Math.max(
        0,
        (viewportHeight - ooiBrowserGameHeight * scale) / 2,
      );
      game.style.setProperty(
        '--yahagi-ooi-frame-width',
        `${ooiBrowserFrameWidth}px`,
      );
      game.style.setProperty(
        '--yahagi-ooi-frame-height',
        `${ooiBrowserFrameHeight}px`,
      );
      game.style.setProperty('--yahagi-ooi-scale', String(scale));
      game.style.setProperty('--yahagi-ooi-left', `${left}px`);
      game.style.setProperty('--yahagi-ooi-top', `${top}px`);
    };
    window.__yahagiMobileAlignGame = window.__yahagiMobileOoiAlignGame;

    if (window.__yahagiMobileOoiResize) {
      window.removeEventListener('resize', window.__yahagiMobileOoiResize);
    }
    window.__yahagiMobileOoiResize = () => {
      window.__yahagiMobileOoiAlignGame?.();
    };
    window.addEventListener('resize', window.__yahagiMobileOoiResize, {
      passive: true,
    });
    window.__yahagiMobileOoiAlignGame();
  };

  window.__yahagiMobileSyncPresentation = () => {
    const hasOoiBrowserSurface = Boolean(
      document.querySelector('#ooi-page #ooi-game > iframe#externalswf'),
    );
    if (isOoiBrowserPage && hasOoiBrowserSurface) {
      cleanupGamePresentation();
      applyOoiBrowserPresentation();
      notifyPresentationState('web');
      return 'web';
    }

    cleanupOoiBrowserPresentation();
    const hasGameSurface =
      Array.from(
        document.querySelectorAll('#game_frame, #game-container'),
      ).some(isVisibleElement) || hasStandaloneGameCanvas();

    if (!isGamePage || isAccountPage || hasBlockingPageDialog()) {
      cleanupGamePresentation();
      notifyPresentationState('web');
      return 'web';
    }
    if (!hasGameSurface) {
      notifyPresentationState('pending');
      return 'pending';
    }

    applyGamePresentation();
    notifyPresentationState('game');
    return 'game';
  };

  window.__yahagiMobilePresentationObserver?.disconnect();
  if (isGamePage && !isAccountPage) {
    window.__yahagiMobilePresentationObserver = new MutationObserver(() => {
      window.__yahagiMobileSyncPresentation();
    });
    window.__yahagiMobilePresentationObserver.observe(document.documentElement, {
      childList: true,
      subtree: true,
      attributes: true,
      attributeFilter: ['class', 'hidden', 'style', 'width', 'height'],
    });
  }

  return window.__yahagiMobileSyncPresentation();
})();
''';
