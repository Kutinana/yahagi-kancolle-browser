import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/fleet/equipment_type_icon.dart';
import 'package:yahagi_kancolle_browser/src/fleet/ship_portrait.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/inventory/owned_inventory_projection.dart';
import 'package:yahagi_kancolle_browser/src/inventory/ship_equipment_compatibility_drawer.dart';

const _ship = MasterShip(
  id: 100,
  name: '矢矧改二乙',
  shipTypeId: 3,
  classTypeId: 42,
  equipTypeIds: <int>{1, 6, 15, 29},
  limitedEquipmentIdsByType: <int, Set<int>>{
    29: <int>{999},
  },
);

void main() {
  const ownedShip = OwnedShip(id: 500, masterId: 100, level: 98);

  testWidgets(
    'renders header, grouped owned equipment, counts and slot labels',
    (tester) async {
      await _pumpDrawer(tester, ownedShip: ownedShip);

      expect(
        find.byKey(const Key('ship-equipment-compatibility-drawer')),
        findsOneWidget,
      );
      expect(find.text('矢矧改二乙'), findsOneWidget);
      expect(find.textContaining('轻巡洋舰'), findsOneWidget);
      expect(find.textContaining('Lv.98'), findsOneWidget);
      expect(find.byType(ShipPortrait), findsOneWidget);
      expect(find.text('持有 3'), findsOneWidget);
      expect(find.text('全部 5'), findsOneWidget);
      expect(
        find.byKey(const Key('ship-equipment-compatibility-group-1')),
        findsOneWidget,
      );
      expect(find.text('小口径主炮'), findsOneWidget);
      expect(
        find.byKey(const Key('ship-equipment-compatibility-equipment-10')),
        findsOneWidget,
      );
      expect(find.text('Alpha Gun'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(
            const Key('ship-equipment-compatibility-equipment-10'),
          ),
          matching: find.byType(EquipmentTypeIconImage),
        ),
        findsOneWidget,
      );
      expect(find.text('普通槽'), findsWidgets);
      expect(find.text('普通槽＋增设栏'), findsOneWidget);
      final ownedCount = find.byKey(
        const Key('ship-equipment-compatibility-owned-count-10'),
      );
      expect(
        find.descendant(of: ownedCount, matching: find.text('持有 X3')),
        findsOneWidget,
      );
      expect(tester.widget<Align>(ownedCount).alignment, Alignment.centerRight);
    },
  );

  testWidgets('does not invent a level for an unowned ship', (tester) async {
    await _pumpDrawer(tester);
    expect(find.textContaining('Lv.'), findsNothing);
  });

  testWidgets('category dialog has all categories and applies immediately', (
    tester,
  ) async {
    await _pumpDrawer(tester);
    await tester.tap(
      find.byKey(const Key('ship-equipment-compatibility-category-button')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('ship-equipment-compatibility-category-dialog')),
      findsOneWidget,
    );
    for (final category in EquipmentInventoryCategory.values) {
      expect(
        find.byKey(
          Key('ship-equipment-compatibility-category-${category.name}'),
        ),
        findsOneWidget,
      );
    }
    const expectedLabels = <String>[
      '全部',
      '主炮',
      '副炮／高角炮',
      '机枪',
      '鱼雷／甲标',
      '舰载机',
      '水上机',
      '陆航',
      '对潜',
      '电探',
      '登陆／运输',
      '辅助／其他',
    ];
    final dialog = find.byKey(
      const Key('ship-equipment-compatibility-category-dialog'),
    );
    for (final label in expectedLabels) {
      expect(
        find.descendant(of: dialog, matching: find.text(label)),
        findsOneWidget,
      );
    }
    expect(find.text('重置'), findsNothing);
    expect(find.text('完成'), findsNothing);

    await tester.tap(
      find.byKey(
        const Key('ship-equipment-compatibility-category-carrierAircraft'),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('ship-equipment-compatibility-category-dialog')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('ship-equipment-compatibility-equipment-20')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('ship-equipment-compatibility-equipment-10')),
      findsNothing,
    );
  });

  testWidgets('searches by equipment name', (tester) async {
    await _pumpDrawer(tester);
    await tester.tap(
      find.byKey(const Key('ship-equipment-compatibility-search-button')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('ship-equipment-compatibility-search-dialog')),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const Key('ship-equipment-compatibility-search-dialog-field')),
      'Alpha',
    );
    await tester.tap(
      find.byKey(
        const Key('ship-equipment-compatibility-search-dialog-confirm'),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('ship-equipment-compatibility-equipment-10')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('ship-equipment-compatibility-equipment-20')),
      findsNothing,
    );
  });

  testWidgets('scope switch preserves category, query and slot filter', (
    tester,
  ) async {
    await _pumpDrawer(tester);
    await tester.tap(
      find.byKey(const Key('ship-equipment-compatibility-category-button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('ship-equipment-compatibility-category-mainGun')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('ship-equipment-compatibility-search-button')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('ship-equipment-compatibility-search-dialog-field')),
      'Gun',
    );
    await tester.tap(
      find.byKey(
        const Key('ship-equipment-compatibility-search-dialog-confirm'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('ship-equipment-compatibility-filter-regular')),
    );
    await tester.pump();
    expect(
      find.byKey(const Key('ship-equipment-compatibility-equipment-11')),
      findsNothing,
    );

    await tester.tap(
      find.byKey(const Key('ship-equipment-compatibility-tab-all')),
    );
    await tester.pump();
    expect(
      find.byKey(const Key('ship-equipment-compatibility-equipment-11')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('ship-equipment-compatibility-equipment-20')),
      findsNothing,
    );
    expect(
      tester
          .widget<Semantics>(
            find
                .descendant(
                  of: find.byKey(
                    const Key('ship-equipment-compatibility-filter-regular'),
                  ),
                  matching: find.byType(Semantics),
                )
                .first,
          )
          .properties
          .selected,
      isTrue,
    );
  });

  testWidgets('expansion filter shows expansion rows and improvement rule', (
    tester,
  ) async {
    await _pumpDrawer(tester);
    await tester.tap(
      find.byKey(const Key('ship-equipment-compatibility-tab-all')),
    );
    await tester.tap(
      find.byKey(const Key('ship-equipment-compatibility-filter-expansion')),
    );
    await tester.pump();
    expect(
      find.byKey(const Key('ship-equipment-compatibility-equipment-30')),
      findsOneWidget,
    );
    final expansionRow = find.byKey(
      const Key('ship-equipment-compatibility-equipment-30'),
    );
    expect(
      find.descendant(of: expansionRow, matching: find.text('增设栏')),
      findsOneWidget,
    );
    expect(find.text('增设栏需 ★+4'), findsOneWidget);
    expect(
      find.byKey(const Key('ship-equipment-compatibility-equipment-10')),
      findsNothing,
    );
  });

  testWidgets('close button and Escape invoke onClose', (tester) async {
    var closes = 0;
    await _pumpDrawer(tester, onClose: () => closes++);
    await tester.tap(
      find.byKey(const Key('ship-equipment-compatibility-close')),
    );
    expect(closes, 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    expect(closes, 2);
  });

  testWidgets('shows rule waiting state instead of empty result', (
    tester,
  ) async {
    await _pumpDrawer(tester, state: _state(hasRules: false));
    expect(find.text('装备规则数据等待更新'), findsOneWidget);
    expect(find.text('没有找到可装备的装备'), findsNothing);
  });

  testWidgets('shows an empty result when ready rules match no equipment', (
    tester,
  ) async {
    await _pumpDrawer(tester);
    await tester.tap(
      find.byKey(const Key('ship-equipment-compatibility-search-button')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('ship-equipment-compatibility-search-dialog-field')),
      '不存在的装备',
    );
    await tester.tap(
      find.byKey(
        const Key('ship-equipment-compatibility-search-dialog-confirm'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('没有找到可装备的装备'), findsOneWidget);
    expect(find.text('装备规则数据等待更新'), findsNothing);
  });

  testWidgets('header and results share one scroll viewport', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 320);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await _pumpDrawer(tester);
    final drawer = find.byKey(const Key('ship-equipment-compatibility-drawer'));
    final scroll = find.descendant(
      of: drawer,
      matching: find.byKey(const Key('ship-equipment-compatibility-scroll')),
    );
    expect(scroll, findsOneWidget);
    expect(tester.widget(scroll), isA<CustomScrollView>());
    expect(
      find.descendant(of: drawer, matching: find.byType(Scrollable)),
      findsOneWidget,
    );
  });

  testWidgets('rebuilds projection when ship changes', (tester) async {
    final state = _state();
    await _pumpDrawer(tester, state: state);
    expect(
      find.byKey(const Key('ship-equipment-compatibility-equipment-10')),
      findsOneWidget,
    );
    const otherShip = MasterShip(
      id: 101,
      name: '利根改二',
      shipTypeId: 5,
      equipTypeIds: <int>{6},
    );
    await _pumpDrawer(tester, state: state, ship: otherShip);
    expect(
      find.byKey(const Key('ship-equipment-compatibility-equipment-10')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('ship-equipment-compatibility-equipment-20')),
      findsOneWidget,
    );
  });

  testWidgets('rebuilds projection when state changes', (tester) async {
    final initialState = _state();
    await _pumpDrawer(tester, state: initialState);
    expect(
      find.byKey(const Key('ship-equipment-compatibility-equipment-10')),
      findsOneWidget,
    );

    final replacementState = initialState.copyWith(
      masterSlotItems: const <int, MasterSlotItem>{
        50: MasterSlotItem(
          id: 50,
          name: 'Replacement Gun',
          sortNo: 1,
          type: <int>[1, 0, 1, 1],
        ),
      },
      slotItems: const <int, OwnedSlotItem>{
        5001: OwnedSlotItem(instanceId: 5001, masterSlotItemId: 50),
      },
    );
    await _pumpDrawer(tester, state: replacementState);

    expect(
      find.byKey(const Key('ship-equipment-compatibility-equipment-10')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('ship-equipment-compatibility-equipment-50')),
      findsOneWidget,
    );
  });
}

Future<void> _pumpDrawer(
  WidgetTester tester, {
  GameState? state,
  MasterShip ship = _ship,
  OwnedShip? ownedShip,
  VoidCallback? onClose,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('zh'),
      home: Scaffold(
        body: ShipEquipmentCompatibilityDrawer(
          state: state ?? _state(),
          ship: ship,
          ownedShip: ownedShip,
          onClose: onClose ?? () {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

GameState _state({bool hasRules = true}) => GameState(
  hasEquipmentCompatibilityData: hasRules,
  masterShips: const <int, MasterShip>{
    100: _ship,
    101: MasterShip(
      id: 101,
      name: '利根改二',
      shipTypeId: 5,
      equipTypeIds: <int>{6},
    ),
  },
  masterShipTypes: const <int, MasterShipType>{
    3: MasterShipType(id: 3, name: '轻巡洋舰'),
    5: MasterShipType(id: 5, name: '重巡洋舰'),
  },
  masterSlotItemTypes: const <int, String>{
    1: '小口径主炮',
    6: '舰上战斗机',
    15: '对空机枪',
    29: '探照灯',
  },
  masterSlotItems: const <int, MasterSlotItem>{
    10: MasterSlotItem(
      id: 10,
      name: 'Alpha Gun',
      sortNo: 10,
      type: <int>[1, 0, 1, 1],
    ),
    11: MasterSlotItem(
      id: 11,
      name: 'Beta Gun',
      sortNo: 20,
      type: <int>[1, 0, 1, 1],
    ),
    20: MasterSlotItem(
      id: 20,
      name: '零式舰战',
      sortNo: 30,
      type: <int>[3, 0, 6, 6],
    ),
    30: MasterSlotItem(
      id: 30,
      name: '特殊探照灯',
      sortNo: 40,
      type: <int>[8, 0, 29, 24],
    ),
    40: MasterSlotItem(
      id: 40,
      name: '集中配备机枪',
      sortNo: 50,
      type: <int>[1, 0, 15, 15],
    ),
  },
  slotItems: const <int, OwnedSlotItem>{
    1001: OwnedSlotItem(instanceId: 1001, masterSlotItemId: 10),
    1002: OwnedSlotItem(instanceId: 1002, masterSlotItemId: 10),
    1003: OwnedSlotItem(instanceId: 1003, masterSlotItemId: 10),
    2001: OwnedSlotItem(instanceId: 2001, masterSlotItemId: 20),
    4001: OwnedSlotItem(instanceId: 4001, masterSlotItemId: 40),
  },
  expansionSlotEquipmentTypeIds: const <int>{15},
  expansionSlotSpecialRules: const <int, ExpansionSlotSpecialRule>{
    30: ExpansionSlotSpecialRule(
      equipmentMasterId: 30,
      shipMasterIds: <int>{100},
      minimumImprovement: 4,
    ),
  },
);
