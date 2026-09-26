import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_controller.dart';
import 'package:yahagi_kancolle_browser/src/battle/prediction/battle_prediction_executor.dart';
import 'package:yahagi_kancolle_browser/src/bridge/captured_api_event.dart';
import 'package:yahagi_kancolle_browser/src/fleet/equipment_type_icon.dart';
import 'package:yahagi_kancolle_browser/src/fleet/fleet_summary_card.dart';
import 'package:yahagi_kancolle_browser/src/game_state/combat_state.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_controller.dart';

void main() {
  setUpAll(() {
    GameStateController.disableTimerForTest = true;
  });

  Widget testBriefingApp(GameStateController controller) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: FleetSummaryCard(
            controller: controller,
            collapsed: false,
            onToggleCollapse: () {},
            onOpenFleet: (_) {},
          ),
        ),
      ),
    );
  }

  testWidgets(
    'Case 1: Personnel in normal slot disappears immediately after battle and normal gear is kept',
    (tester) async {
      final state = createSortieState(
        ships: [
          OwnedShip(
            id: 1001,
            masterId: 101,
            level: 50,
            currentHp: 30,
            maxHp: 30,
            slotIds: const <int>[100, 501, 101],
          ),
        ],
        slotItems: const <OwnedSlotItem>[
          OwnedSlotItem(instanceId: 100, masterSlotItemId: 1), // Main gun
          OwnedSlotItem(instanceId: 501, masterSlotItemId: 42), // Personnel
          OwnedSlotItem(instanceId: 101, masterSlotItemId: 2), // Radar
        ],
      );

      final gameStateController = GameStateController(initialState: state);
      await tester.pumpWidget(testBriefingApp(gameStateController));
      await tester.pump();

      final battleController = BattleController(
        gameState: () => gameStateController.state,
        waitForGameState: () => gameStateController.idle,
        onFriendlyHpUpdated: gameStateController.applyFriendlyBattleHp,
        onDamageControlConsumed:
            gameStateController.applyDamageControlConsumption,
        predictionExecutor: const ImmediateBattlePredictionExecutor(),
      );
      battleController.bindFriendlyHpUpdater(
        gameStateController.applyFriendlyBattleHp,
      );
      battleController.bindDamageControlUpdater(
        gameStateController.applyDamageControlConsumption,
      );
      addTearDown(battleController.dispose);
      addTearDown(gameStateController.dispose);

      // Start map
      battleController.accept(
        apiEvent(
          '/kcsapi/api_req_map/start',
          mapData,
          sequence: 2,
          requestParams: const <String, Object?>{'api_deck_id': '1'},
        ),
      );
      gameStateController.accept(
        apiEvent(
          '/kcsapi/api_req_map/start',
          mapData,
          sequence: 2,
          requestParams: const <String, Object?>{'api_deck_id': '1'},
        ),
      );
      await battleController.idle;
      await gameStateController.idle;

      await tester.pump();

      // Before battle: 3 items in equipment row (gun: icon 1, damecon: icon 14, radar: icon 2)
      final equipmentRow = find.byKey(const Key('equipment-1001'));
      expect(equipmentRow, findsOneWidget);
      final iconsBefore = tester
          .widgetList<EquipmentTypeIconImage>(
            find.descendant(
              of: equipmentRow,
              matching: find.byType(EquipmentTypeIconImage),
            ),
          )
          .map((w) => w.iconId)
          .toList();
      expect(iconsBefore, <int>[1, 14, 2]);

      // Battle A: lethal hit triggers personnel (42)
      battleController.accept(
        apiEvent(
          '/kcsapi/api_req_sortie/battle',
          lethalBattle(30, openingHp: 30),
          sequence: 3,
        ),
      );
      await battleController.idle;
      await gameStateController.idle;

      await tester.pump();

      // Immediately after battle A: personnel icon is gone! Other gear preserved!
      final iconsAfter = tester
          .widgetList<EquipmentTypeIconImage>(
            find.descendant(
              of: equipmentRow,
              matching: find.byType(EquipmentTypeIconImage),
            ),
          )
          .map((w) => w.iconId)
          .toList();
      expect(iconsAfter, <int>[1, 2]);
      expect(gameStateController.state.ships[1001]!.slotIds, <int>[
        100,
        -1,
        101,
      ]);
      expect(gameStateController.state.slotItems[501], isNull);
      expect(gameStateController.state.ships[1001]!.currentHp, 6);
    },
  );

  testWidgets(
    'Case 2: Goddess in normal slot disappears immediately and restores max HP',
    (tester) async {
      final state = createSortieState(
        ships: [
          OwnedShip(
            id: 1001,
            masterId: 101,
            level: 50,
            currentHp: 30,
            maxHp: 30,
            slotIds: const <int>[502],
          ),
        ],
        slotItems: const <OwnedSlotItem>[
          OwnedSlotItem(instanceId: 502, masterSlotItemId: 43), // Goddess
        ],
      );

      final gameStateController = GameStateController(initialState: state);
      await tester.pumpWidget(testBriefingApp(gameStateController));
      await tester.pump();

      final battleController = BattleController(
        gameState: () => gameStateController.state,
        waitForGameState: () => gameStateController.idle,
        onFriendlyHpUpdated: gameStateController.applyFriendlyBattleHp,
        onDamageControlConsumed:
            gameStateController.applyDamageControlConsumption,
        predictionExecutor: const ImmediateBattlePredictionExecutor(),
      );
      addTearDown(battleController.dispose);
      addTearDown(gameStateController.dispose);

      battleController.accept(
        apiEvent(
          '/kcsapi/api_req_map/start',
          mapData,
          sequence: 2,
          requestParams: const <String, Object?>{'api_deck_id': '1'},
        ),
      );
      gameStateController.accept(
        apiEvent(
          '/kcsapi/api_req_map/start',
          mapData,
          sequence: 2,
          requestParams: const <String, Object?>{'api_deck_id': '1'},
        ),
      );
      await battleController.idle;
      await gameStateController.idle;
      await tester.pump();

      final equipmentRow = find.byKey(const Key('equipment-1001'));
      expect(equipmentRow, findsOneWidget);
      expect(
        tester
            .widgetList<EquipmentTypeIconImage>(
              find.descendant(
                of: equipmentRow,
                matching: find.byType(EquipmentTypeIconImage),
              ),
            )
            .map((w) => w.iconId),
        <int>[14],
      );

      // Battle A: lethal hit triggers Goddess (43)
      battleController.accept(
        apiEvent(
          '/kcsapi/api_req_sortie/battle',
          lethalBattle(30, openingHp: 30),
          sequence: 3,
        ),
      );
      await battleController.idle;
      await gameStateController.idle;
      await tester.pump();

      // Goddess icon immediately disappears and HP is full
      final iconsAfter = tester
          .widgetList<EquipmentTypeIconImage>(
            find.descendant(
              of: equipmentRow,
              matching: find.byType(EquipmentTypeIconImage),
            ),
          )
          .map((w) => w.iconId)
          .toList();
      expect(iconsAfter, isEmpty);
      expect(gameStateController.state.ships[1001]!.slotIds, <int>[-1]);
      expect(gameStateController.state.ships[1001]!.currentHp, 30);
    },
  );

  testWidgets(
    'Case 3: Goddess in expansion slot (extraSlotId) disappears immediately and sets extraSlotId to -1',
    (tester) async {
      final state = createSortieState(
        ships: [
          OwnedShip(
            id: 1001,
            masterId: 101,
            level: 50,
            currentHp: 30,
            maxHp: 30,
            slotIds: const <int>[100],
            extraSlotId: 502,
          ),
        ],
        slotItems: const <OwnedSlotItem>[
          OwnedSlotItem(instanceId: 100, masterSlotItemId: 1), // Main gun
          OwnedSlotItem(
            instanceId: 502,
            masterSlotItemId: 43,
          ), // Goddess in extra slot
        ],
      );

      final gameStateController = GameStateController(initialState: state);
      await tester.pumpWidget(testBriefingApp(gameStateController));
      await tester.pump();

      final battleController = BattleController(
        gameState: () => gameStateController.state,
        waitForGameState: () => gameStateController.idle,
        onFriendlyHpUpdated: gameStateController.applyFriendlyBattleHp,
        onDamageControlConsumed:
            gameStateController.applyDamageControlConsumption,
        predictionExecutor: const ImmediateBattlePredictionExecutor(),
      );
      addTearDown(battleController.dispose);
      addTearDown(gameStateController.dispose);

      battleController.accept(
        apiEvent(
          '/kcsapi/api_req_map/start',
          mapData,
          sequence: 2,
          requestParams: const <String, Object?>{'api_deck_id': '1'},
        ),
      );
      gameStateController.accept(
        apiEvent(
          '/kcsapi/api_req_map/start',
          mapData,
          sequence: 2,
          requestParams: const <String, Object?>{'api_deck_id': '1'},
        ),
      );
      await battleController.idle;
      await gameStateController.idle;
      await tester.pump();

      final equipmentRow = find.byKey(const Key('equipment-1001'));
      expect(
        tester
            .widgetList<EquipmentTypeIconImage>(
              find.descendant(
                of: equipmentRow,
                matching: find.byType(EquipmentTypeIconImage),
              ),
            )
            .map((w) => w.iconId),
        <int>[1, 14],
      );

      // Battle A: lethal hit triggers Goddess in extra slot
      battleController.accept(
        apiEvent(
          '/kcsapi/api_req_sortie/battle',
          lethalBattle(30, openingHp: 30),
          sequence: 3,
        ),
      );
      await battleController.idle;
      await gameStateController.idle;
      await tester.pump();

      // Only main gun icon remains, extra slot is cleared
      final iconsAfter = tester
          .widgetList<EquipmentTypeIconImage>(
            find.descendant(
              of: equipmentRow,
              matching: find.byType(EquipmentTypeIconImage),
            ),
          )
          .map((w) => w.iconId)
          .toList();
      expect(iconsAfter, <int>[1]);
      expect(gameStateController.state.ships[1001]!.slotIds, <int>[100]);
      expect(gameStateController.state.ships[1001]!.extraSlotId, -1);
      expect(gameStateController.state.slotItems[502], isNull);
    },
  );

  testWidgets(
    'Case 4: Multiple ships with damage controls only deletes the activating ship',
    (tester) async {
      final state = createSortieState(
        ships: [
          OwnedShip(
            id: 1001,
            masterId: 101,
            level: 50,
            currentHp: 30,
            maxHp: 30,
            slotIds: const <int>[501], // Ship 1: Goddess
          ),
          OwnedShip(
            id: 1002,
            masterId: 102,
            level: 50,
            currentHp: 30,
            maxHp: 30,
            slotIds: const <int>[502], // Ship 2: Goddess
          ),
          OwnedShip(
            id: 1003,
            masterId: 103,
            level: 50,
            currentHp: 30,
            maxHp: 30,
            slotIds: const <int>[503], // Ship 3: Personnel
          ),
        ],
        slotItems: const <OwnedSlotItem>[
          OwnedSlotItem(instanceId: 501, masterSlotItemId: 43),
          OwnedSlotItem(instanceId: 502, masterSlotItemId: 43),
          OwnedSlotItem(instanceId: 503, masterSlotItemId: 42),
        ],
      );

      final gameStateController = GameStateController(initialState: state);
      await tester.pumpWidget(testBriefingApp(gameStateController));
      await tester.pump();

      final battleController = BattleController(
        gameState: () => gameStateController.state,
        waitForGameState: () => gameStateController.idle,
        onFriendlyHpUpdated: gameStateController.applyFriendlyBattleHp,
        onDamageControlConsumed:
            gameStateController.applyDamageControlConsumption,
        predictionExecutor: const ImmediateBattlePredictionExecutor(),
      );
      addTearDown(battleController.dispose);
      addTearDown(gameStateController.dispose);

      battleController.accept(
        apiEvent(
          '/kcsapi/api_req_map/start',
          mapData,
          sequence: 2,
          requestParams: const <String, Object?>{'api_deck_id': '1'},
        ),
      );
      gameStateController.accept(
        apiEvent(
          '/kcsapi/api_req_map/start',
          mapData,
          sequence: 2,
          requestParams: const <String, Object?>{'api_deck_id': '1'},
        ),
      );
      await battleController.idle;
      await gameStateController.idle;
      await tester.pump();

      // All 3 ships have damecon icon
      expect(
        tester
            .widgetList<EquipmentTypeIconImage>(
              find.descendant(
                of: find.byKey(const Key('equipment-1001')),
                matching: find.byType(EquipmentTypeIconImage),
              ),
            )
            .map((w) => w.iconId),
        <int>[14],
      );
      expect(
        tester
            .widgetList<EquipmentTypeIconImage>(
              find.descendant(
                of: find.byKey(const Key('equipment-1002')),
                matching: find.byType(EquipmentTypeIconImage),
              ),
            )
            .map((w) => w.iconId),
        <int>[14],
      );
      expect(
        tester
            .widgetList<EquipmentTypeIconImage>(
              find.descendant(
                of: find.byKey(const Key('equipment-1003')),
                matching: find.byType(EquipmentTypeIconImage),
              ),
            )
            .map((w) => w.iconId),
        <int>[14],
      );

      // Battle A: Enemy attacks Ship 2 (position 1) with lethal damage
      battleController.accept(
        apiEvent(
          '/kcsapi/api_req_sortie/battle',
          threeShipLethalBattle(targetPosition: 1, damage: 30),
          sequence: 3,
        ),
      );
      await battleController.idle;
      await gameStateController.idle;
      await tester.pump();

      // Ship 1 still has goddess:
      expect(
        tester
            .widgetList<EquipmentTypeIconImage>(
              find.descendant(
                of: find.byKey(const Key('equipment-1001')),
                matching: find.byType(EquipmentTypeIconImage),
              ),
            )
            .map((w) => w.iconId),
        <int>[14],
      );
      // Ship 2 goddess is GONE:
      expect(
        tester
            .widgetList<EquipmentTypeIconImage>(
              find.descendant(
                of: find.byKey(const Key('equipment-1002')),
                matching: find.byType(EquipmentTypeIconImage),
              ),
            )
            .map((w) => w.iconId),
        isEmpty,
      );
      // Ship 3 still has personnel:
      expect(
        tester
            .widgetList<EquipmentTypeIconImage>(
              find.descendant(
                of: find.byKey(const Key('equipment-1003')),
                matching: find.byType(EquipmentTypeIconImage),
              ),
            )
            .map((w) => w.iconId),
        <int>[14],
      );

      expect(gameStateController.state.ships[1001]!.slotIds, <int>[501]);
      expect(gameStateController.state.ships[1002]!.slotIds, <int>[-1]);
      expect(gameStateController.state.ships[1003]!.slotIds, <int>[503]);
    },
  );

  testWidgets(
    'Case 5: Multi-node lifecycle - A node consumes goddess, briefing has no goddess before entering B, and never reappears',
    (tester) async {
      final state = createSortieState(
        ships: [
          OwnedShip(
            id: 1001,
            masterId: 101,
            level: 50,
            currentHp: 30,
            maxHp: 30,
            slotIds: const <int>[502],
          ),
        ],
        slotItems: const <OwnedSlotItem>[
          OwnedSlotItem(instanceId: 502, masterSlotItemId: 43), // Goddess
        ],
      );

      final gameStateController = GameStateController(initialState: state);
      await tester.pumpWidget(testBriefingApp(gameStateController));
      await tester.pump();

      final battleController = BattleController(
        gameState: () => gameStateController.state,
        waitForGameState: () => gameStateController.idle,
        onFriendlyHpUpdated: gameStateController.applyFriendlyBattleHp,
        onDamageControlConsumed:
            gameStateController.applyDamageControlConsumption,
        predictionExecutor: const ImmediateBattlePredictionExecutor(),
      );
      addTearDown(battleController.dispose);
      addTearDown(gameStateController.dispose);

      // Node A start
      battleController.accept(
        apiEvent(
          '/kcsapi/api_req_map/start',
          mapData,
          sequence: 2,
          requestParams: const <String, Object?>{'api_deck_id': '1'},
        ),
      );
      gameStateController.accept(
        apiEvent(
          '/kcsapi/api_req_map/start',
          mapData,
          sequence: 2,
          requestParams: const <String, Object?>{'api_deck_id': '1'},
        ),
      );
      await battleController.idle;
      await gameStateController.idle;

      // Node A battle: lethal hit consumes goddess
      battleController.accept(
        apiEvent(
          '/kcsapi/api_req_sortie/battle',
          lethalBattle(30, openingHp: 30),
          sequence: 3,
        ),
      );
      await battleController.idle;
      await gameStateController.idle;
      await tester.pump();

      // A battle finished: goddess icon immediately disappeared!
      final equipmentRow = find.byKey(const Key('equipment-1001'));
      expect(
        tester.widgetList<EquipmentTypeIconImage>(
          find.descendant(
            of: equipmentRow,
            matching: find.byType(EquipmentTypeIconImage),
          ),
        ),
        isEmpty,
      );

      // Move to Node B before battle starts
      battleController.accept(
        apiEvent('/kcsapi/api_req_map/next', mapData, sequence: 4),
      );
      gameStateController.accept(
        apiEvent('/kcsapi/api_req_map/next', mapData, sequence: 4),
      );
      await battleController.idle;
      await gameStateController.idle;
      await tester.pump();

      // In Node B navigation before battle starts: STILL NO GODDESS
      expect(
        tester.widgetList<EquipmentTypeIconImage>(
          find.descendant(
            of: equipmentRow,
            matching: find.byType(EquipmentTypeIconImage),
          ),
        ),
        isEmpty,
      );

      // Node B battle: lethal hit (without goddess, HP reaches 0)
      battleController.accept(
        apiEvent(
          '/kcsapi/api_req_sortie/battle',
          lethalBattle(30, openingHp: 30),
          sequence: 5,
        ),
      );
      await battleController.idle;
      await gameStateController.idle;
      await tester.pump();

      // Node B battle finished: still no goddess
      expect(
        tester.widgetList<EquipmentTypeIconImage>(
          find.descendant(
            of: equipmentRow,
            matching: find.byType(EquipmentTypeIconImage),
          ),
        ),
        isEmpty,
      );
      expect(gameStateController.state.ships[1001]!.currentHp, 0);

      // Move to Node C
      battleController.accept(
        apiEvent('/kcsapi/api_req_map/next', mapData, sequence: 6),
      );
      gameStateController.accept(
        apiEvent('/kcsapi/api_req_map/next', mapData, sequence: 6),
      );
      await battleController.idle;
      await gameStateController.idle;
      await tester.pump();
      expect(
        tester.widgetList<EquipmentTypeIconImage>(
          find.descendant(
            of: equipmentRow,
            matching: find.byType(EquipmentTypeIconImage),
          ),
        ),
        isEmpty,
      );
    },
  );

  testWidgets(
    'Case 6: Duplicate personnel on one ship consumed one by one across nodes with immediate briefing updates',
    (tester) async {
      final state = createSortieState(
        ships: [
          OwnedShip(
            id: 1001,
            masterId: 101,
            level: 50,
            currentHp: 30,
            maxHp: 30,
            slotIds: const <int>[501, 502],
          ),
        ],
        slotItems: const <OwnedSlotItem>[
          OwnedSlotItem(instanceId: 501, masterSlotItemId: 42),
          OwnedSlotItem(instanceId: 502, masterSlotItemId: 42),
        ],
      );

      final gameStateController = GameStateController(initialState: state);
      await tester.pumpWidget(testBriefingApp(gameStateController));
      await tester.pump();

      final battleController = BattleController(
        gameState: () => gameStateController.state,
        waitForGameState: () => gameStateController.idle,
        onFriendlyHpUpdated: gameStateController.applyFriendlyBattleHp,
        onDamageControlConsumed:
            gameStateController.applyDamageControlConsumption,
        predictionExecutor: const ImmediateBattlePredictionExecutor(),
      );
      addTearDown(battleController.dispose);
      addTearDown(gameStateController.dispose);

      // Start Node A
      battleController.accept(
        apiEvent(
          '/kcsapi/api_req_map/start',
          mapData,
          sequence: 2,
          requestParams: const <String, Object?>{'api_deck_id': '1'},
        ),
      );
      gameStateController.accept(
        apiEvent(
          '/kcsapi/api_req_map/start',
          mapData,
          sequence: 2,
          requestParams: const <String, Object?>{'api_deck_id': '1'},
        ),
      );
      await battleController.idle;
      await gameStateController.idle;
      await tester.pump();

      final equipmentRow = find.byKey(const Key('equipment-1001'));
      // Initially has 2 personnel icons
      expect(
        tester.widgetList<EquipmentTypeIconImage>(
          find.descendant(
            of: equipmentRow,
            matching: find.byType(EquipmentTypeIconImage),
          ),
        ),
        hasLength(2),
      );

      // Battle A: 1st lethal hit consumes 501
      battleController.accept(
        apiEvent(
          '/kcsapi/api_req_sortie/battle',
          lethalBattle(30, openingHp: 30),
          sequence: 3,
        ),
      );
      await battleController.idle;
      await gameStateController.idle;
      await tester.pump();

      // Exactly 1 personnel icon remains
      expect(
        tester.widgetList<EquipmentTypeIconImage>(
          find.descendant(
            of: equipmentRow,
            matching: find.byType(EquipmentTypeIconImage),
          ),
        ),
        hasLength(1),
      );
      expect(gameStateController.state.ships[1001]!.slotIds, <int>[-1, 502]);

      // Move to Node B
      battleController.accept(
        apiEvent('/kcsapi/api_req_map/next', mapData, sequence: 4),
      );
      gameStateController.accept(
        apiEvent('/kcsapi/api_req_map/next', mapData, sequence: 4),
      );
      await battleController.idle;
      await gameStateController.idle;

      // Battle B: 2nd lethal hit consumes 502
      battleController.accept(
        apiEvent(
          '/kcsapi/api_req_sortie/battle',
          lethalBattle(6, openingHp: 6),
          sequence: 5,
        ),
      );
      await battleController.idle;
      await gameStateController.idle;
      await tester.pump();

      // Now 0 personnel icons remain
      expect(
        tester.widgetList<EquipmentTypeIconImage>(
          find.descendant(
            of: equipmentRow,
            matching: find.byType(EquipmentTypeIconImage),
          ),
        ),
        isEmpty,
      );
      expect(gameStateController.state.ships[1001]!.slotIds, <int>[-1, -1]);
    },
  );
}

