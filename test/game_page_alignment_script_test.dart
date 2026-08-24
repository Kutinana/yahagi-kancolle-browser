import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_page_alignment_script.dart';

void main() {
  test('alignment pins the 1200 by 720 game frame without touching data', () {
    expect(
      gamePageAlignmentScript,
      contains("location.pathname.includes('kancolle')"),
    );
    expect(gamePageAlignmentScript, contains('854854'));
    expect(gamePageAlignmentScript, contains('osapi.dmm.com'));
    expect(gamePageAlignmentScript, contains('/kcs'));
    expect(gamePageAlignmentScript, contains('#game_frame'));
    expect(gamePageAlignmentScript, contains('width: 1200px !important'));
    expect(gamePageAlignmentScript, contains('height: 720px !important'));
    expect(gamePageAlignmentScript, contains('position: fixed !important'));
    expect(gamePageAlignmentScript, isNot(contains('document.cookie')));
    expect(gamePageAlignmentScript, isNot(contains('XMLHttpRequest')));
    expect(gamePageAlignmentScript, isNot(contains('fetch(')));
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

  test('alignment requires a real game surface and rejects login forms', () {
    expect(gamePageAlignmentScript, contains('accounts.dmm.com'));
    expect(gamePageAlignmentScript, contains('isGamePage'));
    expect(gamePageAlignmentScript, contains('hasGameSurface'));
    expect(gamePageAlignmentScript, contains("input[type=\"password\"]"));
    expect(gamePageAlignmentScript, contains('document.links'));
    expect(gamePageAlignmentScript, contains("href.includes('/login')"));
    expect(
      gamePageAlignmentScript,
      contains('return shouldUseGamePresentation'),
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

  test('alignment yields to an open DMM purchase dialog', () {
    expect(gamePageAlignmentScript, contains("dialog[open]"));
    expect(gamePageAlignmentScript, contains('hasBlockingPageDialog'));
    expect(gamePageAlignmentScript, contains('!hasBlockingPageDialog()'));
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
    expect(gamePageAlignmentScript, contains("'game' : 'web'"));
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
