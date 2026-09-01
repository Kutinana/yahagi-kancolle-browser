import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/development/development_dataset.dart';
import 'package:yahagi_kancolle_browser/src/development/development_recipe_calculator.dart';
import 'package:yahagi_kancolle_browser/src/development/development_resources.dart';

void main() {
  final equipment = <int, DevelopmentEquipmentRecord>{
    7: const DevelopmentEquipmentRecord(
      id: 7,
      name: '主炮',
      typeId: 1,
      minimumResources: DevelopmentResources(10, 20, 30, 40),
    ),
    8: const DevelopmentEquipmentRecord(
      id: 8,
      name: '副炮',
      typeId: 4,
      minimumResources: DevelopmentResources(20, 10, 40, 10),
    ),
    168: const DevelopmentEquipmentRecord(
      id: 168,
      name: '九六式陸攻',
      typeId: 47,
      minimumResources: DevelopmentResources(20, 30, 10, 110),
    ),
  };

  test(
    '96 land attacker applies its domain minimum before pool adjustment',
    () {
      expect(
        deriveMinimumRecipes(DevelopmentPoolType.bauxite, const {
          168,
        }, equipment),
        [const DevelopmentResources(240, 260, 10, 261)],
      );
    },
  );

  test(
    'fuel-steel pool emits both minimum candidates when neither dominates',
    () {
      expect(
        deriveMinimumRecipes(DevelopmentPoolType.fuelSteel, const {
          7,
        }, equipment),
        [
          const DevelopmentResources(40, 20, 30, 40),
          const DevelopmentResources(10, 20, 40, 40),
        ],
      );
    },
  );

  test(
    'recipe evaluation separates target, affordable other and failure rates',
    () {
      final result = evaluateDevelopmentRecipe(
        poolKey: 'base#3',
        poolType: DevelopmentPoolType.fuelSteel,
        resources: const DevelopmentResources(10, 20, 30, 40),
        dropRates: const {7: 2, 8: 4, 168: 1},
        targets: const {7},
        equipment: equipment,
      );

      expect(result.targetRate, 2);
      expect(result.failureRate, 98); // 8 and 168 are not affordable.
    },
  );

  test('display sorting follows rate, resource threshold and failure rate', () {
    const a = DevelopmentRecipeResult(
      poolKey: 'a',
      poolType: DevelopmentPoolType.bauxite,
      resources: DevelopmentResources(10, 10, 10, 10),
      targetRate: 2,
      failureRate: 80,
    );
    const b = DevelopmentRecipeResult(
      poolKey: 'b',
      poolType: DevelopmentPoolType.bauxite,
      resources: DevelopmentResources(10, 10, 10, 11),
      targetRate: 2,
      failureRate: 90,
    );
    expect(sortDevelopmentRecipes([a, b]).map((item) => item.poolKey), [
      'b',
      'a',
    ]);
  });
}
