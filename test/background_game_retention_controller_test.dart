import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_toolbar_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/background_game_retention_controller.dart';

void main() {
  test('defaults enabled when no value was saved', () async {
    final controller = await BackgroundGameRetentionController.load(
      _MemoryBackgroundGameRetentionStore(),
    );

    expect(controller.enabled, isTrue);
  });

  test('restores a persisted disabled value', () async {
    final store = _MemoryBackgroundGameRetentionStore()..value = false;

    final controller = await BackgroundGameRetentionController.load(store);

    expect(controller.enabled, isFalse);
  });

  test('rolls setting back when persistence fails', () async {
    final store = _MemoryBackgroundGameRetentionStore()..failWrites = true;
    final controller = await BackgroundGameRetentionController.load(store);

    await controller.setEnabled(false);

    expect(controller.enabled, isTrue);
    expect(controller.errorMessage, isNotNull);
  });

  test(
    'retains only while enabled game is active and app is backgrounded',
    () async {
      final controller = await BackgroundGameRetentionController.load(
        _MemoryBackgroundGameRetentionStore(),
      );
      final toolbar = GameToolbarController();
      final port = _RecordingBackgroundGameRetentionPort();
      final coordinator = BackgroundGameRetentionCoordinator(
        controller: controller,
        toolbarController: toolbar,
        port: port,
      );
      await coordinator.settle();

      toolbar.onStageChanged(GameSurfaceStage.game);
      await coordinator.handleLifecycleState(AppLifecycleState.paused);
      await coordinator.settle();

      expect(port.values.last, isTrue);

      await coordinator.handleLifecycleState(AppLifecycleState.resumed);
      await coordinator.settle();

      expect(port.values.last, isFalse);
      coordinator.dispose();
      toolbar.dispose();
      controller.dispose();
    },
  );

  test('inactive does not flicker retention and detached stops it', () async {
    final controller = await BackgroundGameRetentionController.load(
      _MemoryBackgroundGameRetentionStore(),
    );
    final toolbar = GameToolbarController()
      ..onStageChanged(GameSurfaceStage.game);
    final port = _RecordingBackgroundGameRetentionPort();
    final coordinator = BackgroundGameRetentionCoordinator(
      controller: controller,
      toolbarController: toolbar,
      port: port,
    );

    await coordinator.handleLifecycleState(AppLifecycleState.paused);
    await coordinator.settle();
    final afterPause = List<bool>.of(port.values);

    await coordinator.handleLifecycleState(AppLifecycleState.inactive);
    await coordinator.settle();
    expect(port.values, afterPause);

    await coordinator.handleLifecycleState(AppLifecycleState.detached);
    await coordinator.settle();
    expect(port.values.last, isFalse);
  });

  test('leaving game or disabling setting stops retention', () async {
    final controller = await BackgroundGameRetentionController.load(
      _MemoryBackgroundGameRetentionStore(),
    );
    final toolbar = GameToolbarController()
      ..onStageChanged(GameSurfaceStage.game);
    final port = _RecordingBackgroundGameRetentionPort();
    final coordinator = BackgroundGameRetentionCoordinator(
      controller: controller,
      toolbarController: toolbar,
      port: port,
    );

    await coordinator.handleLifecycleState(AppLifecycleState.paused);
    await coordinator.settle();
    toolbar.onStageChanged(GameSurfaceStage.login);
    await coordinator.settle();
    expect(port.values.last, isFalse);

    toolbar.onStageChanged(GameSurfaceStage.game);
    await coordinator.settle();
    expect(port.values.last, isTrue);
    await controller.setEnabled(false);
    await coordinator.settle();
    expect(port.values.last, isFalse);
  });

  test('rapid transitions finish at the newest requested state', () async {
    final controller = await BackgroundGameRetentionController.load(
      _MemoryBackgroundGameRetentionStore(),
    );
    final toolbar = GameToolbarController()
      ..onStageChanged(GameSurfaceStage.game);
    final port = _RecordingBackgroundGameRetentionPort()..block = true;
    final coordinator = BackgroundGameRetentionCoordinator(
      controller: controller,
      toolbarController: toolbar,
      port: port,
    );

    await coordinator.handleLifecycleState(AppLifecycleState.paused);
    await coordinator.handleLifecycleState(AppLifecycleState.resumed);
    port.release();
    await coordinator.settle();

    expect(port.values.last, isFalse);
  });
}

final class _MemoryBackgroundGameRetentionStore
    implements BackgroundGameRetentionStore {
  bool? value;
  bool failWrites = false;

  @override
  Future<bool?> readEnabled() async => value;

  @override
  Future<void> writeEnabled(bool enabled) async {
    if (failWrites) throw StateError('write failed');
    value = enabled;
  }
}

final class _RecordingBackgroundGameRetentionPort
    implements BackgroundGameRetentionPort {
  final List<bool> values = <bool>[];
  bool block = false;
  Completer<void>? _gate;

  @override
  Future<void> setRetaining(bool retaining) async {
    values.add(retaining);
    if (block) {
      _gate ??= Completer<void>();
      await _gate!.future;
      block = false;
    }
  }

  void release() => _gate?.complete();
}
