import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_controller.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_damage_alert.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_models.dart';
import 'package:yahagi_kancolle_browser/src/battle/prediction/battle_prediction_engine.dart';
import 'package:yahagi_kancolle_browser/src/battle/prediction/battle_prediction_executor.dart';
import 'package:yahagi_kancolle_browser/src/bridge/captured_api_event.dart';
import 'package:yahagi_kancolle_browser/src/capture/battle_result_warning_overlay.dart';
import 'package:yahagi_kancolle_browser/src/capture/game_capture_controller.dart';
import 'package:yahagi_kancolle_browser/src/capture/game_capture_port.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_reducer.dart';
import 'package:yahagi_kancolle_browser/src/settings/safety_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/safety_settings_store.dart';

import 'fixtures/kcsapi_fixtures.dart';

BattleShipSnapshot _heavyDamageShip() {
  return const BattleShipSnapshot(
    masterId: 1,
    name: 'test',
    side: BattleSide.friend,
    fleetRole: BattleFleetRole.main,
    position: 1,
    initialHp: 20,
    maxHp: 20,
    currentHp: 5,
  );
}

void main() {
  test('boss result has no retreat risk even with a heavily damaged ship', () {
    final battle = LiveBattle(
      context: const BattleContext(node: 5, bossNode: 5),
      friendMain: <BattleShipSnapshot>[_heavyDamageShip()],
      displayStage: BattleDisplayStage.result,
    );

    expect(shouldShowPostBattleWarning(battle), isFalse);
  });

  test('non-boss result keeps the heavily damaged retreat warning', () {
    final battle = LiveBattle(
      context: const BattleContext(node: 4, bossNode: 5),
      friendMain: <BattleShipSnapshot>[_heavyDamageShip()],
      displayStage: BattleDisplayStage.result,
    );

    expect(shouldShowPostBattleWarning(battle), isTrue);
  });

  testWidgets('confirm warning vibrates once and shows a dialog', (
    tester,
  ) async {
    final fixture = await _WarningOverlayFixture.create(
      mode: BattleWarningMode.confirm,
    );
    addTearDown(fixture.dispose);

    await fixture.pump(tester);
    await fixture.showWarning(tester);

    expect(fixture.alerts.alerts, <BattleDamageAlertSeverity>[
      BattleDamageAlertSeverity.postBattleWarning,
    ]);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('大破安全警告'), findsOneWidget);
    expect(find.text('出击舰队中存在大破舰娘！'), findsOneWidget);
    expect(
      find.text('继续进击前，请确认大破舰的管损及退避状态；无法确保安全时请撤退！'),
      findsOneWidget,
    );
    expect(find.text('确认了解'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('off mode neither vibrates nor shows a dialog', (tester) async {
    final fixture = await _WarningOverlayFixture.create(
      mode: BattleWarningMode.off,
    );
    addTearDown(fixture.dispose);

    await fixture.pump(tester);
    await fixture.showWarning(tester);

    expect(fixture.alerts.alerts, isEmpty);
    expect(find.byType(AlertDialog), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('warning does not vibrate while damage vibration is disabled', (
    tester,
  ) async {
    final fixture = await _WarningOverlayFixture.create(
      mode: BattleWarningMode.confirm,
      vibrationEnabled: false,
    );
    addTearDown(fixture.dispose);

    await fixture.pump(tester);
    await fixture.showWarning(tester);

    expect(fixture.alerts.alerts, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

final class _WarningOverlayFixture {
  _WarningOverlayFixture({
    required this.captureController,
    required this.capturePort,
    required this.battleController,
    required this.settingsController,
    required this.alerts,
  });

  final GameCaptureController captureController;
  final _FakeGameCapturePort capturePort;
  final BattleController battleController;
  final SafetySettingsController settingsController;
  final _RecordingDamageAlertPort alerts;

  static Future<_WarningOverlayFixture> create({
    required BattleWarningMode mode,
    bool vibrationEnabled = true,
  }) async {
    final reducer = GameStateReducer();
    var state = reducer.reduce(GameState.empty, start2Event);
    state = reducer.reduce(state, portEvent);
    final battleController = BattleController(
      gameState: () => state,
      predictionExecutor: const _InlinePredictionExecutor(),
    );
    final captureController = GameCaptureController();
    final capturePort = _FakeGameCapturePort();
    await captureController.attach(capturePort, enabled: true);
    final settingsController = await SafetySettingsController.load(
      MemorySafetySettingsStore(),
    );
    await settingsController.setBattleWarningMode(mode);
    await settingsController.setBattleDamageVibrationEnabled(vibrationEnabled);
    return _WarningOverlayFixture(
      captureController: captureController,
      capturePort: capturePort,
      battleController: battleController,
      settingsController: settingsController,
      alerts: _RecordingDamageAlertPort(),
    );
  }

  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      home: BattleResultWarningOverlay(
        gameCaptureController: captureController,
        battleController: battleController,
        safetySettingsController: settingsController,
        damageAlertPort: alerts,
        child: const SizedBox.expand(),
      ),
    ),
  );

  Future<void> showWarning(WidgetTester tester) async {
    battleController
      ..accept(mapStartEvent)
      ..accept(
        kcsapiEvent('/kcsapi/api_req_sortie/battle', <String, Object?>{
          'api_deck_id': 1,
          'api_f_nowhps': <int>[30, 15],
          'api_f_maxhps': <int>[30, 15],
          'api_e_nowhps': <int>[20],
          'api_e_maxhps': <int>[20],
          'api_ship_ke': <int>[501],
          'api_hougeki1': <String, Object?>{
            'api_at_eflag': <int>[1],
            'api_at_list': <int>[0],
            'api_df_list': <Object?>[
              <int>[0],
            ],
            'api_damage': <Object?>[
              <num>[25],
            ],
          },
        }, sequence: 801),
      )
      ..accept(battleResultEvent);
    await battleController.idle;

    capturePort.add(battleResultEvent);
    await tester.pump();
    await tester.pump();
  }

  void dispose() {
    battleController.dispose();
    captureController.dispose();
    capturePort.dispose();
    settingsController.dispose();
  }
}

final class _RecordingDamageAlertPort implements BattleDamageAlertPort {
  final List<BattleDamageAlertSeverity> alerts = <BattleDamageAlertSeverity>[];

  @override
  Future<void> alert(BattleDamageAlertSeverity severity) async {
    alerts.add(severity);
  }
}

final class _InlinePredictionExecutor implements BattlePredictionExecutor {
  const _InlinePredictionExecutor();

  @override
  Future<BattlePredictionAppendResult> append({
    required BattlePredictionEngine engine,
    required String path,
    required Map<String, Object?> data,
  }) async =>
      (engine: engine, prediction: engine.append(path: path, data: data));
}

final class _FakeGameCapturePort implements GameCapturePort {
  final StreamController<CapturedApiEvent> _events =
      StreamController<CapturedApiEvent>.broadcast(sync: true);

  @override
  Stream<CapturedApiEvent> get events => _events.stream;

  void add(CapturedApiEvent event) => _events.add(event);

  @override
  Future<void> configure({
    required bool enabled,
    required String script,
  }) async {}

  @override
  Future<bool> isSupported() async => true;

  @override
  void dispose() => unawaited(_events.close());
}