const Map<String, Object?> mapData = <String, Object?>{
  'api_maparea_id': 1,
  'api_mapinfo_no': 1,
  'api_no': 1,
};

CapturedApiEvent apiEvent(
  String path,
  Object? data, {
  required int sequence,
  Map<String, Object?> requestParams = const <String, Object?>{},
}) => CapturedApiEvent(
  path: path,
  responseBody: jsonEncode(<String, Object?>{
    'api_result': 1,
    'api_data': data,
  }),
  requestParams: requestParams,
  source: CaptureSource.xhr,
  sourceOrigin: 'https://w01y.kancolle-server.com',
  capturedAt: DateTime.utc(2026, 9, 16),
  sequence: sequence,
);

GameState createSortieState({
  required List<OwnedShip> ships,
  required List<OwnedSlotItem> slotItems,
}) {
  return GameState(
    hasPortData: true,
    combatState: const CombatState(
      isActive: true,
      sortieFleetId: 1,
      mapArea: 1,
      mapInfo: 1,
    ),
    masterShips: const <int, MasterShip>{
      101: MasterShip(
        id: 101,
        sortNo: 1,
        name: '夕张',
        shipTypeId: 2,
        classTypeId: 1,
        speed: 10,
        range: 1,
        maxFuel: 20,
        maxAmmo: 20,
        slotCount: 4,
      ),
      102: MasterShip(
        id: 102,
        sortNo: 2,
        name: '吹雪',
        shipTypeId: 3,
        classTypeId: 1,
        speed: 10,
        range: 1,
        maxFuel: 20,
        maxAmmo: 20,
        slotCount: 3,
      ),
      103: MasterShip(
        id: 103,
        sortNo: 3,
        name: '白雪',
        shipTypeId: 3,
        classTypeId: 1,
        speed: 10,
        range: 1,
        maxFuel: 20,
        maxAmmo: 20,
        slotCount: 3,
      ),
    },
    masterSlotItems: const <int, MasterSlotItem>{
      1: MasterSlotItem(
        id: 1,
        name: '12.7cm连装炮',
        type: <int>[1, 2, 3, 1], // type[3] == 1
      ),
      2: MasterSlotItem(
        id: 2,
        name: '22号对海电探',
        type: <int>[1, 2, 3, 2], // type[3] == 2
      ),
      42: MasterSlotItem(
        id: 42,
        name: '応急修理要員',
        type: <int>[1, 2, 3, 14], // type[3] == 14
      ),
      43: MasterSlotItem(
        id: 43,
        name: '応急修理女神',
        type: <int>[1, 2, 3, 14], // type[3] == 14
      ),
    },
    ships: <int, OwnedShip>{for (final s in ships) s.id: s},
    slotItems: <int, OwnedSlotItem>{
      for (final item in slotItems) item.instanceId: item,
    },
    fleets: <Fleet>[
      Fleet(id: 1, name: '第一舰队', shipIds: <int>[for (final s in ships) s.id]),
    ],
  );
}

