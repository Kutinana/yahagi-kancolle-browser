import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_page_alignment_script.dart';

void main() {
  test('alignment pins the 1200 by 720 game frame without touching data', () {
    expect(
      gamePageAlignmentScript,
      contains('/netgame/social/-/gadgets/=/app_id=854854/'),
    );
    expect(gamePageAlignmentScript, contains("host === 'osapi.dmm.com'"));
    expect(
      gamePageAlignmentScript,
      contains("host.endsWith('.kancolle-server.com')"),
    );
    expect(
      gamePageAlignmentScript,
      isNot(contains("pathname.includes('kancolle')")),
    );
    expect(gamePageAlignmentScript, contains('#game_frame'));
    expect(gamePageAlignmentScript, contains('width: 1200px !important'));
    expect(gamePageAlignmentScript, contains('height: 720px !important'));
    expect(gamePageAlignmentScript, contains('position: fixed !important'));
    expect(gamePageAlignmentScript, isNot(contains('document.cookie')));
    expect(gamePageAlignmentScript, isNot(contains('XMLHttpRequest')));
    expect(gamePageAlignmentScript, isNot(contains('fetch(')));
  });

  test('alignment recognizes the current DMM play URL exactly', () {
    expect(gamePageAlignmentScript, contains("host === 'play.games.dmm.com'"));
    expect(gamePageAlignmentScript, contains("pathname === '/game/kancolle'"));
    expect(gamePageAlignmentScript, contains("pathname === '/game/kancolle/'"));
    expect(
      gamePageAlignmentScript,
      isNot(contains("pathname.includes('/game/kancolle')")),
    );
    expect(
      gamePageAlignmentScript,
      isNot(
        contains(
          "pathname.includes('/netgame/social/-/gadgets/=/app_id=854854/')",
        ),
      ),
    );
  });

  test('alignment hides the DMM page shell around the game viewport', () {
    expect(gamePageAlignmentScript, contains('#spacing_top'));
    expect(gamePageAlignmentScript, contains('#ntg-recommend'));
    expect(gamePageAlignmentScript, contains('.naviapp'));
    expect(gamePageAlignmentScript, contains('aside'));
    expect(gamePageAlignmentScript, contains('footer'));
    expect(gamePageAlignmentScript, contains('inset: 0 !important'));
    expect(gamePageAlignmentScript, contains('overflow: hidden !important'));
    expect(
      gamePageAlignmentScript,
      contains('transform-origin: 0 0 !important'),
    );
  });

  test('normal DMM account links cannot disable the game presentation', () {
    expect(gamePageAlignmentScript, contains('accounts.dmm.com'));
    expect(gamePageAlignmentScript, contains('isGamePage'));
    expect(gamePageAlignmentScript, contains('hasGameSurface'));
    expect(gamePageAlignmentScript, isNot(contains('document.links')));
    expect(gamePageAlignmentScript, isNot(contains("href.includes('/login')")));
  });

  test('game candidates remain pending until a visible surface exists', () {
    expect(gamePageAlignmentScript, contains("return 'pending'"));
    expect(gamePageAlignmentScript, contains('getBoundingClientRect()'));
    expect(gamePageAlignmentScript, contains('element.isConnected'));
    expect(
      gamePageAlignmentScript,
      contains("notifyPresentationState('pending')"),
    );
  });

  test('alignment recognizes the standalone HTML5 game canvas', () {
    expect(
      gamePageAlignmentScript,
      contains("document.querySelectorAll('canvas')"),
    );
    expect(gamePageAlignmentScript, contains('canvas.width === 1200'));
    expect(gamePageAlignmentScript, contains('canvas.height === 720'));
  });

  test('OOI mode 1 keeps its outer frame while fitting the visible game', () {
    expect(
      gamePageAlignmentScript,
      contains("location.hostname === 'ooi.moe'"),
    );
    expect(
      gamePageAlignmentScript,
      contains("location.pathname === '/kancolle'"),
    );
    expect(gamePageAlignmentScript, contains("iframe#externalswf"));
    expect(gamePageAlignmentScript, contains('ooiBrowserFrameWidth = 1280'));
    expect(gamePageAlignmentScript, contains('ooiBrowserFrameHeight = 800'));
    expect(gamePageAlignmentScript, contains('ooiBrowserGameWidth = 1200'));
    expect(gamePageAlignmentScript, contains('ooiBrowserGameHeight = 720'));
    expect(
      gamePageAlignmentScript,
      contains('viewportWidth / ooiBrowserGameWidth'),
    );
    expect(
      gamePageAlignmentScript,
      contains('viewportHeight / ooiBrowserGameHeight'),
    );
  });

  test('OOI mode 1 isolates the game after login from native fixed canvas', () {
    expect(gamePageAlignmentScript, contains('applyOoiBrowserPresentation'));
    expect(gamePageAlignmentScript, contains('cleanupOoiBrowserPresentation'));
    expect(gamePageAlignmentScript, contains('#ooi-header'));
    expect(gamePageAlignmentScript, contains('#ooi-footer'));
    expect(
      gamePageAlignmentScript,
      contains('#ooi-game > :not(iframe#externalswf)'),
    );
    expect(
      gamePageAlignmentScript,
      contains("style.setProperty('--yahagi-ooi-scale'"),
    );
    expect(
      gamePageAlignmentScript,
      contains("style.setProperty('--yahagi-ooi-left'"),
    );
    expect(
      gamePageAlignmentScript,
      contains("window.addEventListener('resize'"),
    );
    expect(gamePageAlignmentScript, contains("notifyPresentationState('web')"));
  });

  test('alignment yields to an open DMM purchase dialog', () {
    expect(gamePageAlignmentScript, contains("dialog[open]"));
    expect(gamePageAlignmentScript, contains('hasBlockingPageDialog'));
    expect(
      gamePageAlignmentScript,
      contains('isAccountPage || hasBlockingPageDialog()'),
    );
  });

  test('alignment removes every game-only lock outside the game surface', () {
    expect(
      gamePageAlignmentScript,
      contains("getElementById(styleId)?.remove()"),
    );
    expect(
      gamePageAlignmentScript,
      contains(
        "removeEventListener('scroll', window.__yahagiMobileScrollLock)",
      ),
    );
    expect(gamePageAlignmentScript, contains("removeAttribute('scrolling')"));
    expect(gamePageAlignmentScript, contains('cleanupGamePresentation()'));
  });

  test('alignment exposes a manual align hook on window', () {
    expect(gamePageAlignmentScript, contains('window.__yahagiMobileAlignGame'));
    expect(gamePageAlignmentScript, contains('window.scrollTo(0, 0)'));
  });

  test('alignment resynchronizes when the game iframe appears later', () {
    expect(
      gamePageAlignmentScript,
      contains('window.__yahagiMobileSyncPresentation'),
    );
    expect(gamePageAlignmentScript, contains('new MutationObserver'));
    expect(gamePageAlignmentScript, contains('YahagiPresentation.postMessage'));
    expect(
      gamePageAlignmentScript,
      contains("notifyPresentationState('game')"),
    );
    expect(gamePageAlignmentScript, contains("notifyPresentationState('web')"));
  });

  test(
    'alignment prevents touch panning from exposing content below the game',
    () {
      expect(
        gamePageAlignmentScript,
        contains('touch-action: none !important'),
      );
      expect(
        gamePageAlignmentScript,
        contains('overscroll-behavior: none !important'),
      );
      expect(
        gamePageAlignmentScript,
        contains("window.addEventListener('scroll'"),
      );
      expect(
        gamePageAlignmentScript,
        contains("setAttribute('scrolling', 'no')"),
      );
    },
  );
}
