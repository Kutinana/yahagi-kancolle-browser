import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/main.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_toolbar_display_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/game_rendering_mode.dart';

void main() {
  test('native direct mode reserves only 10px in portrait', () {
    expect(
      portraitGamePanelExtraExtent(
        displayMode: GameToolbarDisplayMode.autoHide,
        renderingMode: GameRenderingMode.nativeActivityExperimental,
      ),
      10,
    );
  });

  test('existing modes keep their portrait toolbar extent', () {
    expect(
      portraitGamePanelExtraExtent(
        displayMode: GameToolbarDisplayMode.autoHide,
        renderingMode: GameRenderingMode.standard,
      ),
      0,
    );
    expect(
      portraitGamePanelExtraExtent(
        displayMode: GameToolbarDisplayMode.persistent,
        renderingMode: GameRenderingMode.standard,
      ),
      42,
    );
  });

  test('native direct mode always uses a persistent toolbar', () {
    expect(
      shouldUsePersistentGameToolbar(
        displayMode: GameToolbarDisplayMode.autoHide,
        renderingMode: GameRenderingMode.nativeActivityExperimental,
      ),
      isTrue,
    );
  });

  test('existing modes keep the player toolbar preference', () {
    for (final mode in <GameRenderingMode>[
      GameRenderingMode.standard,
      GameRenderingMode.compatibility,
      GameRenderingMode.canvasCompatibility,
    ]) {
      expect(
        shouldUsePersistentGameToolbar(
          displayMode: GameToolbarDisplayMode.autoHide,
          renderingMode: mode,
        ),
        isFalse,
      );
      expect(
        shouldUsePersistentGameToolbar(
          displayMode: GameToolbarDisplayMode.persistent,
          renderingMode: mode,
        ),
        isTrue,
      );
    }
  });
}
