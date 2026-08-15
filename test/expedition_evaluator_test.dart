import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/expedition/expedition_evaluator.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';

void main() {
  group('ExpeditionEvaluator', () {
    test('远征 14 在旗舰等级、数量、编成和补给均满足时通过', () {
      final result = ExpeditionEvaluator().evaluate(
        state: _state(),
        fleet: _fleet,
        missionId: 14,
      );

      expect(result.hasRule, isTrue);
      expect(result.normalPassed, isTrue);
      expect(result.normalConditions, isNotEmpty);
      expect(result.normalConditions.every((item) => item.passed), isTrue);
    });

    test('补给不足时普通成功检查不通过', () {
      final result = ExpeditionEvaluator().evaluate(
        state: _state(underSupplied: true),
        fleet: _fleet,
        missionId: 14,
      );

      expect(result.normalPassed, isFalse);
      expect(
        result.normalConditions.any(
          (item) =>
              item.kind == ExpeditionConditionKind.resupply && !item.passed,
        ),
        isTrue,
      );
    });

    test('大成功使用当前概率与默认 100% 目标分别判断', () {
      final result = ExpeditionEvaluator().evaluate(
        state: _state(allSparkled: true),
        fleet: _fleet,
        missionId: 14,
        greatSuccessTarget: 100,
      );

      expect(result.normalPassed, isTrue);
      expect(result.greatSuccessRate, greaterThanOrEqualTo(100));
      expect(result.greatSuccessPassed, isTrue);
    });

    test('普通条件未通过时仍保留真实大成功率', () {
      final result = ExpeditionEvaluator().evaluate(
        state: _state(underSupplied: true, allSparkled: true),
        fleet: _fleet,
        missionId: 14,
        greatSuccessTarget: 100,
      );

      final rateCondition = result.greatSuccessConditions.firstWhere(
        (item) => item.kind == ExpeditionConditionKind.greatSuccessRate,
      );
      expect(result.normalPassed, isFalse);
      expect(result.greatSuccessRate, greaterThanOrEqualTo(100));
      expect(
        rateCondition.actual,
        '${result.greatSuccessRate.toStringAsFixed(2)}%',
      );
      expect(rateCondition.actual, isNot('0.00%'));
    });

    test('A3 condition exposes every compact composition alternative', () {
      final result = ExpeditionEvaluator().evaluate(
        state: const GameState(),
        fleet: const Fleet(id: 2, name: '第二舰队'),
        missionId: 102,
      );

      final condition = result.normalConditions.firstWhere(
        (item) => item.kind == ExpeditionConditionKind.composition,
      );
      expect(
        condition.label,
        '舰队构成：1CL+3DD/DE or 1CL+2DE or 1DD+3DE or 1CT+2DE or '
        '1CVE+2DD or 1CVE+2DE',
      );
    });

    test(
      'effective ASW excludes recon plane ASW but other totals stay direct',
      () {
        final state = GameState(
          masterShips: const <int, MasterShip>{
            700: MasterShip(id: 700, name: '测试舰', shipTypeId: 3),
          },
          masterSlotItems: const <int, MasterSlotItem>{
            800: MasterSlotItem(
              id: 800,
              name: '水上侦察机',
              antiSub: 10,
              type: <int>[5, 7, 10, 10, 0],
            ),
          },
          slotItems: const <int, OwnedSlotItem>{
            900: OwnedSlotItem(id: 900, masterId: 800),
          },
          ships: const <int, OwnedShip>{
            1: OwnedShip(
              id: 1,
              masterId: 700,
              level: 99,
              firepower: 500,
              antiAir: 280,
              antiSub: 280,
              lineOfSight: 170,
              slotIds: <int>[900],
            ),
          },
        );
        final result = const ExpeditionEvaluator().evaluate(
          state: state,
          fleet: const Fleet(id: 2, name: '第二舰队', shipIds: <int>[1]),
          missionId: 43,
        );

        ExpeditionConditionResult condition(ExpeditionConditionKind kind) =>
            result.normalConditions.firstWhere((item) => item.kind == kind);

        expect(
          condition(ExpeditionConditionKind.firepower).actual,
          '500 / 500',
        );
        expect(condition(ExpeditionConditionKind.antiAir).actual, '280 / 280');
        expect(condition(ExpeditionConditionKind.antiSub).actual, '270 / 280');
        expect(condition(ExpeditionConditionKind.antiSub).passed, isFalse);
        expect(
          condition(ExpeditionConditionKind.lineOfSight).actual,
          '170 / 170',
        );
      },
    );

    test('CVE classification uses master base ASW instead of current ASW', () {
      GameState state({
        required int baseAntiSub,
        required int currentAntiSub,
      }) => GameState(
        masterShips: <int, MasterShip>{
          700: MasterShip(
            id: 700,
            name: '测试轻空母',
            shipTypeId: 7,
            baseAntiSub: baseAntiSub,
          ),
          701: const MasterShip(id: 701, name: '测试驱逐', shipTypeId: 2),
        },
        ships: <int, OwnedShip>{
          1: OwnedShip(id: 1, masterId: 700, level: 3, antiSub: currentAntiSub),
          2: const OwnedShip(id: 2, masterId: 701, level: 3),
          3: const OwnedShip(id: 3, masterId: 701, level: 3),
        },
      );
      const fleet = Fleet(id: 2, name: '第二舰队', shipIds: <int>[1, 2, 3]);

      bool compositionPassed(GameState value) => const ExpeditionEvaluator()
          .evaluate(state: value, fleet: fleet, missionId: 4)
          .normalConditions
          .firstWhere(
            (item) => item.kind == ExpeditionConditionKind.composition,
          )
          .passed;

      expect(state(baseAntiSub: 0, currentAntiSub: 50), isNotNull);
      expect(
        compositionPassed(state(baseAntiSub: 0, currentAntiSub: 50)),
        isFalse,
      );
      expect(
        compositionPassed(state(baseAntiSub: 1, currentAntiSub: 0)),
        isTrue,
      );
    });

    test(
      'flagship great-success level bonus floors after adding both terms',
      () {
        final result = const ExpeditionEvaluator().evaluate(
          state: const GameState(
            masterShips: <int, MasterShip>{
              700: MasterShip(id: 700, name: '旗舰', shipTypeId: 2),
            },
            ships: <int, OwnedShip>{
              1: OwnedShip(id: 1, masterId: 700, level: 76, condition: 49),
            },
          ),
          fleet: const Fleet(id: 2, name: '第二舰队', shipIds: <int>[1]),
          missionId: 101,
        );

        expect(result.greatSuccessRate, 31.31);
      },
    );

    test('100 percent flagship rate waives the highest-level check', () {
      final result = const ExpeditionEvaluator().evaluate(
        state: GameState(
          masterShips: <int, MasterShip>{
            700: MasterShip(id: 700, name: '旗舰', shipTypeId: 2),
            701: MasterShip(id: 701, name: '僚舰', shipTypeId: 2),
          },
          ships: <int, OwnedShip>{
            1: OwnedShip(id: 1, masterId: 700, level: 1, condition: 50),
            2: OwnedShip(id: 2, masterId: 701, level: 99, condition: 50),
            3: OwnedShip(id: 3, masterId: 701, level: 99, condition: 50),
            4: OwnedShip(id: 4, masterId: 701, level: 99, condition: 50),
            5: OwnedShip(id: 5, masterId: 701, level: 99, condition: 50),
            6: OwnedShip(id: 6, masterId: 701, level: 99, condition: 50),
          },
        ),
        fleet: Fleet(id: 2, name: '第二舰队', shipIds: <int>[1, 2, 3, 4, 5, 6]),
        missionId: 101,
      );

      expect(result.greatSuccessRate, greaterThanOrEqualTo(100));
      expect(
        result.greatSuccessConditions
            .firstWhere(
              (item) =>
                  item.kind == ExpeditionConditionKind.higherLevelFlagship,
            )
            .passed,
        isTrue,
      );
    });

    group('Poi fill-dlc parity', () {
      test('passes when no spare normal Daihatsu exists', () {
        final result = _evaluateDaihatsu(state: _daihatsuState());

        expect(result.daihatsuFill.passed, isTrue);
      });

      test(
        'fails below 20 percent when a capable ship and spare gear exist',
        () {
          final result = _evaluateDaihatsu(
            state: _daihatsuState(
              slotItems: const <int, OwnedSlotItem>{
                100: OwnedSlotItem(id: 100, masterId: 68),
              },
            ),
          );

          expect(result.daihatsuFill.passed, isFalse);
          expect(result.daihatsuFill.auxiliary, isFalse);
          expect(result.daihatsuFill.label, '尽可能多的大发动艇或特大发动艇');
        },
      );

      test(
        'passes at the normal 20 percent cap even when spare gear exists',
        () {
          final result = _evaluateDaihatsu(
            state: _daihatsuState(
              slotCount: 4,
              shipSlotIds: const <int>[101, 102, 103, 104],
              slotItems: const <int, OwnedSlotItem>{
                100: OwnedSlotItem(id: 100, masterId: 68),
                101: OwnedSlotItem(id: 101, masterId: 68),
                102: OwnedSlotItem(id: 102, masterId: 68),
                103: OwnedSlotItem(id: 103, masterId: 68),
                104: OwnedSlotItem(id: 104, masterId: 68),
              },
            ),
          );

          expect(result.daihatsuFill.passed, isTrue);
        },
      );

      test('passes when no expedition ship can equip Daihatsu', () {
        final result = _evaluateDaihatsu(
          state: _daihatsuState(
            equipTypeIds: const <int>{},
            slotItems: const <int, OwnedSlotItem>{
              100: OwnedSlotItem(id: 100, masterId: 68),
            },
          ),
        );

        expect(result.daihatsuFill.passed, isTrue);
      });

      test(
        'equipment on a reserve ship is spare, but equipment in another fleet is not',
        () {
          final reserve = _daihatsuState(
            extraShips: const <int, OwnedShip>{
              2: OwnedShip(id: 2, masterId: 701, level: 1, slotIds: <int>[100]),
            },
            slotItems: const <int, OwnedSlotItem>{
              100: OwnedSlotItem(id: 100, masterId: 68),
            },
          );
          final inOtherFleet = reserve.copyWith(
            fleets: const <Fleet>[
              Fleet(id: 2, name: '第二舰队', shipIds: <int>[1]),
              Fleet(id: 3, name: '第三舰队', shipIds: <int>[2]),
            ],
          );

          expect(
            _evaluateDaihatsu(state: reserve).daihatsuFill.passed,
            isFalse,
          );
          expect(
            _evaluateDaihatsu(state: inOtherFleet).daihatsuFill.passed,
            isTrue,
          );
        },
      );

      test('red Daihatsu reminder does not change success judgments', () {
        const fleet = Fleet(id: 2, name: '第二舰队', shipIds: <int>[1, 2]);
        const state = GameState(
          masterShips: <int, MasterShip>{
            700: MasterShip(
              id: 700,
              name: '大发搭载舰',
              shipTypeId: 2,
              slotCount: 1,
              equipTypeIds: <int>{24},
            ),
            701: MasterShip(id: 701, name: '僚舰', shipTypeId: 2),
          },
          ships: <int, OwnedShip>{
            1: OwnedShip(id: 1, masterId: 700, level: 1, condition: 49),
            2: OwnedShip(id: 2, masterId: 701, level: 1, condition: 49),
          },
          slotItems: <int, OwnedSlotItem>{
            100: OwnedSlotItem(id: 100, masterId: 68),
          },
          fleets: <Fleet>[fleet],
        );

        final result = const ExpeditionEvaluator().evaluate(
          state: state,
          fleet: fleet,
          missionId: 1,
        );

        expect(result.daihatsuFill.passed, isFalse);
        expect(result.normalPassed, isTrue);
      });
    });
  });
}

