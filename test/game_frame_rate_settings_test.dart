import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/src/settings/game_frame_rate_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test('a new install defaults to automatic', () async {
    final store = SharedPreferencesGameFrameRateSettingsStore();
    expect(await store.loadMode(), GameFrameRateMode.automatic);
  });

  test('migrates the old boolean preference to an enum value', () async {
    for (final entry in <bool, GameFrameRateMode>{
      true: GameFrameRateMode.highRefresh,
      false: GameFrameRateMode.stable30,
    }.entries) {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'game.unlockFrameRate': entry.key,
      });
      final store = SharedPreferencesGameFrameRateSettingsStore();

      expect(await store.loadMode(), entry.value);
      expect(
        (await SharedPreferences.getInstance()).getString(
          'game.frameRateMode.v2',
        ),
        entry.value.wireName,
      );
    }
  });

  test('migrates legacy string values', () async {
    for (final entry in <String, GameFrameRateMode>{
      'max60': GameFrameRateMode.automatic,
      'followDisplay': GameFrameRateMode.highRefresh,
      'off': GameFrameRateMode.stable30,
    }.entries) {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'game.frameRateMode': entry.key,
      });
      final store = SharedPreferencesGameFrameRateSettingsStore();
      expect(await store.loadMode(), entry.value);
    }
  });

  test('new enum values round-trip and unknown values use automatic', () async {
    final store = SharedPreferencesGameFrameRateSettingsStore();
    for (final mode in GameFrameRateMode.values) {
      await store.saveMode(mode);
      expect(await store.loadMode(), mode);
    }

    SharedPreferences.setMockInitialValues(<String, Object>{
      'game.frameRateMode.v2': 'future-mode',
    });
    expect(
      await SharedPreferencesGameFrameRateSettingsStore().loadMode(),
      GameFrameRateMode.automatic,
    );
  });

  test(
    'controller applies startup mode and live changes to the port',
    () async {
      final store = MemoryGameFrameRateSettingsStore(
        GameFrameRateMode.highRefresh,
      );
      final controller = await GameFrameRateSettingsController.load(store);
      final port = _RecordingFrameRatePort();
      addTearDown(controller.dispose);

      await controller.attachPort(port);
      await controller.setMode(GameFrameRateMode.stable30);

      expect(port.configuredModes, <GameFrameRateMode>[
        GameFrameRateMode.highRefresh,
        GameFrameRateMode.stable30,
      ]);
      expect(controller.mode, GameFrameRateMode.stable30);
      expect(await store.loadMode(), GameFrameRateMode.stable30);
    },
  );

  test('port failure keeps the saved choice and marks support false', () async {
    final store = MemoryGameFrameRateSettingsStore();
    final controller = await GameFrameRateSettingsController.load(store);
    final port = _RecordingFrameRatePort(throwOnConfigure: true);
    addTearDown(controller.dispose);

    await controller.attachPort(port);
    await controller.setMode(GameFrameRateMode.highRefresh);

    expect(controller.mode, GameFrameRateMode.highRefresh);
    expect(await store.loadMode(), GameFrameRateMode.highRefresh);
    expect(controller.supported, isFalse);
  });

  test(
    'rapid mode changes finish in the order selected by the player',
    () async {
      final store = _DelayedFrameRateSettingsStore();
      final controller = await GameFrameRateSettingsController.load(store);
      addTearDown(controller.dispose);

      final stable30 = controller.setMode(GameFrameRateMode.stable30);
      final highRefresh = controller.setMode(GameFrameRateMode.highRefresh);
      await Future<void>.delayed(Duration.zero);

      expect(store.pendingModes, <GameFrameRateMode>[
        GameFrameRateMode.stable30,
      ]);
      store.completeNext();
      await Future<void>.delayed(Duration.zero);
      expect(store.pendingModes, <GameFrameRateMode>[
        GameFrameRateMode.highRefresh,
      ]);
      store.completeNext();
      await Future.wait<void>(<Future<void>>[stable30, highRefresh]);

      expect(controller.mode, GameFrameRateMode.highRefresh);
      expect(await store.loadMode(), GameFrameRateMode.highRefresh);
    },
  );
}

final class _RecordingFrameRatePort implements GameFrameRatePort {
  _RecordingFrameRatePort({this.throwOnConfigure = false});

  final bool throwOnConfigure;
  final List<GameFrameRateMode> configuredModes = <GameFrameRateMode>[];

  @override
  Future<bool> isSupported() async => true;

  @override
  Future<void> configure(GameFrameRateMode mode) async {
    if (throwOnConfigure) throw StateError('configure failed');
    configuredModes.add(mode);
  }
}

final class _DelayedFrameRateSettingsStore
    implements GameFrameRateSettingsStore {
  GameFrameRateMode _mode = GameFrameRateMode.automatic;
  final List<({GameFrameRateMode mode, Completer<void> completer})> _pending =
      <({GameFrameRateMode mode, Completer<void> completer})>[];

  List<GameFrameRateMode> get pendingModes => <GameFrameRateMode>[
    for (final request in _pending) request.mode,
  ];

  @override
  Future<GameFrameRateMode> loadMode() async => _mode;

  @override
  Future<void> saveMode(GameFrameRateMode mode) {
    final completer = Completer<void>();
    _pending.add((mode: mode, completer: completer));
    return completer.future.then((_) => _mode = mode);
  }

  void completeNext() {
    final request = _pending.removeAt(0);
    request.completer.complete();
  }
}
