import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_toolbar_controller.dart';

void main() {
  test('starts expanded and stays visible as time passes', () {
    fakeAsync((async) {
      final controller = GameToolbarController(initiallyVisible: true);

      expect(controller.stage, GameSurfaceStage.localPrototype);
      expect(controller.isVisible, isTrue);

      async.elapse(const Duration(minutes: 1));
      expect(controller.isVisible, isTrue);
      controller.dispose();
    });
  });

  test('records stage without forcing visibility changes', () {
    fakeAsync((async) {
      final controller = GameToolbarController();

      expect(controller.isVisible, isFalse);
      controller.onStageChanged(GameSurfaceStage.login);
      expect(controller.stage, GameSurfaceStage.login);
      expect(controller.isVisible, isFalse);

      controller.toggle();
      expect(controller.isVisible, isTrue);

      controller.onStageChanged(GameSurfaceStage.game);
      expect(controller.stage, GameSurfaceStage.game);
      expect(controller.isVisible, isTrue);

      async.elapse(const Duration(minutes: 1));
      expect(controller.isVisible, isTrue);
      controller.dispose();
    });
  });

  test('notifies listeners when the game surface stage changes', () {
    final controller = GameToolbarController();
    var notifications = 0;
    controller.addListener(() => notifications++);

    controller.onStageChanged(GameSurfaceStage.game);
    controller.onStageChanged(GameSurfaceStage.game);

    expect(notifications, 1);
    expect(controller.isVisible, isFalse);
  });

  test('revealing stays visible until explicitly collapsed', () {
    fakeAsync((async) {
      final controller = GameToolbarController();

      controller.collapse();
      expect(controller.isVisible, isFalse);

      controller.reveal();
      expect(controller.isVisible, isTrue);

      async.elapse(const Duration(minutes: 1));
      expect(controller.isVisible, isTrue);

      controller.collapse();
      expect(controller.isVisible, isFalse);
      controller.dispose();
    });
  });

  test('toggle switches between expanded and collapsed manually', () {
    fakeAsync((async) {
      final controller = GameToolbarController();
      controller.collapse();
      expect(controller.isVisible, isFalse);

      controller.toggle();
      expect(controller.isVisible, isTrue);

      async.elapse(const Duration(minutes: 1));
      expect(controller.isVisible, isTrue);

      controller.toggle();
      expect(controller.isVisible, isFalse);
      controller.dispose();
    });
  });
}
