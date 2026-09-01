import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/development/development_dataset.dart';
import 'package:yahagi_kancolle_browser/src/development/development_projection.dart';
import 'package:yahagi_kancolle_browser/src/development/development_resources.dart';

void main() {
  const equipment = <int, DevelopmentEquipmentRecord>{
    7: DevelopmentEquipmentRecord(
      id: 7,
      name: '目标',
      typeId: 1,
      minimumResources: DevelopmentResources(10, 10, 10, 10),
    ),
    8: DevelopmentEquipmentRecord(
      id: 8,
      name: '资源不足',
      typeId: 1,
      minimumResources: DevelopmentResources(20, 20, 20, 20),
    ),
    9: DevelopmentEquipmentRecord(
      id: 9,
      name: '陪跑',
      typeId: 1,
      minimumResources: DevelopmentResources(10, 10, 10, 10),
    ),
  };

  test('zero total is replaced before affordability and target checks', () {
    final groups = projectDevelopmentEquipment(
      totals: const {7: 0, 8: 2, 9: 3},
      details: const {
        7: [2, -2],
        8: [2],
        9: [3],
      },
      targets: const {7},
      resources: const DevelopmentResources(10, 10, 10, 10),
      equipment: equipment,
    );

    expect(groups.replaced.single.id, 7);
    expect(groups.replaced.single.rateDetails, [2, -2]);
    expect(groups.insufficient.single.id, 8);
    expect(groups.other.single.id, 9);
    expect(groups.targets, isEmpty);
  });

  test('positive affordable target appears in the target group', () {
    final groups = projectDevelopmentEquipment(
      totals: const {7: 2},
      details: const {
        7: [2],
      },
      targets: const {7},
      resources: const DevelopmentResources(10, 10, 10, 10),
      equipment: equipment,
    );
    expect(groups.targets.single.id, 7);
  });

  test(
    'enabled set keeps zero-rate keys but requires positive selected targets',
    () async {
      final dataset = DevelopmentDataset.fromJsonString(
        await File(
          'assets/data/development/development_snapshot.json',
        ).readAsString(),
      );

      final all = calculateEnabledDevelopmentEquipment(dataset, const {});
      final withLandAttacker = calculateEnabledDevelopmentEquipment(
        dataset,
        const {168},
      );
      expect(all, contains(168));
      expect(withLandAttacker, contains(168));
      expect(withLandAttacker.length, lessThan(all.length));
    },
  );
}
