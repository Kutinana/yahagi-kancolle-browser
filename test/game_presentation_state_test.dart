import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_presentation_state.dart';

void main() {
  test('decodes game web and pending presentation states', () {
    expect(decodeGamePresentationState(true), GamePresentationState.game);
    expect(decodeGamePresentationState(false), GamePresentationState.web);
    expect(decodeGamePresentationState('game'), GamePresentationState.game);
    expect(decodeGamePresentationState('"game"'), GamePresentationState.game);
    expect(decodeGamePresentationState('web'), GamePresentationState.web);
    expect(
      decodeGamePresentationState('pending'),
      GamePresentationState.pending,
    );
  });

  test('unknown results remain non-actionable', () {
    expect(decodeGamePresentationState(null), isNull);
    expect(decodeGamePresentationState(1), isNull);
    expect(decodeGamePresentationState('unknown'), isNull);
  });

  test('pending never binds or releases fixed canvas', () {
    expect(
      GamePresentationState.pending.platformAction,
      GamePresentationPlatformAction.none,
    );
    expect(
      GamePresentationState.game.platformAction,
      GamePresentationPlatformAction.bind,
    );
    expect(
      GamePresentationState.web.platformAction,
      GamePresentationPlatformAction.release,
    );
  });
}
