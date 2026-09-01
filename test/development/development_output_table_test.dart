import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/development/development_dataset.dart';
import 'package:yahagi_kancolle_browser/src/development/development_output_table.dart';
import 'package:yahagi_kancolle_browser/src/development/development_projection.dart';
import 'package:yahagi_kancolle_browser/src/development/development_resources.dart';

void main() {
  test('目标置顶且其他装备默认按最终概率降序排列', () {
    final output = visibleDevelopmentOutput(
      groups: DevelopmentEquipmentGroups(
        targets: [_projection(7, 4)],
        other: [_projection(8, 18), _projection(9, 6)],
        insufficient: [_projection(10, 30)],
        replaced: [_projection(11, 0)],
      ),
      targets: const {7},
      ascending: false,
    );

    expect(output.map((item) => item.id), [7, 8, 9]);
  });

  test('升序切换不影响目标置顶并以装备 ID 稳定排序', () {
    final output = visibleDevelopmentOutput(
      groups: DevelopmentEquipmentGroups(
        targets: [_projection(7, 4)],
        other: [_projection(9, 6), _projection(8, 6), _projection(12, 2)],
        insufficient: const [],
        replaced: const [],
      ),
      targets: const {7},
      ascending: true,
    );

    expect(output.map((item) => item.id), [7, 12, 8, 9]);
  });
}

DevelopmentEquipmentProjection _projection(int id, double rate) =>
    DevelopmentEquipmentProjection(
      equipment: DevelopmentEquipmentRecord(
        id: id,
        name: '装备 $id',
        typeId: id,
        minimumResources: const DevelopmentResources(10, 10, 10, 10),
      ),
      totalRate: rate,
      rateDetails: [rate],
    );
