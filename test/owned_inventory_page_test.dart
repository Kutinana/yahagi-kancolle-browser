import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_controller.dart';
import 'package:yahagi_kancolle_browser/src/inventory/owned_inventory_page.dart';
import 'package:yahagi_kancolle_browser/src/inventory/owned_inventory_projection.dart';
import 'package:yahagi_kancolle_browser/src/inventory/unowned_inventory_projection.dart';
import 'package:yahagi_kancolle_browser/src/new_ship/new_ship_reminder_controller.dart';
import 'package:yahagi_kancolle_browser/src/new_ship/new_ship_reminder_store.dart';
import 'package:yahagi_kancolle_browser/src/widgets/frozen_data_table.dart';

import 'fixtures/kcsapi_fixtures.dart';

void main() {
  setUp(() => GameStateController.disableTimerForTest = true);

  testWidgets(
    'unowned ship cards are flat and exclusions follow the active filter',
    (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1100, 700);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final controller = GameStateController();
      addTearDown(controller.dispose);
      controller
        ..accept(start2Event)
        ..accept(
          kcsapiEvent('/kcsapi/api_port/port', <String, Object?>{
            'api_basic': <String, Object?>{'api_member_id': 1001},
            'api_ship': <Object?>[],
          }),
        );
      await controller.idle;
      final reminderController = NewShipReminderController(
        stateProvider: () => controller.state,
        store: NewShipReminderStore(await SharedPreferences.getInstance()),
        onPublish: (_) {},
      );
      addTearDown(reminderController.dispose);
      await reminderController.setFamilyExcluded(101, true);

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          home: Scaffold(
            body: OwnedInventoryPage(
              controller: controller,
              reminderController: reminderController,
              showOwned: false,
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('unowned-ship-summary')), findsNothing);
      expect(find.byType(ExpansionTile), findsNothing);
      final excludedCount = find.byKey(
        const Key('unowned-ship-excluded-count'),
      );
      expect(excludedCount, findsOneWidget);
      expect(tester.widget<Text>(excludedCount).data, '1');
      expect(
        tester.widget<Text>(excludedCount).style?.color,
        const Color(0xffffc85a),
      );
      final clearExclusions = find.byKey(
        const Key('unowned-ship-clear-exclusions'),
      );
      expect(clearExclusions, findsOneWidget);
      final clearIcon = find.descendant(
        of: clearExclusions,
        matching: find.byIcon(Icons.restore),
      );
      expect(clearIcon, findsOneWidget);
      expect(tester.widget<Icon>(clearIcon).size, 19);
      expect(
        tester.widget<Icon>(clearIcon).color,
        const Color(0xffffc85a),
      );
      expect(tester.getSize(clearExclusions), const Size(34, 28));
      expect(
        tester
            .widget<Tooltip>(
              find.descendant(
                of: clearExclusions,
                matching: find.byType(Tooltip),
              ),
            )
            .message,
        '清除排除',
      );
      expect(find.text('清除排除'), findsNothing);
      expect(
        tester.getTopLeft(clearExclusions).dx,
        lessThan(
          tester
              .getTopLeft(
                find.byKey(const Key('unowned-ship-filter-result-count')),
              )
              .dx,
        ),
      );

      await tester.tap(find.byKey(const Key('unowned-ship-filter-cl')));
      await tester.pump();
      expect(tester.widget<Text>(excludedCount).data, '0');

      await tester.tap(find.byKey(const Key('unowned-ship-filter-dd')));
      await tester.pump();
      expect(tester.widget<Text>(excludedCount).data, '1');

      await tester.tap(clearExclusions);
      await tester.pump();
      expect(reminderController.excludedFamilyIds, isEmpty);
      expect(tester.widget<Text>(excludedCount).data, '0');
      expect(clearExclusions, findsOneWidget);
    },
  );

  testWidgets('explains unowned ship reminder exclusions below the filter', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(520, 700);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final controller = GameStateController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        home: Scaffold(
          body: OwnedInventoryPage(controller: controller, showOwned: false),
        ),
      ),
    );

    final hint = find.byKey(const Key('unowned-ship-reminder-hint'));
    expect(hint, findsOneWidget);
    final hintText = tester.widget<Text>(hint);
    expect(
      hintText.data,
      '获得未勾选的舰娘时，将正常提醒并震动；勾选的舰娘则不会提醒。',
    );
    expect(hintText.style?.fontSize, 12);
    expect(hintText.style?.color, const Color(0xff8ba2af));
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('owned-inventory-tab-equipment')));
    await tester.pump();
    expect(hint, findsNothing);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        home: Scaffold(body: OwnedInventoryPage(controller: controller)),
      ),
    );
    expect(hint, findsNothing);
  });

  testWidgets('unowned views reuse filters and remember each category', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1100, 700);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final controller = GameStateController();
    addTearDown(controller.dispose);
    controller
      ..accept(start2Event)
      ..accept(portEvent);
    await controller.idle;
    final projection = UnownedInventoryProjection(controller.state);
    final ddCount = projection
        .unownedShipFamiliesFor(category: ShipInventoryCategory.dd)
        .length;
    final unownedEquipmentRows = projection.unownedEquipment;
    final mainGunRows = projection.unownedEquipmentFor(
      category: EquipmentInventoryCategory.mainGun,
    );
    final mainGunCount = mainGunRows.length;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        home: Scaffold(
          body: OwnedInventoryPage(controller: controller, showOwned: false),
        ),
      ),
    );

    expect(find.byKey(const Key('unowned-ship-filter-all')), findsOneWidget);
    expect(find.byKey(const Key('unowned-ship-filter-dd')), findsOneWidget);
    for (final key in <String>['bbBc', 'cv', 'cvl']) {
      expect(find.byKey(Key('unowned-ship-filter-$key')), findsOneWidget);
    }
    expect(find.byKey(const Key('unowned-ship-filter-cvCvl')), findsNothing);
    final unownedCapitalFilterX = <double>[
      tester.getTopLeft(find.byKey(const Key('unowned-ship-filter-bbBc'))).dx,
      tester.getTopLeft(find.byKey(const Key('unowned-ship-filter-cv'))).dx,
      tester.getTopLeft(find.byKey(const Key('unowned-ship-filter-cvl'))).dx,
    ];
    expect(unownedCapitalFilterX[0], lessThan(unownedCapitalFilterX[1]));
    expect(unownedCapitalFilterX[1], lessThan(unownedCapitalFilterX[2]));
    await tester.tap(find.byKey(const Key('unowned-ship-filter-dd')));
    await tester.pump();
    expect(
      tester
          .widget<Text>(
            find.byKey(const Key('unowned-ship-filter-result-count')),
          )
          .data,
      '$ddCount',
    );

    await tester.tap(find.byKey(const Key('owned-inventory-tab-equipment')));
    await tester.pump();
    expect(
      find.byKey(const Key('unowned-equipment-filter-all')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('unowned-equipment-summary')), findsNothing);
    expect(find.byType(ExpansionTile), findsNothing);
    final equipmentCardKeys = find
        .byWidgetPredicate(
          (widget) =>
              widget.key is ValueKey<String> &&
              RegExp(
                r'^unowned-equipment-\d+$',
              ).hasMatch((widget.key! as ValueKey<String>).value),
        )
        .evaluate()
        .map((element) => (element.widget.key! as ValueKey<String>).value)
        .toList();
    expect(
      equipmentCardKeys,
      unownedEquipmentRows
          .map((row) => 'unowned-equipment-${row.master.id}')
          .toList(),
    );
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('unowned-equipment-filter-mainGun')));
    await tester.pump();
    expect(
      tester
          .widget<Text>(
            find.byKey(const Key('unowned-equipment-filter-result-count')),
          )
          .data,
      '$mainGunCount',
    );
    final resetEquipmentFilter = find.byKey(
      const Key('unowned-equipment-filter-reset'),
    );
    expect(resetEquipmentFilter, findsOneWidget);
    final resetEquipmentIcon = find.descendant(
      of: resetEquipmentFilter,
      matching: find.byIcon(Icons.restore),
    );
    expect(resetEquipmentIcon, findsOneWidget);
    expect(tester.widget<Icon>(resetEquipmentIcon).size, 19);
    expect(
      tester.widget<Icon>(resetEquipmentIcon).color,
      const Color(0xffffc85a),
    );
    expect(tester.getSize(resetEquipmentFilter), const Size(34, 28));
    expect(
      tester
          .widget<Tooltip>(
            find.descendant(
              of: resetEquipmentFilter,
              matching: find.byType(Tooltip),
            ),
          )
          .message,
      '重置筛选',
    );
    expect(
      tester.getTopLeft(resetEquipmentFilter).dx,
      lessThan(
        tester
            .getTopLeft(
              find.byKey(const Key('unowned-equipment-filter-result-count')),
            )
            .dx,
      ),
    );
    await tester.tap(resetEquipmentFilter);
    await tester.pump();
    final allLabel = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const Key('unowned-equipment-filter-all')),
        matching: find.text('全部'),
      ),
    );
    expect(allLabel.style?.color, const Color(0xffffcf62));
    expect(
      tester
          .widget<Text>(
            find.byKey(const Key('unowned-equipment-filter-result-count')),
          )
          .data,
      '${unownedEquipmentRows.length}',
    );

    await tester.tap(find.byKey(const Key('owned-inventory-tab-ships')));
    await tester.pump();
    final ddLabel = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const Key('unowned-ship-filter-dd')),
        matching: find.text('DD'),
      ),
    );
    expect(ddLabel.style?.color, const Color(0xffffcf62));
  });

  testWidgets('matches the confirmed compact ship and equipment controls', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(844, 390);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final controller = GameStateController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        home: Scaffold(body: OwnedInventoryPage(controller: controller)),
      ),
    );

    expect(find.byKey(const Key('owned-inventory-segmented')), findsOneWidget);
    expect(find.text('舰娘 0'), findsOneWidget);
    expect(find.text('装备 0'), findsOneWidget);
    expect(find.byKey(const Key('ship-filter-all')), findsOneWidget);
    for (final key in <String>['bbBc', 'cv', 'cvl']) {
      expect(find.byKey(Key('ship-filter-$key')), findsOneWidget);
    }
    expect(find.byKey(const Key('ship-filter-cvCvl')), findsNothing);
    final ownedCapitalFilterX = <double>[
      tester.getTopLeft(find.byKey(const Key('ship-filter-bbBc'))).dx,
      tester.getTopLeft(find.byKey(const Key('ship-filter-cv'))).dx,
      tester.getTopLeft(find.byKey(const Key('ship-filter-cvl'))).dx,
    ];
    expect(ownedCapitalFilterX[0], lessThan(ownedCapitalFilterX[1]));
    expect(ownedCapitalFilterX[1], lessThan(ownedCapitalFilterX[2]));
    expect(find.text('筛选结果 '), findsOneWidget);
    expect(find.byKey(const Key('ship-table-frozen-header')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('装备 0'));
    await tester.pump();

    expect(find.byKey(const Key('equipment-filter-all')), findsOneWidget);
    expect(find.byKey(const Key('equipment-filter-support')), findsOneWidget);
    expect(
      find.byKey(const Key('owned-inventory-equipment-sort-name')),
      findsOneWidget,
    );
    expect(find.text('总数（剩余）'), findsOneWidget);
    expect(find.text('改修／熟练度'), findsOneWidget);
    expect(find.text('着装情况'), findsOneWidget);
    expect(find.text('官方ID'), findsOneWidget);
    expect(find.text('实例ID'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('section control uses the Poi equipment capacity count', (
    tester,
  ) async {
    final controller = GameStateController();
    addTearDown(controller.dispose);
    controller.accept(start2Event);
    controller.accept(portEvent);
    controller.accept(
      kcsapiEvent('/kcsapi/api_get_member/slot_item', <Object?>[
        <String, Object?>{'api_id': 1, 'api_slotitem_id': 201},
        <String, Object?>{'api_id': 2, 'api_slotitem_id': 42},
      ]),
    );
    await controller.idle;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        home: Scaffold(body: OwnedInventoryPage(controller: controller)),
      ),
    );

    expect(find.text('装备 1'), findsOneWidget);
  });

  testWidgets('equipment remains grouped and ends with only official id', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(844, 390);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final controller = GameStateController();
    addTearDown(controller.dispose);
    controller
      ..accept(start2Event)
      ..accept(portEvent)
      ..accept(slotItemEvent);
    await controller.idle;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        home: Scaffold(body: OwnedInventoryPage(controller: controller)),
      ),
    );
    await tester.tap(find.byKey(const Key('owned-inventory-tab-equipment')));
    await tester.pump();

    final table = tester.widget<FrozenDataTable>(
      find.byKey(const Key('owned-inventory-table-equipment')),
    );
    expect(
      table.scrollableHeaders.last.key,
      const Key('owned-inventory-equipment-sort-officialId'),
    );
    expect(table.rowHeights, hasLength(3));

    final masterId = tester.widget<SelectableText>(
      find.byKey(const Key('equipment-master-id-201')),
    );
    expect(masterId.data, '201');
    expect(find.byKey(const Key('equipment-instance-id-7001')), findsNothing);
    expect(find.textContaining('12.7cm'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ship rows end with official and instance id columns', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(844, 390);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final controller = GameStateController();
    addTearDown(controller.dispose);
    controller
      ..accept(start2Event)
      ..accept(portEvent);
    await controller.idle;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        home: Scaffold(body: OwnedInventoryPage(controller: controller)),
      ),
    );

    final table = tester.widget<FrozenDataTable>(
      find.byKey(const Key('owned-inventory-table-ships')),
    );
    expect(
      table.scrollableHeaders
          .map((header) => header.key)
          .toList()
          .sublist(table.scrollableHeaders.length - 2),
      const <Key>[
        Key('owned-inventory-sort-officialId'),
        Key('owned-inventory-sort-instanceId'),
      ],
    );
    final horizontal = tester.widget<SingleChildScrollView>(
      find.byKey(const Key('owned-inventory-horizontal-scroll')),
    );
    horizontal.controller!.jumpTo(
      horizontal.controller!.position.maxScrollExtent,
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('owned-inventory-sort-officialId')));
    await tester.pump();
    expect(find.text('官方ID ▼'), findsOneWidget);
    expect(
      tester
          .widget<SelectableText>(find.byKey(const Key('ship-master-id-9001')))
          .data,
      '101',
    );
    expect(
      tester
          .widget<SelectableText>(
            find.byKey(const Key('ship-instance-id-9001')),
          )
          .data,
      '9001',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('only name total and official id sort equipment groups', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(844, 390);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final controller = GameStateController();
    addTearDown(controller.dispose);
    controller
      ..accept(start2Event)
      ..accept(portEvent)
      ..accept(slotItemEvent);
    await controller.idle;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        home: Scaffold(body: OwnedInventoryPage(controller: controller)),
      ),
    );
    await tester.tap(find.byKey(const Key('owned-inventory-tab-equipment')));
    await tester.pump();

    final table = tester.widget<FrozenDataTable>(
      find.byKey(const Key('owned-inventory-table-equipment')),
    );
    expect(
      table.frozenHeaders.single.key,
      const Key('owned-inventory-equipment-sort-name'),
    );
    expect(table.scrollableHeaders.map((header) => header.key), <Key?>[
      const Key('owned-inventory-equipment-sort-total'),
      null,
      null,
      const Key('owned-inventory-equipment-sort-officialId'),
    ]);

    await tester.tap(
      find.byKey(const Key('owned-inventory-equipment-sort-total')),
    );
    await tester.pump();
    expect(find.text('总数（剩余） ▼'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses uniform 78 widths for ship stat columns', (tester) async {
    final controller = GameStateController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        home: Scaffold(body: OwnedInventoryPage(controller: controller)),
      ),
    );

    final table = tester.widget<FrozenDataTable>(
      find.byKey(const Key('owned-inventory-table-ships')),
    );

    expect(table.frozenColumnWidths, const <double>[240]);
    expect(table.scrollableColumnWidths, const <double>[
      96,
      78,
      78,
      78,
      78,
      78,
      78,
      78,
      78,
      78,
      78,
      78,
      78,
      210,
      52,
      92,
      110,
    ]);
  });

  testWidgets('keeps both filter rows equally compact on a square foldable', (
    tester,
  ) async {
    final semanticsHandle = tester.ensureSemantics();
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(720, 720);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final controller = GameStateController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: OwnedInventoryPage(controller: controller)),
      ),
    );

    final shipHeight = tester
        .getSize(find.byKey(const Key('ship-filter-all')))
        .height;
    final resetSort = find.byKey(const Key('owned-inventory-sort-reset'));
    expect(resetSort, findsOneWidget);
    await tester.ensureVisible(resetSort);
    expect(
      find.descendant(of: resetSort, matching: find.byIcon(Icons.restore)),
      findsOneWidget,
    );
    expect(find.text('还原默认排序'), findsNothing);
    expect(tester.getSize(resetSort), const Size(34, 28));
    final resetIcon = tester.widget<Icon>(
      find.descendant(of: resetSort, matching: find.byIcon(Icons.restore)),
    );
    expect(resetIcon.size, 19);
    expect(resetIcon.color, const Color(0xffffc85a));
    final resetTooltip = tester.widget<Tooltip>(
      find.descendant(of: resetSort, matching: find.byType(Tooltip)),
    );
    expect(resetTooltip.message, '还原默认排序');
    expect(tester.getSemantics(resetSort).label, contains('还原默认排序'));
    await tester.tap(resetSort);
    await tester.pump();
    expect(find.text('等级 ▼'), findsOneWidget);
    expect(find.text('等级 ▼①'), findsNothing);

    await tester.tap(find.text('装备 0'));
    await tester.pump();
    final equipmentHeight = tester
        .getSize(find.byKey(const Key('equipment-filter-all')))
        .height;

    expect(shipHeight, equipmentHeight);
    expect(shipHeight, lessThanOrEqualTo(30));
    expect(tester.takeException(), isNull);
    semanticsHandle.dispose();
  });

  testWidgets('renders live ships and grouped equipment and toggles sorting', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(844, 390);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final controller = GameStateController();
    addTearDown(controller.dispose);
    controller.accept(start2Event);
    controller.accept(portEvent);
    controller.accept(slotItemEvent);
    await controller.idle;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: OwnedInventoryPage(controller: controller)),
      ),
    );

    expect(find.text('舰娘 2'), findsOneWidget);
    expect(find.text('等级 ▼'), findsOneWidget);
    await tester.tap(find.text('等级 ▼'));
    await tester.pump();
    expect(find.text('等级 ▲'), findsOneWidget);

    await tester.tap(find.byKey(const Key('owned-inventory-tab-equipment')));
    await tester.pump();
    expect(find.text('总数（剩余）'), findsOneWidget);
    expect(find.textContaining('12.7cm'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses one temporary sort and toggles its direction', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(2400, 600);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final controller = GameStateController();
    addTearDown(controller.dispose);
    controller
      ..accept(start2Event)
      ..accept(portEvent)
      ..accept(slotItemEvent);
    await controller.idle;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: OwnedInventoryPage(controller: controller)),
      ),
    );

    await tester.tap(find.byKey(const Key('owned-inventory-sort-firepower')));
    await tester.pump();
    expect(find.text('等级'), findsOneWidget);
    expect(find.text('火力 ▼'), findsOneWidget);
    expect(find.text('火力 ▼①'), findsNothing);

    await tester.tap(find.byKey(const Key('owned-inventory-sort-firepower')));
    await tester.pump();
    expect(find.text('火力 ▲'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sort interactions reorder real frozen ship rows', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(2400, 600);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final startEnvelope =
        jsonDecode(start2Event.responseBody) as Map<String, Object?>;
    final startData =
        jsonDecode(jsonEncode(startEnvelope['api_data']))
            as Map<String, Object?>;
    final masterShips = startData['api_mst_ship']! as List<Object?>;
    masterShips.add(<String, Object?>{
      ...Map<String, Object?>.from(masterShips[1]! as Map),
      'api_id': 103,
      'api_name': '睦月',
    });

    final portEnvelope =
        jsonDecode(portEvent.responseBody) as Map<String, Object?>;
    final portData = portEnvelope['api_data']! as Map<String, Object?>;
    final sourceShips = portData['api_ship']! as List<Object?>;
    final first = Map<String, Object?>.from(sourceShips[0]! as Map);
    final second = Map<String, Object?>.from(sourceShips[1]! as Map);
    final ships = <Object?>[
      <String, Object?>{
        ...first,
        'api_id': 9001,
        'api_ship_id': 101,
        'api_lv': 60,
        'api_karyoku': <int>[10, 10],
        'api_soukou': <int>[5, 5],
        'api_taisen': <int>[10, 10],
      },
      <String, Object?>{
        ...second,
        'api_id': 9002,
        'api_ship_id': 102,
        'api_lv': 50,
        'api_karyoku': <int>[30, 30],
        'api_soukou': <int>[10, 10],
        'api_taisen': <int>[5, 5],
      },
      <String, Object?>{
        ...second,
        'api_id': 9003,
        'api_ship_id': 103,
        'api_lv': 40,
        'api_karyoku': <int>[20, 20],
        'api_soukou': <int>[10, 10],
        'api_taisen': <int>[30, 30],
      },
    ];
    final controller = GameStateController();
    addTearDown(controller.dispose);
    controller
      ..accept(kcsapiEvent('/kcsapi/api_start2/getData', startData))
      ..accept(
        kcsapiEvent('/kcsapi/api_port/port', <String, Object?>{
          'api_ship': ships,
          'api_deck_port': const <Object?>[],
        }),
      );
    await controller.idle;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: OwnedInventoryPage(controller: controller)),
      ),
    );

    double rowTop(int shipId) =>
        tester.getTopLeft(find.byKey(Key('owned-ship-portrait-$shipId'))).dy;
    void expectOrder(List<int> shipIds) {
      for (var index = 1; index < shipIds.length; index++) {
        expect(rowTop(shipIds[index - 1]), lessThan(rowTop(shipIds[index])));
      }
    }

    expectOrder(const <int>[9001, 9002, 9003]);

    final firepowerHeader = find.byKey(
      const Key('owned-inventory-sort-firepower'),
    );
    await tester.tap(firepowerHeader);
    await tester.pump();
    expectOrder(const <int>[9002, 9003, 9001]);

    await tester.tap(firepowerHeader);
    await tester.pump();
    expectOrder(const <int>[9001, 9003, 9002]);

    final armorHeader = find.byKey(const Key('owned-inventory-sort-armor'));
    await tester.tap(armorHeader);
    await tester.pump();
    await tester.longPress(armorHeader);
    await tester.pump();
    await tester.tap(find.byKey(const Key('owned-inventory-sort-antiSub')));
    await tester.pump();
    expectOrder(const <int>[9003, 9002, 9001]);

    await tester.tap(find.byKey(const Key('owned-inventory-sort-reset')));
    await tester.pump();
    expectOrder(const <int>[9001, 9002, 9003]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('locks a temporary sort and appends one temporary last level', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(2400, 600);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final controller = GameStateController();
    addTearDown(controller.dispose);
    controller
      ..accept(start2Event)
      ..accept(portEvent)
      ..accept(slotItemEvent);
    await controller.idle;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: OwnedInventoryPage(controller: controller)),
      ),
    );

    final firepowerHeader = find.byKey(
      const Key('owned-inventory-sort-firepower'),
    );
    final antiSubHeader = find.byKey(const Key('owned-inventory-sort-antiSub'));
    final armorHeader = find.byKey(const Key('owned-inventory-sort-armor'));

    await tester.tap(firepowerHeader);
    await tester.pump();
    await tester.longPress(firepowerHeader);
    await tester.pump();

    expect(find.text('火力 ▼①'), findsOneWidget);
    expect(
      find.descendant(of: firepowerHeader, matching: find.byIcon(Icons.lock)),
      findsOneWidget,
    );

    await tester.tap(antiSubHeader);
    await tester.pump();
    expect(find.text('对潜 ▼②'), findsOneWidget);
    expect(
      find.descendant(of: antiSubHeader, matching: find.byIcon(Icons.lock)),
      findsNothing,
    );

    await tester.tap(armorHeader);
    await tester.pump();
    expect(find.text('火力 ▼①'), findsOneWidget);
    expect(find.text('对潜'), findsOneWidget);
    expect(find.text('装甲 ▼②'), findsOneWidget);
    expect(
      find.descendant(of: firepowerHeader, matching: find.byIcon(Icons.lock)),
      findsOneWidget,
    );

    await tester.tap(firepowerHeader);
    await tester.pump();
    expect(find.text('火力 ▲①'), findsOneWidget);

    final table = tester.widget(
      find.byKey(const Key('owned-inventory-table-ships')),
    );
    await tester.longPress(firepowerHeader);
    await tester.pump();
    expect(find.text('火力'), findsOneWidget);
    expect(find.text('装甲 ▼'), findsOneWidget);
    expect(
      find.descendant(of: firepowerHeader, matching: find.byIcon(Icons.lock)),
      findsNothing,
    );
    expect(
      tester.widget(find.byKey(const Key('owned-inventory-table-ships'))),
      isNot(same(table)),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'directly locks an inactive field and clears the temporary sort',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(2400, 600);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final controller = GameStateController();
      addTearDown(controller.dispose);
      controller
        ..accept(start2Event)
        ..accept(portEvent)
        ..accept(slotItemEvent);
      await controller.idle;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: OwnedInventoryPage(controller: controller)),
        ),
      );

      final antiSubHeader = find.byKey(
        const Key('owned-inventory-sort-antiSub'),
      );
      expect(find.text('等级 ▼'), findsOneWidget);

      await tester.longPress(antiSubHeader);
      await tester.pump();

      expect(find.text('等级'), findsOneWidget);
      expect(find.text('对潜 ▼①'), findsOneWidget);
      expect(
        find.descendant(of: antiSubHeader, matching: find.byIcon(Icons.lock)),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('exposes sort state and supports Shift+Enter locking', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(2400, 600);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final controller = GameStateController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        home: Scaffold(body: OwnedInventoryPage(controller: controller)),
      ),
    );

    final firepowerHeader = find.byKey(
      const Key('owned-inventory-sort-firepower'),
    );
    final headerElement = tester.element(firepowerHeader);

    bool headerHasFocus() {
      final focusContext = tester.binding.focusManager.primaryFocus?.context;
      if (focusContext == null) return false;
      var isInsideHeader = identical(focusContext, headerElement);
      focusContext.visitAncestorElements((ancestor) {
        if (identical(ancestor, headerElement)) isInsideHeader = true;
        return !isInsideHeader;
      });
      return isInsideHeader;
    }

    for (var i = 0; i < 40 && !headerHasFocus(); i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
    }
    expect(headerHasFocus(), isTrue);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();

    expect(find.text('火力 ▼①'), findsOneWidget);
    final semantics = tester.getSemantics(firepowerHeader);
    expect(semantics.label, contains('火力'));
    expect(semantics.label, contains('降序'));
    expect(semantics.label, contains('第1优先级'));
    expect(semantics.label, contains('已锁定'));
  });

  testWidgets('keeps accessible tap and named lock actions', (tester) async {
    final semanticsHandle = tester.ensureSemantics();
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(2400, 600);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final controller = GameStateController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        home: Scaffold(body: OwnedInventoryPage(controller: controller)),
      ),
    );

    final firepowerHeader = find.byKey(
      const Key('owned-inventory-sort-firepower'),
    );
    var node = tester.getSemantics(firepowerHeader);
    var data = node.getSemanticsData();
    expect(data.hasAction(SemanticsAction.tap), isTrue);
    expect(data.hasAction(SemanticsAction.longPress), isTrue);
    expect(data.hasAction(SemanticsAction.customAction), isTrue);

    node.owner!.performAction(node.id, SemanticsAction.tap);
    await tester.pump();
    expect(find.text('火力 ▼'), findsOneWidget);

    node = tester.getSemantics(firepowerHeader);
    data = node.getSemanticsData();
    final customActionId = data.customSemanticsActionIds!.single;
    node.owner!.performAction(
      node.id,
      SemanticsAction.customAction,
      customActionId,
    );
    await tester.pump();

    expect(find.text('火力 ▼①'), findsOneWidget);
    node = tester.getSemantics(firepowerHeader);
    data = node.getSemanticsData();
    expect(data.hasAction(SemanticsAction.tap), isTrue);
    expect(data.hasAction(SemanticsAction.longPress), isTrue);
    expect(data.hasAction(SemanticsAction.customAction), isTrue);
    expect(data.hint, contains('长按或按 Shift+Enter 解除锁定'));

    final unlockActionId = data.customSemanticsActionIds!.single;
    node.owner!.performAction(
      node.id,
      SemanticsAction.customAction,
      unlockActionId,
    );
    await tester.pump();

    expect(find.text('火力'), findsOneWidget);
    expect(find.text('等级 ▼'), findsOneWidget);
    semanticsHandle.dispose();
  });

  testWidgets(
    'keeps two locked levels while replacing the temporary last level',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(2400, 600);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final controller = GameStateController();
      addTearDown(controller.dispose);
      controller
        ..accept(start2Event)
        ..accept(portEvent)
        ..accept(slotItemEvent);
      await controller.idle;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: OwnedInventoryPage(controller: controller)),
        ),
      );

      final antiSubHeader = find.byKey(
        const Key('owned-inventory-sort-antiSub'),
      );
      final firepowerHeader = find.byKey(
        const Key('owned-inventory-sort-firepower'),
      );
      final torpedoHeader = find.byKey(
        const Key('owned-inventory-sort-torpedo'),
      );
      final armorHeader = find.byKey(const Key('owned-inventory-sort-armor'));

      await tester.longPress(antiSubHeader);
      await tester.pump();
      await tester.longPress(firepowerHeader);
      await tester.pump();

      expect(find.text('对潜 ▼①'), findsOneWidget);
      expect(find.text('火力 ▼②'), findsOneWidget);
      expect(
        find.descendant(of: antiSubHeader, matching: find.byIcon(Icons.lock)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: firepowerHeader, matching: find.byIcon(Icons.lock)),
        findsOneWidget,
      );

      await tester.tap(torpedoHeader);
      await tester.pump();
      expect(find.text('雷装 ▼③'), findsOneWidget);
      expect(
        find.descendant(of: torpedoHeader, matching: find.byIcon(Icons.lock)),
        findsNothing,
      );

      await tester.tap(armorHeader);
      await tester.pump();
      expect(find.text('对潜 ▼①'), findsOneWidget);
      expect(find.text('火力 ▼②'), findsOneWidget);
      expect(find.text('雷装'), findsOneWidget);
      expect(find.text('装甲 ▼③'), findsOneWidget);
      expect(
        find.descendant(of: armorHeader, matching: find.byIcon(Icons.lock)),
        findsNothing,
      );
      expect(
        find.descendant(of: antiSubHeader, matching: find.byIcon(Icons.lock)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: firepowerHeader, matching: find.byIcon(Icons.lock)),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'long-pressing a locked header removes it and advances later priorities',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(2400, 600);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final controller = GameStateController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          home: Scaffold(body: OwnedInventoryPage(controller: controller)),
        ),
      );

      final antiSubHeader = find.byKey(
        const Key('owned-inventory-sort-antiSub'),
      );
      final firepowerHeader = find.byKey(
        const Key('owned-inventory-sort-firepower'),
      );
      final armorHeader = find.byKey(const Key('owned-inventory-sort-armor'));

      await tester.longPress(antiSubHeader);
      await tester.pump();
      await tester.longPress(firepowerHeader);
      await tester.pump();
      await tester.tap(armorHeader);
      await tester.pump();

      expect(find.text('对潜 ▼①'), findsOneWidget);
      expect(find.text('火力 ▼②'), findsOneWidget);
      expect(find.text('装甲 ▼③'), findsOneWidget);

      await tester.longPress(antiSubHeader);
      await tester.pump();

      expect(find.text('对潜'), findsOneWidget);
      expect(find.text('火力 ▼①'), findsOneWidget);
      expect(find.text('装甲 ▼②'), findsOneWidget);
      expect(
        find.descendant(of: antiSubHeader, matching: find.byIcon(Icons.lock)),
        findsNothing,
      );
      expect(
        find.descendant(of: firepowerHeader, matching: find.byIcon(Icons.lock)),
        findsOneWidget,
      );
    },
  );

  testWidgets('colors active headers and contains a locked header', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(844, 390);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final controller = GameStateController();
    addTearDown(controller.dispose);
    controller
      ..accept(start2Event)
      ..accept(portEvent)
      ..accept(slotItemEvent);
    await controller.idle;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: OwnedInventoryPage(controller: controller)),
      ),
    );

    final levelHeader = find.byKey(const Key('owned-inventory-sort-level'));
    final temporaryText = tester.widget<Text>(
      find.descendant(of: levelHeader, matching: find.text('等级 ▼')),
    );
    expect(temporaryText.style?.color, const Color(0xffffc85a));

    await tester.longPress(levelHeader);
    await tester.pump();
    final lockedTextFinder = find.descendant(
      of: levelHeader,
      matching: find.text('等级 ▼①'),
    );
    final lockFinder = find.descendant(
      of: levelHeader,
      matching: find.byIcon(Icons.lock),
    );
    expect(
      tester.widget<Text>(lockedTextFinder).style?.color,
      const Color(0xff72bded),
    );
    expect(lockFinder, findsOneWidget);

    final headerRect = tester.getRect(levelHeader);
    final textRect = tester.getRect(lockedTextFinder);
    final lockRect = tester.getRect(lockFinder);
    expect(headerRect.width, 78);
    expect(textRect.left, greaterThanOrEqualTo(headerRect.left));
    expect(textRect.right, lessThanOrEqualTo(headerRect.right));
    expect(lockRect.left, greaterThanOrEqualTo(headerRect.left));
    expect(lockRect.right, lessThanOrEqualTo(headerRect.right));
    expect(textRect.top, greaterThanOrEqualTo(headerRect.top));
    expect(textRect.bottom, lessThanOrEqualTo(headerRect.bottom));
    expect(lockRect.top, greaterThanOrEqualTo(headerRect.top));
    expect(lockRect.bottom, lessThanOrEqualTo(headerRect.bottom));
    expect(tester.takeException(), isNull);
  });

  testWidgets('rightmost sort headers stay tappable after horizontal scroll', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(844, 390);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final controller = GameStateController();
    addTearDown(controller.dispose);
    controller
      ..accept(start2Event)
      ..accept(portEvent)
      ..accept(slotItemEvent);
    await controller.idle;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        home: Scaffold(body: OwnedInventoryPage(controller: controller)),
      ),
    );

    final horizontal = tester.widget<SingleChildScrollView>(
      find.byKey(const Key('owned-inventory-horizontal-scroll')),
    );
    horizontal.controller!.jumpTo(
      horizontal.controller!.position.maxScrollExtent - 202,
    );
    await tester.pump();

    for (final field in <String>[
      'luck',
      'evasion',
      'antiSub',
      'lineOfSight',
      'locked',
    ]) {
      final header = find.byKey(Key('owned-inventory-sort-$field'));
      expect(header.hitTestable(), findsOneWidget, reason: field);

      await tester.tap(header);
      await tester.pump();

      expect(
        find.descendant(
          of: header,
          matching: find.byWidgetPredicate(
            (widget) => widget is Text && widget.data!.contains('▼'),
          ),
        ),
        findsOneWidget,
        reason: field,
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('restores the default sort without clearing ship category', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(2400, 600);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final controller = GameStateController();
    addTearDown(controller.dispose);
    controller
      ..accept(start2Event)
      ..accept(portEvent)
      ..accept(slotItemEvent);
    await controller.idle;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: OwnedInventoryPage(controller: controller)),
      ),
    );

    await tester.tap(find.byKey(const Key('ship-filter-dd')));
    await tester.pump();
    expect(find.text('夕張'), findsOneWidget);
    expect(find.text('吹雪'), findsNothing);

    final antiSubHeader = find.byKey(const Key('owned-inventory-sort-antiSub'));
    final firepowerHeader = find.byKey(
      const Key('owned-inventory-sort-firepower'),
    );
    final levelHeader = find.byKey(const Key('owned-inventory-sort-level'));

    await tester.longPress(antiSubHeader);
    await tester.pump();
    await tester.longPress(firepowerHeader);
    await tester.pump();
    expect(find.text('对潜 ▼①'), findsOneWidget);
    expect(find.text('火力 ▼②'), findsOneWidget);

    await tester.tap(find.byKey(const Key('owned-inventory-sort-reset')));
    await tester.pump();

    expect(find.text('等级 ▼'), findsOneWidget);
    expect(find.text('火力'), findsOneWidget);
    expect(find.text('对潜'), findsOneWidget);
    expect(
      find.descendant(of: antiSubHeader, matching: find.byIcon(Icons.lock)),
      findsNothing,
    );
    expect(
      find.descendant(of: firepowerHeader, matching: find.byIcon(Icons.lock)),
      findsNothing,
    );
    expect(
      find.descendant(of: levelHeader, matching: find.byIcon(Icons.lock)),
      findsNothing,
    );
    expect(find.text('夕張'), findsOneWidget);
    expect(find.text('吹雪'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'uses taller portraits and keeps modernization suffixes visible',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(844, 390);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final controller = GameStateController();
      addTearDown(controller.dispose);
      controller
        ..accept(start2Event)
        ..accept(portEvent)
        ..accept(slotItemEvent);
      await controller.idle;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: OwnedInventoryPage(controller: controller)),
        ),
      );

      final portrait = find.byKey(const Key('owned-ship-portrait-9001'));
      expect(tester.getSize(portrait).height, greaterThanOrEqualTo(50));
      expect(tester.getSize(portrait).width, greaterThanOrEqualTo(76));
      expect(find.text('55/+10'), findsOneWidget);
      expect(find.text('42/+8'), findsOneWidget);
      expect(find.text('38/+12'), findsOneWidget);
      expect(find.text('46/+3'), findsOneWidget);
    },
  );

  testWidgets('equipment rows grow for many wearing ships without overlap', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(844, 390);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final controller = GameStateController();
    addTearDown(controller.dispose);
    controller.accept(start2Event);
    controller.accept(
      kcsapiEvent('/kcsapi/api_port/port', <String, Object?>{
        'api_ship': <Object?>[
          for (var index = 1; index <= 14; index++)
            <String, Object?>{
              'api_id': 9000 + index,
              'api_ship_id': 101,
              'api_lv': index,
              'api_slot': <int>[7000 + index],
            },
        ],
        'api_deck_port': const <Object?>[],
      }),
    );
    controller.accept(
      kcsapiEvent('/kcsapi/api_get_member/slot_item', <Object?>[
        for (var index = 1; index <= 14; index++)
          <String, Object?>{
            'api_id': 7000 + index,
            'api_slotitem_id': 201,
            'api_level': index % 11,
          },
      ]),
    );
    await controller.idle;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: OwnedInventoryPage(controller: controller)),
      ),
    );
    await tester.tap(find.byKey(const Key('owned-inventory-tab-equipment')));
    await tester.pump();

    final row = find.byKey(const Key('equipment-name-row-201'));
    expect(row, findsOneWidget);
    expect(tester.getSize(row).height, greaterThan(44));

    final wearingCell = find.byKey(const Key('equipment-wearings-cell-201'));
    expect(wearingCell, findsOneWidget);
    final wearingCellRect = tester.getRect(wearingCell);
    final wearingItems = find.byWidgetPredicate(
      (widget) =>
          widget.key is ValueKey<String> &&
          ((widget.key! as ValueKey<String>).value).startsWith(
            'equipment-wearing-item-201-',
          ),
    );
    expect(wearingItems, findsNWidgets(14));
    for (final element in wearingItems.evaluate()) {
      final itemRect = tester.getRect(
        find.byElementPredicate((candidate) {
          return identical(candidate, element);
        }),
      );
      expect(itemRect.left, greaterThanOrEqualTo(wearingCellRect.left + 8));
      expect(itemRect.right, lessThanOrEqualTo(wearingCellRect.right - 8));
      expect(itemRect.top, greaterThanOrEqualTo(wearingCellRect.top));
      expect(itemRect.bottom, lessThanOrEqualTo(wearingCellRect.bottom));
    }
    final firstItemRect = tester.getRect(wearingItems.first);
    expect(firstItemRect.left, closeTo(wearingCellRect.left + 8, 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('long equipment names wrap completely and grow their row', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(844, 390);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    const longName = '试制十五厘米九联装对空喷进炮改二熟练型集中配备型性能强化改修型特殊装备';
    final startEnvelope =
        jsonDecode(start2Event.responseBody) as Map<String, Object?>;
    final startData =
        jsonDecode(jsonEncode(startEnvelope['api_data']))
            as Map<String, Object?>;
    final masterSlotItems = startData['api_mst_slotitem']! as List<Object?>;
    final target = masterSlotItems.cast<Map<String, Object?>>().firstWhere(
      (item) => item['api_id'] == 201,
    );
    target['api_name'] = longName;

    final controller = GameStateController();
    addTearDown(controller.dispose);
    controller
      ..accept(kcsapiEvent('/kcsapi/api_start2/getData', startData))
      ..accept(portEvent)
      ..accept(slotItemEvent);
    await controller.idle;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: OwnedInventoryPage(controller: controller)),
      ),
    );
    await tester.tap(find.byKey(const Key('owned-inventory-tab-equipment')));
    await tester.pump();

    final nameFinder = find.text(longName);
    final rowFinder = find.byKey(const Key('equipment-name-row-201'));
    expect(nameFinder, findsOneWidget);
    expect(tester.widget<Text>(nameFinder).maxLines, isNull);
    expect(tester.getSize(rowFinder).height, greaterThan(44));
    expect(
      tester.getRect(nameFinder).bottom,
      lessThanOrEqualTo(tester.getRect(rowFinder).bottom),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'equipment row contains the final wearing line with long names and scaled text',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(844, 390);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      final startEnvelope =
          jsonDecode(start2Event.responseBody) as Map<String, Object?>;
      final startData =
          jsonDecode(jsonEncode(startEnvelope['api_data']))
              as Map<String, Object?>;
      final masters = startData['api_mst_ship']! as List<Object?>;
      final template = Map<String, Object?>.from(
        masters.first! as Map<String, Object?>,
      );
      for (var index = 1; index <= 30; index++) {
        masters.add(<String, Object?>{
          ...template,
          'api_id': 1000 + index,
          'api_name': index.isEven
              ? 'Samuel B.Roberts改二$index'
              : 'Ташкент改二$index',
        });
      }

      final controller = GameStateController();
      addTearDown(controller.dispose);
      controller
        ..accept(kcsapiEvent('/kcsapi/api_start2/getData', startData))
        ..accept(
          kcsapiEvent('/kcsapi/api_port/port', <String, Object?>{
            'api_ship': <Object?>[
              for (var index = 1; index <= 30; index++)
                <String, Object?>{
                  'api_id': 9000 + index,
                  'api_ship_id': 1000 + index,
                  'api_lv': 99 - index,
                  'api_slot': <int>[7000 + index],
                },
            ],
            'api_deck_port': const <Object?>[],
          }),
        )
        ..accept(
          kcsapiEvent('/kcsapi/api_get_member/slot_item', <Object?>[
            for (var index = 1; index <= 30; index++)
              <String, Object?>{
                'api_id': 7000 + index,
                'api_slotitem_id': 201,
                'api_level': 0,
              },
          ]),
        );
      await controller.idle;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(fontFamily: 'HarmonyOS_Sans_SC'),
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.2)),
            child: Scaffold(body: OwnedInventoryPage(controller: controller)),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('owned-inventory-tab-equipment')));
      await tester.pump();

      final wearingCell = find.byKey(const Key('equipment-wearings-cell-201'));
      final finalItem = find.byKey(
        const ValueKey<String>('equipment-wearing-item-201-9030'),
      );
      expect(wearingCell, findsOneWidget);
      expect(finalItem, findsOneWidget);
      expect(
        tester.getRect(finalItem).bottom,
        lessThanOrEqualTo(tester.getRect(wearingCell).bottom),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('lazily builds ship rows near the viewport', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(844, 390);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final controller = GameStateController();
    addTearDown(controller.dispose);
    controller
      ..accept(start2Event)
      ..accept(
        kcsapiEvent('/kcsapi/api_port/port', <String, Object?>{
          'api_ship': <Object?>[
            for (var index = 1; index <= 100; index++)
              <String, Object?>{
                'api_id': 9000 + index,
                'api_ship_id': 101,
                'api_lv': 1,
                'api_slot': const <int>[-1, -1, -1, -1],
              },
          ],
          'api_deck_port': const <Object?>[],
        }),
      );
    await controller.idle;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: OwnedInventoryPage(controller: controller)),
      ),
    );

    final firstPortrait = find.byKey(const Key('owned-ship-portrait-9001'));
    final lastPortrait = find.byKey(const Key('owned-ship-portrait-9100'));
    expect(firstPortrait, findsOneWidget);
    expect(lastPortrait, findsNothing);
    final bodyList = find.byKey(const Key('owned-inventory-body-scroll'));
    expect(bodyList, findsOneWidget);
    final bodyListWidget = tester.widget<ListView>(bodyList);
    bodyListWidget.controller!.jumpTo(
      bodyListWidget.controller!.position.maxScrollExtent,
    );
    await tester.pump();

    expect(lastPortrait, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'ignores unrelated game state updates and invalidates inventory changes',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(844, 390);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      final controller = GameStateController();
      addTearDown(controller.dispose);
      controller
        ..accept(start2Event)
        ..accept(portEvent)
        ..accept(slotItemEvent);
      await controller.idle;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: OwnedInventoryPage(controller: controller)),
        ),
      );

      final tableFinder = find.byKey(const Key('owned-inventory-table-ships'));
      expect(tableFinder, findsOneWidget);
      final initialTable = tester.widget(tableFinder);

      controller.accept(
        kcsapiEvent('/kcsapi/api_get_member/material', <Object?>[
          <String, Object?>{'api_id': 1, 'api_value': 999},
        ]),
      );
      await controller.idle;
      await tester.pump();

      expect(tester.widget(tableFinder), same(initialTable));

      controller.accept(slotItemEvent);
      await controller.idle;
      await tester.pump();

      expect(tester.widget(tableFinder), isNot(same(initialTable)));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('decodes owned ship portraits at thumbnail resolution', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = const Size(1688, 780);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final controller = GameStateController();
    addTearDown(controller.dispose);
    controller
      ..accept(start2Event)
      ..accept(portEvent)
      ..accept(slotItemEvent);
    await controller.idle;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: OwnedInventoryPage(controller: controller)),
      ),
    );

    final image = tester.widget<Image>(
      find
          .descendant(
            of: find.byKey(const Key('owned-ship-portrait-9001')),
            matching: find.byType(Image),
          )
          .first,
    );
    expect(image.image, isA<ResizeImage>());
    expect((image.image as ResizeImage).height, 106);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'keeps lazy frozen rows and header synchronized while scrolling',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(844, 390);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      final controller = GameStateController();
      addTearDown(controller.dispose);
      controller
        ..accept(start2Event)
        ..accept(
          kcsapiEvent('/kcsapi/api_port/port', <String, Object?>{
            'api_ship': <Object?>[
              for (var index = 1; index <= 100; index++)
                <String, Object?>{
                  'api_id': 9000 + index,
                  'api_ship_id': 101,
                  'api_lv': 1,
                  'api_slot': const <int>[-1, -1, -1, -1],
                },
            ],
            'api_deck_port': const <Object?>[],
          }),
        );
      await controller.idle;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: OwnedInventoryPage(controller: controller)),
        ),
      );

      final bodyListFinder = find.byKey(
        const Key('owned-inventory-body-scroll'),
      );
      final bodyList = tester.widget<ListView>(bodyListFinder);
      bodyList.controller!.jumpTo(500);
      await tester.pump();

      final frozenList = tester.widget<ListView>(
        find.byKey(const Key('owned-inventory-frozen-scroll')),
      );
      expect(bodyList.controller!.offset, greaterThan(0));
      expect(
        frozenList.controller!.offset,
        closeTo(bodyList.controller!.offset, 0.1),
      );

      final horizontalFinder = find.byKey(
        const Key('owned-inventory-horizontal-scroll'),
      );
      expect(horizontalFinder, findsOneWidget);
      final horizontal = tester.widget<SingleChildScrollView>(horizontalFinder);
      horizontal.controller!.jumpTo(500);
      await tester.pump();

      final headerTranslation = find.descendant(
        of: find.byKey(const Key('owned-inventory-table-ships')),
        matching: find.byWidgetPredicate((widget) {
          if (widget is! Transform) return false;
          final translation = widget.transform.getTranslation();
          return (translation.x + horizontal.controller!.offset).abs() <= 0.1 &&
              translation.y.abs() <= 0.1;
        }),
      );
      expect(horizontal.controller!.offset, greaterThan(0));
      expect(headerTranslation, findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('provides known variable equipment extents to both lazy lists', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(844, 390);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final controller = GameStateController();
    addTearDown(controller.dispose);
    controller
      ..accept(start2Event)
      ..accept(
        kcsapiEvent('/kcsapi/api_port/port', <String, Object?>{
          'api_ship': <Object?>[
            for (var index = 1; index <= 14; index++)
              <String, Object?>{
                'api_id': 9000 + index,
                'api_ship_id': 101,
                'api_lv': index,
                'api_slot': <int>[7000 + index],
              },
          ],
          'api_deck_port': const <Object?>[],
        }),
      )
      ..accept(
        kcsapiEvent('/kcsapi/api_get_member/slot_item', <Object?>[
          for (var index = 1; index <= 14; index++)
            <String, Object?>{
              'api_id': 7000 + index,
              'api_slotitem_id': 201,
              'api_level': index % 11,
            },
          <String, Object?>{
            'api_id': 8000,
            'api_slotitem_id': 202,
            'api_level': 0,
          },
        ]),
      );
    await controller.idle;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: OwnedInventoryPage(controller: controller)),
      ),
    );
    await tester.tap(find.byKey(const Key('owned-inventory-tab-equipment')));
    await tester.pump();

    final frozenList = tester.widget<ListView>(
      find.byKey(const Key('owned-inventory-frozen-scroll')),
    );
    final bodyList = tester.widget<ListView>(
      find.byKey(const Key('owned-inventory-body-scroll')),
    );
    expect(frozenList.itemExtentBuilder, isNotNull);
    expect(bodyList.itemExtentBuilder, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('equipment table ignores fleet-only inventory changes', (
    tester,
  ) async {
    final controller = GameStateController();
    addTearDown(controller.dispose);
    controller
      ..accept(start2Event)
      ..accept(portEvent)
      ..accept(slotItemEvent);
    await controller.idle;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: OwnedInventoryPage(controller: controller)),
      ),
    );
    await tester.tap(find.byKey(const Key('owned-inventory-tab-equipment')));
    await tester.pump();

    final tableFinder = find.byKey(
      const Key('owned-inventory-table-equipment'),
    );
    final initialTable = tester.widget(tableFinder);

    controller.accept(
      kcsapiEvent(
        '/kcsapi/api_req_hensei/change',
        null,
        includeApiData: false,
        requestParams: const <String, Object?>{
          'api_id': '1',
          'api_ship_idx': '1',
          'api_ship_id': '-1',
        },
      ),
    );
    await controller.idle;
    await tester.pump();

    expect(tester.widget(tableFinder), same(initialTable));
    expect(tester.takeException(), isNull);
  });
}
