import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/improvement/improvement_dataset.dart';
import 'package:yahagi_kancolle_browser/src/improvement/improvement_projection.dart';
import 'package:yahagi_kancolle_browser/src/inventory/owned_inventory_projection.dart';

const _emptyStage = ImprovementStageCost(
  developmentMin: 0,
  developmentMax: 0,
  improvementMin: 0,
  improvementMax: 0,
  items: <ImprovementConsumeItem>[],
);

void main() {
  final dataset = ImprovementDataset(
    version: const ImprovementDatasetVersion(
      dataVersion: 'test',
      commitSha: '',
    ),
    entries: <ImprovementEntry>[
      _entry(1, evolvable: true),
      _entry(2, evolvable: false),
      _entry(3, evolvable: true),
      _entry(4, evolvable: true, evolutionAvailableToday: false),
    ],
  );
  const equipmentMasters = <int, MasterSlotItem>{
    1: MasterSlotItem(id: 1, name: 'Alpha Gun', type: <int>[1, 0, 1, 1]),
    2: MasterSlotItem(id: 2, name: 'Beta Torpedo', type: <int>[2, 0, 5, 5]),
    3: MasterSlotItem(id: 3, name: 'Gamma Gun', type: <int>[1, 0, 1, 1]),
    4: MasterSlotItem(id: 4, name: 'Delta Radar', type: <int>[0, 0, 12, 11]),
  };

  test('filters daily rows by evolvable state', () {
    expect(
      projectImprovementRows(
        dataset,
        weekday: DateTime.monday,
        evolutionFilter: ImprovementEvolutionFilter.all,
      ).map((row) => row.entry.equipmentId),
      <int>[1, 2, 3, 4],
    );
    expect(
      projectImprovementRows(
        dataset,
        weekday: DateTime.monday,
        evolutionFilter: ImprovementEvolutionFilter.evolvable,
      ).map((row) => row.entry.equipmentId),
      <int>[1, 3],
    );
    expect(
      projectImprovementRows(
        dataset,
        weekday: DateTime.monday,
        evolutionFilter: ImprovementEvolutionFilter.notEvolvable,
      ).map((row) => row.entry.equipmentId),
      <int>[2, 4],
    );
  });

  test('combines favorite-only and evolution filters', () {
    final rows = projectImprovementRows(
      dataset,
      weekday: DateTime.monday,
      favoriteEquipmentIds: const <int>{2, 3},
      favoritesOnly: true,
      evolutionFilter: ImprovementEvolutionFilter.evolvable,
    );
    expect(rows.map((row) => row.entry.equipmentId), <int>[3]);
  });

  test('searches equipment names with trimmed case-insensitive text', () {
    final rows = projectImprovementRows(
      dataset,
      weekday: DateTime.monday,
      equipmentMasters: equipmentMasters,
      query: ' beta ',
    );

    expect(rows.map((row) => row.entry.equipmentId), <int>[2]);
  });

  test('uses owned inventory equipment categories', () {
    final rows = projectImprovementRows(
      dataset,
      weekday: DateTime.monday,
      equipmentMasters: equipmentMasters,
      equipmentCategory: EquipmentInventoryCategory.mainGun,
    );

    expect(rows.map((row) => row.entry.equipmentId), <int>[1, 3]);
  });

  test('combines search category and evolution filters', () {
    final rows = projectImprovementRows(
      dataset,
      weekday: DateTime.monday,
      equipmentMasters: equipmentMasters,
      query: 'gamma',
      equipmentCategory: EquipmentInventoryCategory.mainGun,
      evolutionFilter: ImprovementEvolutionFilter.evolvable,
    );

    expect(rows.map((row) => row.entry.equipmentId), <int>[3]);
  });

  test('all weekdays keeps one row and merges weekdays per secretary', () {
    final allWeekdaysDataset = ImprovementDataset(
      version: const ImprovementDatasetVersion(
        dataVersion: 'test',
        commitSha: '',
      ),
      entries: <ImprovementEntry>[_multiWeekdayEntry(evolvable: false)],
    );

    final rows = projectImprovementRows(
      allWeekdaysDataset,
      weekday: improvementAllWeekdays,
    );

    expect(rows, hasLength(1));
    expect(rows.single.secretaryLabels, <String>['明石①⑤', '夕张①②③④⑤⑥⑦']);
  });

  test('specific weekday keeps secretary labels without weekday suffix', () {
    final rows = projectImprovementRows(
      ImprovementDataset(
        version: const ImprovementDatasetVersion(
          dataVersion: 'test',
          commitSha: '',
        ),
        entries: <ImprovementEntry>[_multiWeekdayEntry(evolvable: false)],
      ),
      weekday: DateTime.friday,
    );

    expect(rows.single.secretaryLabels, <String>['明石', '夕张']);
  });

  test('resolves numeric secretary labels by ship sort number', () {
    final rows = projectImprovementRows(
      ImprovementDataset(
        version: const ImprovementDatasetVersion(
          dataVersion: 'test',
          commitSha: '',
        ),
        entries: <ImprovementEntry>[
          ImprovementEntry(
            equipmentId: 10,
            baseCost: const ImprovementResourceCost(
              fuel: 0,
              ammo: 0,
              steel: 0,
              bauxite: 0,
            ),
            arrangements: <ImprovementArrangement>[
              ImprovementArrangement(
                secretaryId: 444,
                secretaryLabel: '#444',
                weekdays: Set<int>.unmodifiable(<int>{DateTime.monday}),
              ),
              ImprovementArrangement(
                secretaryId: 1,
                secretaryLabel: '明石',
                weekdays: Set<int>.unmodifiable(<int>{DateTime.monday}),
              ),
              ImprovementArrangement(
                secretaryId: 999,
                secretaryLabel: '#999',
                weekdays: Set<int>.unmodifiable(<int>{DateTime.monday}),
              ),
              ImprovementArrangement(
                secretaryId: 444,
                secretaryLabel: '#444改',
                weekdays: Set<int>.unmodifiable(<int>{DateTime.monday}),
              ),
            ],
            stage0: _emptyStage,
            stage1: _emptyStage,
            upgrades: const <ImprovementUpgrade>[],
          ),
        ],
      ),
      weekday: DateTime.monday,
      shipMasters: const <int, MasterShip>{
        444: MasterShip(id: 444, name: 'Aquila', shipTypeId: 11, sortNo: 244),
        644: MasterShip(id: 644, name: '桃', shipTypeId: 2, sortNo: 444),
      },
    );

    expect(rows.single.secretaryLabels, <String>['桃', '明石', '#999', '#444改']);
    expect(rows.single.secretaryLabels, isNot(contains('#444')));
    expect(rows.single.secretaryLabels, isNot(contains('Aquila')));
  });

  test('keeps numeric secretary label when ship sort number is ambiguous', () {
    final rows = projectImprovementRows(
      ImprovementDataset(
        version: const ImprovementDatasetVersion(
          dataVersion: 'test',
          commitSha: '',
        ),
        entries: <ImprovementEntry>[_secretaryEntry('#444', 444)],
      ),
      weekday: DateTime.monday,
      shipMasters: const <int, MasterShip>{
        644: MasterShip(id: 644, name: '桃', shipTypeId: 2, sortNo: 444),
        645: MasterShip(id: 645, name: '桃改', shipTypeId: 2, sortNo: 444),
      },
    );

    expect(rows.single.secretaryLabels, <String>['#444']);
  });

  test('keeps oversized numeric secretary label without throwing', () {
    const label = '#999999999999999999999999999999999999999999999999999999';
    final rows = projectImprovementRows(
      ImprovementDataset(
        version: const ImprovementDatasetVersion(
          dataVersion: 'test',
          commitSha: '',
        ),
        entries: <ImprovementEntry>[_secretaryEntry(label, null)],
      ),
      weekday: DateTime.monday,
    );

    expect(rows.single.secretaryLabels, <String>[label]);
  });

  test('all weekdays is evolvable when any weekday has a valid route', () {
    final rows = projectImprovementRows(
      ImprovementDataset(
        version: const ImprovementDatasetVersion(
          dataVersion: 'test',
          commitSha: '',
        ),
        entries: <ImprovementEntry>[_multiWeekdayEntry(evolvable: true)],
      ),
      weekday: improvementAllWeekdays,
      evolutionFilter: ImprovementEvolutionFilter.evolvable,
    );

    expect(rows, hasLength(1));
    expect(rows.single.upgradeRoutes.single.secretaryLabels, <String>[
      '明石①⑤',
      '夕张①②③④⑤⑥⑦',
    ]);
  });

  test('all weekdays combines search category favorite and evolution', () {
    const allEquipmentMasters = <int, MasterSlotItem>{
      10: MasterSlotItem(id: 10, name: 'Weekly Gun', type: <int>[1, 0, 1, 1]),
    };
    final rows = projectImprovementRows(
      ImprovementDataset(
        version: const ImprovementDatasetVersion(
          dataVersion: 'test',
          commitSha: '',
        ),
        entries: <ImprovementEntry>[_multiWeekdayEntry(evolvable: true)],
      ),
      weekday: improvementAllWeekdays,
      equipmentMasters: allEquipmentMasters,
      query: ' weekly ',
      equipmentCategory: EquipmentInventoryCategory.mainGun,
      favoriteEquipmentIds: const <int>{10},
      favoritesOnly: true,
      evolutionFilter: ImprovementEvolutionFilter.evolvable,
    );

    expect(rows.map((row) => row.entry.equipmentId), <int>[10]);
  });
}

