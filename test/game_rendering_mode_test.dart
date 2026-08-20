import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/settings/game_rendering_mode.dart';

void main() {
  test('standard mode keeps the texture WebGL path without blur', () {
    const mode = GameRenderingMode.standard;

    expect(mode.usesActivityWebView, isFalse);
    expect(mode.usesPlatformView, isTrue);
    expect(mode.usesHybridComposition, isFalse);
    expect(mode.usesCanvasRenderer, isFalse);
    expect(mode.enablesToolbarBlur, isFalse);
  });

  test('compatibility mode uses hybrid WebGL without toolbar blur', () {
    const mode = GameRenderingMode.compatibility;

    expect(mode.usesActivityWebView, isFalse);
    expect(mode.usesPlatformView, isTrue);
    expect(mode.usesHybridComposition, isTrue);
    expect(mode.usesCanvasRenderer, isFalse);
    expect(mode.enablesToolbarBlur, isFalse);
  });

  test('canvas compatibility mode uses hybrid Canvas without blur', () {
    const mode = GameRenderingMode.canvasCompatibility;

    expect(mode.usesActivityWebView, isFalse);
    expect(mode.usesPlatformView, isTrue);
    expect(mode.usesHybridComposition, isTrue);
    expect(mode.usesCanvasRenderer, isTrue);
    expect(mode.enablesToolbarBlur, isFalse);
  });

  test('native activity experimental mode bypasses platform views', () {
    const mode = GameRenderingMode.nativeActivityExperimental;

    expect(mode.usesActivityWebView, isTrue);
    expect(mode.usesPlatformView, isFalse);
    expect(mode.usesHybridComposition, isFalse);
    expect(mode.usesCanvasRenderer, isFalse);
    expect(mode.enablesToolbarBlur, isFalse);
    expect(GameRenderingModeCodec.decode(mode.storageName), mode);
  });

  test(
    'stored names round-trip and invalid values fall back to nativeActivityExperimental',
    () {
      for (final mode in GameRenderingMode.values) {
        expect(GameRenderingModeCodec.decode(mode.storageName), mode);
      }

      expect(
        GameRenderingModeCodec.decode(null),
        GameRenderingMode.nativeActivityExperimental,
      );
      expect(
        GameRenderingModeCodec.decode('broken'),
        GameRenderingMode.nativeActivityExperimental,
      );
    },
  );
}