Map<String, Object?> lethalBattle(num damage, {required int openingHp}) =>
    <String, Object?>{
      'api_deck_id': 1,
      'api_f_nowhps': <int>[-1, openingHp],
      'api_f_maxhps': const <int>[-1, 30],
      'api_e_nowhps': const <int>[-1, 20],
      'api_e_maxhps': const <int>[-1, 20],
      'api_ship_ke': const <int>[-1, 501],
      'api_hougeki1': <String, Object?>{
        'api_at_eflag': const <int>[1],
        'api_at_list': const <int>[0],
        'api_df_list': const <Object?>[
          <int>[0],
        ],
        'api_damage': <Object?>[
          <num>[damage],
        ],
      },
    };

Map<String, Object?> threeShipLethalBattle({
  required int targetPosition,
  required num damage,
}) => <String, Object?>{
  'api_deck_id': 1,
  'api_f_nowhps': const <int>[-1, 30, 30, 30],
  'api_f_maxhps': const <int>[-1, 30, 30, 30],
  'api_e_nowhps': const <int>[-1, 20],
  'api_e_maxhps': const <int>[-1, 20],
  'api_ship_ke': const <int>[-1, 501],
  'api_hougeki1': <String, Object?>{
    'api_at_eflag': const <int>[1],
    'api_at_list': const <int>[0],
    'api_df_list': <Object?>[
      <int>[targetPosition],
    ],
    'api_damage': <Object?>[
      <num>[damage],
    ],
  },
};