ImprovementEntry _secretaryEntry(String label, int? id) => ImprovementEntry(
  equipmentId: 10,
  baseCost: const ImprovementResourceCost(
    fuel: 0,
    ammo: 0,
    steel: 0,
    bauxite: 0,
  ),
  arrangements: <ImprovementArrangement>[
    ImprovementArrangement(
      secretaryId: id,
      secretaryLabel: label,
      weekdays: Set<int>.unmodifiable(<int>{DateTime.monday}),
    ),
  ],
  stage0: _emptyStage,
  stage1: _emptyStage,
  upgrades: const <ImprovementUpgrade>[],
);

ImprovementEntry _multiWeekdayEntry({required bool evolvable}) =>
    ImprovementEntry(
      equipmentId: 10,
      baseCost: const ImprovementResourceCost(
        fuel: 0,
        ammo: 0,
        steel: 0,
        bauxite: 0,
      ),
      arrangements: <ImprovementArrangement>[
        ImprovementArrangement(
          secretaryId: 1,
          secretaryLabel: '明石',
          weekdays: Set<int>.unmodifiable(<int>{DateTime.friday}),
        ),
        ImprovementArrangement(
          secretaryId: 1,
          secretaryLabel: '明石',
          weekdays: Set<int>.unmodifiable(<int>{DateTime.monday}),
        ),
        ImprovementArrangement(
          secretaryId: 2,
          secretaryLabel: '夕张',
          weekdays: Set<int>.unmodifiable(<int>{
            DateTime.monday,
            DateTime.tuesday,
            DateTime.wednesday,
            DateTime.thursday,
            DateTime.friday,
            DateTime.saturday,
            DateTime.sunday,
          }),
        ),
      ],
      stage0: _emptyStage,
      stage1: _emptyStage,
      upgrades: evolvable
          ? const <ImprovementUpgrade>[
              ImprovementUpgrade(
                targetEquipmentId: 110,
                developmentMin: 0,
                developmentMax: 0,
                improvementMin: 0,
                improvementMax: 0,
                items: <ImprovementConsumeItem>[],
              ),
            ]
          : const <ImprovementUpgrade>[],
    );

ImprovementEntry _entry(
  int id, {
  required bool evolvable,
  bool evolutionAvailableToday = true,
}) => ImprovementEntry(
  equipmentId: id,
  baseCost: const ImprovementResourceCost(
    fuel: 0,
    ammo: 0,
    steel: 0,
    bauxite: 0,
  ),
  arrangements: <ImprovementArrangement>[
    ImprovementArrangement(
      secretaryId: 1,
      secretaryLabel: '秘书舰',
      weekdays: Set<int>.unmodifiable(<int>{DateTime.monday}),
      routeKind: evolutionAvailableToday ? null : 'kind1',
    ),
  ],
  stage0: _emptyStage,
  stage1: _emptyStage,
  upgrades: evolvable
      ? <ImprovementUpgrade>[
          ImprovementUpgrade(
            targetEquipmentId: id + 100,
            developmentMin: 0,
            developmentMax: 0,
            improvementMin: 0,
            improvementMax: 0,
            items: const <ImprovementConsumeItem>[],
            routeKind: evolutionAvailableToday ? null : 'kind2',
          ),
        ]
      : const <ImprovementUpgrade>[],
);
