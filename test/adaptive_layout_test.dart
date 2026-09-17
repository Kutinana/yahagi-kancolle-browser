import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/layout/adaptive_layout.dart';
import 'package:yahagi_kancolle_browser/src/settings/display_mode_store.dart';

void main() {
  test('screen classes share one compact, square, and wide rule', () {
    expect(
      classifyAdaptiveWindow(const Size(412, 915)),
      AdaptiveWindowClass.compact,
    );
    expect(
      classifyAdaptiveWindow(const Size(673, 841)),
      AdaptiveWindowClass.nearSquareLarge,
    );
    expect(
      classifyAdaptiveWindow(const Size(1280, 800)),
      AdaptiveWindowClass.wideLarge,
    );
  });

  test(
    'near-square displays keep the vertical workspace after a 90 degree turn',
    () {
      expect(usesVerticalWorkspace(const Size(673, 841)), isTrue);
      expect(usesVerticalWorkspace(const Size(841, 673)), isTrue);
      expect(usesVerticalWorkspace(const Size(800, 1280)), isTrue);
      expect(usesVerticalWorkspace(const Size(1280, 800)), isFalse);
    },
  );

  test(
    'forced portrait and landscape override geometry in usesVerticalWorkspace',
    () {
      // Forced portrait always uses vertical workspace (e.g. split screen wide window)
      expect(
        usesVerticalWorkspace(const Size(1280, 800), DisplayMode.portrait),
        isTrue,
      );
      expect(
        usesVerticalWorkspace(const Size(800, 1280), DisplayMode.portrait),
        isTrue,
      );

      // Forced landscape always uses horizontal workspace (e.g. split screen tall window)
      expect(
        usesVerticalWorkspace(const Size(800, 1280), DisplayMode.landscape),
        isFalse,
      );
      expect(
        usesVerticalWorkspace(const Size(673, 841), DisplayMode.landscape),
        isFalse,
      );
    },
  );
}