ExpeditionEvaluation _evaluateDaihatsu({required GameState state}) =>
    const ExpeditionEvaluator().evaluate(
      state: state,
      fleet: const Fleet(id: 2, name: '第二舰队', shipIds: <int>[1]),
      missionId: 1,
    );

GameState _daihatsuState({
  int slotCount = 1,
  Set<int> equipTypeIds = const <int>{24},
  List<int> shipSlotIds = const <int>[],
  Map<int, OwnedShip> extraShips = const <int, OwnedShip>{},
  Map<int, OwnedSlotItem> slotItems = const <int, OwnedSlotItem>{},
}) => GameState(
  masterShips: <int, MasterShip>{
    700: MasterShip(
      id: 700,
      name: '大发搭载舰',
      shipTypeId: 2,
      slotCount: slotCount,
      equipTypeIds: equipTypeIds,
    ),
    701: const MasterShip(id: 701, name: '预备舰', shipTypeId: 2, slotCount: 1),
  },
  ships: <int, OwnedShip>{
    1: OwnedShip(id: 1, masterId: 700, level: 1, slotIds: shipSlotIds),
    ...extraShips,
  },
  slotItems: slotItems,
  fleets: const <Fleet>[
    Fleet(id: 2, name: '第二舰队', shipIds: <int>[1]),
  ],
);

const _fleet = Fleet(id: 2, name: '第2艦隊', shipIds: <int>[1, 2, 3, 4, 5, 6]);

GameState _state({bool underSupplied = false, bool allSparkled = false}) {
  final conditions = allSparkled ? 60 : 49;
  return GameState(
    masterShips: const <int, MasterShip>{
      101: MasterShip(
        id: 101,
        name: '軽巡',
        shipTypeId: 3,
        maxFuel: 30,
        maxAmmo: 30,
      ),
      102: MasterShip(
        id: 102,
        name: '駆逐',
        shipTypeId: 2,
        maxFuel: 15,
        maxAmmo: 20,
      ),
    },
    ships: <int, OwnedShip>{
      1: OwnedShip(
        id: 1,
        masterId: 101,
        level: 76,
        condition: conditions,
        currentFuel: 30,
        currentAmmo: 30,
      ),
      for (var id = 2; id <= 6; id++)
        id: OwnedShip(
          id: id,
          masterId: 102,
          level: 20,
          condition: conditions,
          currentFuel: underSupplied && id == 2 ? 14 : 15,
          currentAmmo: 20,
        ),
    },
  );
}
