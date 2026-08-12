import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/improvement/improvement_dataset.dart';
import 'package:yahagi_kancolle_browser/src/improvement/improvement_raw_bundle.dart';

void main() {
  Map<String, String> fixture({bool complete = true}) => <String, String>{
    'data_manifest.json': jsonEncode(<String, Object>{
      'data_version': '2026.07.10',
      'version_complete': complete,
      'files': ImprovementRawBundle.dataFiles,
    }),
    'equip_base_cost.json': jsonEncode(<Object>[
      <String, Object>{
        'id': 1,
        'consume_fuel': 10,
        'consume_ammo': 20,
        'consume_steel': 30,
        'consume_bauxite': 40,
      },
    ]),
    'equipment_upgrade_path.json': jsonEncode(<Object>[
      <String, Object>{
        'id': '1|293|1>293',
        'from_equipment_id': 1,
        'to_equipment_id': 293,
        'equipment_path': <int>[1, 293],
        'step_count': 1,
      },
    ]),
    'improvement_arrangement.json': jsonEncode(<Object>[
      <String, Object?>{
        'id': '1|31|-|睦月|all|1111111',
        'equipment_id': 1,
        'secretary_id': 31,
        'secretary_variant': null,
        'secretary_label': '睦月',
        'route_kind': null,
        'sunday': true,
        'monday': true,
        'tuesday': true,
        'wednesday': true,
        'thursday': true,
        'friday': true,
        'saturday': true,
        'note': null,
      },
    ]),
    'improvement_consume_item.json': jsonEncode(<Object>[
      <String, Object?>{
        'id': '1_0|equipment|2|-|-',
        'step_id': '1_0',
        'item_equipment_id': 2,
        'item_material_key': null,
        'count': 1,
      },
      <String, Object?>{
        'id': '1_1|equipment|3|-|-',
        'step_id': '1_1',
        'item_equipment_id': 3,
        'item_material_key': null,
        'count': 2,
      },
    ]),
    'improvement_consume_step.json': jsonEncode(<Object>[
      <String, Object>{
        'id': '1_0',
        'equipment_id': 1,
        'step_id': 0,
        'consume_development_min': 2,
        'consume_development_max': 2,
        'consume_improvement_min': 1,
        'consume_improvement_max': 2,
      },
      <String, Object>{
        'id': '1_1',
        'equipment_id': 1,
        'step_id': 1,
        'consume_development_min': 3,
        'consume_development_max': 4,
        'consume_improvement_min': 2,
        'consume_improvement_max': 3,
      },
    ]),
    'improvement_upgrade_cost.json': jsonEncode(<Object>[
      <String, Object?>{
        'id': '1|293|equipment|4',
        'equipment_id': 1,
        'upgrade_id': 293,
        'item_equipment_id': 4,
        'item_material_key': null,
        'count': 1,
      },
    ]),
    'improvement_upgrade_target.json': jsonEncode(<Object>[
      <String, Object?>{
        'id': '1|293|all',
        'equipment_id': 1,
        'upgrade_id': 293,
        'route_kind': null,
        'consume_development_min': 4,
        'consume_development_max': 5,
        'consume_improvement_min': 6,
        'consume_improvement_max': 7,
      },
    ]),
    'material.json': jsonEncode(<Object>[
      <String, Object>{'key': 'ActionReport', 'name': '战斗详报'},
    ]),
  };

  test('joins the remote relational files into one equipment entry', () {
    final dataset = ImprovementRawBundle.parse(
      fixture(),
      commitSha: 'a' * 40,
    ).normalize();

    expect(dataset.version.dataVersion, '2026.07.10');
    expect(dataset.version.commitSha, 'a' * 40);
    expect(dataset.entries, hasLength(1));
    final entry = dataset.entries.single;
    expect(entry.baseCost.fuel, 10);
    expect(entry.arrangements.single.secretaryLabel, '睦月');
    expect(entry.arrangements.single.weekdays, <int>{1, 2, 3, 4, 5, 6, 7});
    expect(entry.stage0.single.equipmentId, 2);
    expect(entry.stage1.single.count, 2);
    expect(entry.upgrades.single.targetEquipmentId, 293);
    expect(entry.upgrades.single.items.single.equipmentId, 4);
  });

  test('keeps the upstream display name for material consumption', () {
    final files = fixture();
    final upgradeCosts =
        jsonDecode(files['improvement_upgrade_cost.json']!) as List<Object?>;
    upgradeCosts.first = <String, Object?>{
      'id': '1|293|material|ActionReport',
      'equipment_id': 1,
      'upgrade_id': 293,
      'item_equipment_id': null,
      'item_material_key': 'ActionReport',
      'count': 1,
    };
    files['improvement_upgrade_cost.json'] = jsonEncode(upgradeCosts);

    final item = ImprovementRawBundle.parse(
      files,
    ).normalize().entries.single.upgrades.single.items.single;
    expect(item.materialKey, 'ActionReport');
    expect(item.materialName, '战斗详报');
  });

  test('rejects an incomplete manifest', () {
    expect(
      () => ImprovementRawBundle.parse(fixture(complete: false)),
      throwsFormatException,
    );
  });

  test('rejects unknown files, duplicate keys and broken foreign keys', () {
    final unknown = fixture()..['extra.json'] = '[]';
    expect(() => ImprovementRawBundle.parse(unknown), throwsFormatException);

    final duplicate = fixture();
    final base =
        jsonDecode(duplicate['equip_base_cost.json']!) as List<Object?>;
    duplicate['equip_base_cost.json'] = jsonEncode(<Object?>[
      ...base,
      base.first,
    ]);
    expect(() => ImprovementRawBundle.parse(duplicate), throwsFormatException);

    final broken = fixture();
    final items =
        jsonDecode(broken['improvement_consume_item.json']!) as List<Object?>;
    (items.first! as Map<String, Object?>)['step_id'] = 'missing';
    broken['improvement_consume_item.json'] = jsonEncode(items);
    expect(() => ImprovementRawBundle.parse(broken), throwsFormatException);
  });

  test('rejects negative resource values', () {
    final files = fixture();
    final costs = jsonDecode(files['equip_base_cost.json']!) as List<Object?>;
    (costs.first! as Map<String, Object?>)['consume_fuel'] = -1;
    files['equip_base_cost.json'] = jsonEncode(costs);
    expect(() => ImprovementRawBundle.parse(files), throwsFormatException);
  });

  test('loads a complete embedded offline snapshot', () async {
    final source = await File(
      'assets/data/improvement/planner_snapshot.json',
    ).readAsString();
    final dataset = ImprovementDataset.parse(source);
    expect(dataset.entries.length, greaterThan(300));
    expect(dataset.version.commitSha, hasLength(40));
  });
}
