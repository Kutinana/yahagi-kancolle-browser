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

  test('offers automatic, stable 60, stable 30, and high refresh modes', () {
    expect(GameFrameRateMode.values, <GameFrameRateMode>[
      GameFrameRateMode.automatic,
      GameFrameRateMode.stable60,
      GameFrameRateMode.stable30,
      GameFrameRateMode.highRefresh,
    ]);
  });

  test('migrates the old boolean preference to an enum value', () async {
    for (final entry in <bool, GameFrameRateMode>{
      true: GameFrameRateMode.automatic,
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
      'followDisplay': GameFrameRateMode.automatic,
      'off': GameFrameRateMode.stable30,
    }.entries) {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'game.frameRateMode': entry.key,
      });
      final store = SharedPreferencesGameFrameRateSettingsStore();
      expect(await store.loadMode(), entry.value);
    }
  });

  test('removed high refresh wire value falls back to automatic', () {
    expect(
      GameFrameRateMode.fromWireName('prefer60'),
      GameFrameRateMode.automatic,
    );
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
      final store = MemoryGameFrameRateSettingsStore();
      final controller = await GameFrameRateSettingsController.load(store);
      final port = _RecordingFrameRatePort();
      addTearDown(controller.dispose);

      await controller.attachPort(port);
      await controller.setMode(GameFrameRateMode.stable60);
      await controller.setMode(GameFrameRateMode.stable30);
      await controller.setMode(GameFrameRateMode.highRefresh);

      expect(port.configuredModes, <GameFrameRateMode>[
        GameFrameRateMode.automatic,
        GameFrameRateMode.stable60,
        GameFrameRateMode.stable30,
        GameFrameRateMode.highRefresh,
      ]);
      expect(controller.mode, GameFrameRateMode.highRefresh);
      expect(await store.loadMode(), GameFrameRateMode.highRefresh);
    },
  );

  test('port failure keeps the saved choice and marks support false', () async {
    final store = MemoryGameFrameRateSettingsStore();
    final controller = await GameFrameRateSettingsController.load(store);
    final port = _RecordingFrameRatePort(throwOnConfigure: true);
    addTearDown(controller.dispose);

    await controller.attachPort(port);
    await controller.setMode(GameFrameRateMode.stable30);

    expect(controller.mode, GameFrameRateMode.stable30);
    expect(await store.loadMode(), GameFrameRateMode.stable30);
    expect(controller.supported, isFalse);
  });

  test(
    'attach and live mode changes run on the same serialized queue',
    () async {
      final controller = await GameFrameRateSettingsController.load(
        MemoryGameFrameRateSettingsStore(),
      );
      addTearDown(controller.dispose);
      final port = _GatedFrameRatePort();

      final attach = controller.attachPort(port);
      await Future<void>.delayed(Duration.zero);
      expect(port.events, <String>['supported.start']);

      final change = controller.setMode(GameFrameRateMode.stable30);
      await Future<void>.delayed(Duration.zero);
      expect(port.events, <String>['supported.start']);

      port.supportGate.complete();
      await Future.wait<void>(<Future<void>>[attach, change]);

      expect(port.events, <String>[
        'supported.start',
        'supported.end',
        'configure:auto',
        'configure:stable30',
      ]);
      expect(controller.mode, GameFrameRateMode.stable30);
    },
  );

  test(
    'rapid mode changes finish in the order selected by the player',
    () async {
      final store = _DelayedFrameRateSettingsStore();
      final controller = await GameFrameRateSettingsController.load(store);
      addTearDown(controller.dispose);

      final stable30 = controller.setMode(GameFrameRateMode.stable30);
      final automatic = controller.setMode(GameFrameRateMode.automatic);
      await Future<void>.delayed(Duration.zero);

      expect(store.pendingModes, <GameFrameRateMode>[
        GameFrameRateMode.stable30,
      ]);
      store.completeNext();
      await Future<void>.delayed(Duration.zero);
      expect(store.pendingModes, <GameFrameRateMode>[
        GameFrameRateMode.automatic,
      ]);
      store.completeNext();
      await Future.wait<void>(<Future<void>>[stable30, automatic]);

      expect(controller.mode, GameFrameRateMode.automatic);
      expect(await store.loadMode(), GameFrameRateMode.automatic);
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

final class _GatedFrameRatePort implements GameFrameRatePort {
  final Completer<void> supportGate = Completer<void>();
  final List<String> events = <String>[];

  @override
  Future<bool> isSupported() async {
    events.add('supported.start');
    await supportGate.future;
    events.add('supported.end');
    return true;
  }

  @override
  Future<void> configure(GameFrameRateMode mode) async {
    events.add('configure:${mode.wireName}');
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
