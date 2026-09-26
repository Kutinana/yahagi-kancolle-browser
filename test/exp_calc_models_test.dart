import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/exp_calc/exp_calc_models.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/exp_calc/ship_exp_table.dart';

void main() {
  test(
    'route display groups consecutive points without losing repeats or order',
    () {
      expect(
        compactRouteSummary('5-2(C) + 5-2(F) + 5-2(K) + 5-2(I)'),
        '5-2（C+F+K+I）',
      );
      expect(compactRouteSummary('5-2(C) + 5-2(C)'), '5-2（C+C）');
      expect(
        compactRouteSummary('5-2(C) + 7-1(D) + 5-2(F)'),
        '5-2（C） + 7-1（D） + 5-2（F）',
      );
      expect(compactRouteSummary('5-2（C+F）'), '5-2（C+F）');
      expect(compactRouteSummary('custom legacy value'), 'custom legacy value');
    },
  );
  group('ShipExpTable', () {
    test(
      'verifies standard cumulative experience matching KanColle mechanics',
      () {
        expect(shipCumulativeExp(1), 0);
        expect(shipCumulativeExp(2), 100);
        expect(shipCumulativeExp(99), 1000000);
        expect(shipCumulativeExp(186), 17200000);
        expect(shipCumulativeExp(187), 18600000);
        expect(shipCumulativeExp(188), 20200000);
        expect(shipCumulativeExp(200), 20200000); // Clamped
      },
    );

    test('verifies levelForExp calculation', () {
      expect(levelForExp(0), 1);
      expect(levelForExp(99), 1);
      expect(levelForExp(100), 2);
      expect(levelForExp(17635281), 186);
      expect(levelForExp(18600000), 187);
      expect(levelForExp(20200000), 188);
    });
  });

  group('Exp Calculations', () {
    test(
      'computes screenshot scenario exactly: 5-2 S Flagship MVP base 150',
      () {
        // Base: 150
        // MVP: x2 -> 300
        // Flagship: x1.5 -> (300 * 3) / 2 = 450
        // Rank S: x1.2 -> (450 * 6) / 5 = 540
        final mapExp = computeMapExp(
          baseExp: 150,
          rank: BattleRank.s,
          isFlagship: true,
          isMvp: true,
        );
        expect(mapExp, 540);

        const currentExp = 17635281;
        const targetExp = 18600000;
        final remainExp = targetExp - currentExp;
        expect(remainExp, 964719);

        final battleCount = computeBattleCount(
          remainExp: remainExp,
          mapExp: mapExp,
        );
        expect(battleCount, 1787);
      },
    );

    test('computes rank C/D modifiers with integer truncation', () {
      // Base: 100, no MVP, no Flagship
      // Rank C: 100 * 8 / 10 = 80
      // Rank D: 100 * 7 / 10 = 70
      expect(
        computeMapExp(
          baseExp: 100,
          rank: BattleRank.c,
          isFlagship: false,
          isMvp: false,
        ),
        80,
      );
      expect(
        computeMapExp(
          baseExp: 100,
          rank: BattleRank.d,
          isFlagship: false,
          isMvp: false,
        ),
        70,
      );
    });

    test('computeBattleCount handles zero or negative remainExp', () {
      expect(computeBattleCount(remainExp: 0, mapExp: 540), 0);
      expect(computeBattleCount(remainExp: -100, mapExp: 540), 0);
    });
  });

  group('Map Database and Sortie Node Planning', () {
    test('SortieNodePlan computes experience correctly per node', () {
      final node = SortieNodePlan(
        id: 'node-1',
        mapId: '7-1',
        nodeId: 'G',
        baseExp: 870,
        rank: BattleRank.s,
        isFlagship: true,
        isMvp: true,
      );
      // Base: 870 -> MVP x2: 1740 -> Flagship x1.5: 2610 -> Rank S x1.2: 3132
      expect(node.computeExp(), 3132);
    });
  });

  group('ExpCalcTrackItem', () {
    test('resolves dynamic levels and remaining battles against GameState', () {
      const shipInstanceId = 42;
      const initialExp = 17635281;
      const targetExp = 18600000;
      const mapExp = 540;

      final item = ExpCalcTrackItem(
        id: 'track-1',
        shipInstanceId: shipInstanceId,
        shipMasterId: 546,
        shipName: '武藏改二',
        targetLevel: 187,
        targetExp: targetExp,
        map: '5-2',
        rank: BattleRank.s,
        isFlagship: true,
        isMvp: true,
        baseExp: 150,
        mapExp: mapExp,
        recordedLevel: 186,
        recordedExp: initialExp,
      );

      final stateInitial = GameState(
        memberId: 1,
        ships: {
          shipInstanceId: const OwnedShip(
            id: shipInstanceId,
            masterId: 546,
            level: 186,
            experience: initialExp,
          ),
        },
      );

      expect(item.resolveCurrentLevel(stateInitial), 186);
      expect(item.resolveCurrentExp(stateInitial), initialExp);
      expect(item.resolveRemainExp(stateInitial), 964719);
      expect(item.resolveBattleCount(stateInitial), 1787);
      expect(item.isCompleted(stateInitial), isFalse);

      // Ship gained experience and leveled up!
      final stateProgress = GameState(
        memberId: 1,
        ships: {
          shipInstanceId: const OwnedShip(
            id: shipInstanceId,
            masterId: 546,
            level: 187,
            experience: 18600100,
          ),
        },
      );

      expect(item.resolveCurrentLevel(stateProgress), 187);
      expect(item.resolveCurrentExp(stateProgress), 18600100);
      expect(item.resolveRemainExp(stateProgress), 0);
      expect(item.resolveBattleCount(stateProgress), 0);
      expect(item.isCompleted(stateProgress), isTrue);
    });

    test(
      'serializes and deserializes multi-node route track items losslessly',
      () {
        final item = ExpCalcTrackItem(
          id: 'track-multi',
          shipInstanceId: 101,
          shipMasterId: 131,
          shipName: '大和改二',
          targetLevel: 99,
          targetExp: 1000000,
          map: '7-1',
          rank: BattleRank.s,
          isFlagship: true,
          isMvp: false,
          baseExp: 870,
          mapExp: 1566,
          recordedLevel: 80,
          recordedExp: 369400,
          routeSummary: '7-1(D点) + 7-1(G点)',
          totalSortieExp: 3078,
        );

        final json = item.toJson();
        final restored = ExpCalcTrackItem.fromJson(json);

        expect(restored.id, item.id);
        expect(restored.shipInstanceId, item.shipInstanceId);
        expect(restored.shipName, item.shipName);
        expect(restored.targetLevel, item.targetLevel);
        expect(restored.map, item.map);
        expect(restored.rank, item.rank);
        expect(restored.isFlagship, item.isFlagship);
        expect(restored.isMvp, item.isMvp);
        expect(restored.baseExp, item.baseExp);
        expect(restored.mapExp, item.mapExp);
        expect(restored.routeSummary, '7-1(D点) + 7-1(G点)');
        expect(restored.totalSortieExp, 3078);
        expect(restored.effectiveSortieExp, 3078);
      },
    );
  });
}
