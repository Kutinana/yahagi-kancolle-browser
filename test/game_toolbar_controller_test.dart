import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_toolbar_controller.dart';

void main() {
  test('starts expanded and hides after five seconds of inactivity', () {
    fakeAsync((async) {
      final controller = GameToolbarController(
        autoHideDuration: const Duration(seconds: 5),
        initiallyVisible: true,
      );

      expect(controller.stage, GameSurfaceStage.localPrototype);
      expect(controller.isVisible, isTrue);

      async.elapse(const Duration(seconds: 4));
      expect(controller.isVisible, isTrue);

      async.elapse(const Duration(seconds: 1));
      expect(controller.isVisible, isFalse);
      controller.dispose();
    });
  });

  test('records stage without forcing visibility changes', () {
    fakeAsync((async) {
      final controller = GameToolbarController(
        autoHideDuration: const Duration(seconds: 5),
      );

      expect(controller.isVisible, isFalse);
      controller.onStageChanged(GameSurfaceStage.login);
      expect(controller.stage, GameSurfaceStage.login);
      expect(controller.isVisible, isFalse);

      controller.toggle();
      expect(controller.isVisible, isTrue);

      controller.onStageChanged(GameSurfaceStage.game);
      expect(controller.stage, GameSurfaceStage.game);
      expect(controller.isVisible, isTrue);

      async.elapse(const Duration(seconds: 5));
      expect(controller.isVisible, isFalse);
      controller.dispose();
    });
  });

  test('interaction pauses and restarts the auto-hide countdown', () {
    fakeAsync((async) {
      final controller = GameToolbarController(
        autoHideDuration: const Duration(seconds: 5),
        initiallyVisible: true,
      );

      async.elapse(const Duration(seconds: 4));
      controller.beginInteraction();
      async.elapse(const Duration(seconds: 10));
      expect(controller.isVisible, isTrue);

      controller.endInteraction();
      async.elapse(const Duration(seconds: 4));
      expect(controller.isVisible, isTrue);

      async.elapse(const Duration(seconds: 1));
      expect(controller.isVisible, isFalse);
      controller.dispose();
    });
  });

  test('revealing and collapsing control visibility immediately', () {
    fakeAsync((async) {
      final controller = GameToolbarController(
        autoHideDuration: const Duration(seconds: 5),
      );

      controller.collapse();
      expect(controller.isVisible, isFalse);

      controller.reveal();
      expect(controller.isVisible, isTrue);

      async.elapse(const Duration(seconds: 5));
      expect(controller.isVisible, isFalse);
      controller.dispose();
    });
  });

  test('toggle switches between expanded and collapsed with auto-hide timer', () {
    fakeAsync((async) {
      final controller = GameToolbarController(
        autoHideDuration: const Duration(seconds: 5),
      );
      controller.collapse();
      expect(controller.isVisible, isFalse);

      controller.toggle();
      expect(controller.isVisible, isTrue);

      async.elapse(const Duration(seconds: 3));
      controller.resetAutoHide();
      async.elapse(const Duration(seconds: 3));
      expect(controller.isVisible, isTrue);

      async.elapse(const Duration(seconds: 2));
      expect(controller.isVisible, isFalse);

      controller.toggle();
      expect(controller.isVisible, isTrue);

      controller.toggle();
      expect(controller.isVisible, isFalse);
      controller.dispose();
    });
  });
}
