import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_frame_reload_script.dart';

void main() {
  test('matches POI game_frame to htmlWrap reload semantics', () {
    expect(gameFrameReloadScript, contains("getElementById('game_frame')"));
    expect(gameFrameReloadScript, contains("getElementById('htmlWrap')"));
    expect(
      gameFrameReloadScript,
      contains('game.contentWindow.location.reload()'),
    );
    expect(gameFrameReloadScript, isNot(contains('window.location.reload()')));
  });

  test('returns bounded statuses and retries through the iframe source', () {
    for (final status in <String>[
      'reloaded',
      'game_frame_not_found',
      'html_wrap_not_found',
      'blocked',
    ]) {
      expect(gameFrameReloadScript, contains("'$status'"));
    }
    expect(gameFrameReloadScript, contains("game.setAttribute('src', source)"));
  });
}
