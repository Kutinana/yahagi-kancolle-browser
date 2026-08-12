import 'package:flutter/material.dart';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_controller.dart';
import 'package:yahagi_kancolle_browser/src/inventory/owned_inventory_page.dart';

import 'fixtures/kcsapi_fixtures.dart';

void main() {
  setUp(() => GameStateController.disableTimerForTest = true);

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
    expect(find.text('筛选结果 '), findsOneWidget);
    expect(find.byKey(const Key('ship-table-frozen-header')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('装备 0'));
    await tester.pump();

    expect(find.byKey(const Key('equipment-filter-all')), findsOneWidget);
    expect(find.byKey(const Key('equipment-filter-support')), findsOneWidget);
    expect(
      find.byKey(const Key('equipment-table-frozen-header')),
      findsOneWidget,
    );
    expect(find.text('总数（剩余）'), findsOneWidget);
    expect(find.text('改修／熟练度'), findsOneWidget);
    expect(find.text('着装情况'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps both filter rows equally compact on a square foldable', (
    tester,
  ) async {
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
    await tester.tap(find.text('装备 0'));
    await tester.pump();
    final equipmentHeight = tester
        .getSize(find.byKey(const Key('equipment-filter-all')))
        .height;

    expect(shipHeight, equipmentHeight);
    expect(shipHeight, lessThanOrEqualTo(30));
    expect(tester.takeException(), isNull);
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
    final bodyScrollable = find.descendant(
      of: bodyList,
      matching: find.byType(Scrollable),
    );
    expect(bodyList, findsOneWidget);
    expect(bodyScrollable, findsOneWidget);

    await tester.scrollUntilVisible(
      lastPortrait,
      500,
      scrollable: bodyScrollable,
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
      final bodyScrollable = find.descendant(
        of: bodyListFinder,
        matching: find.byType(Scrollable),
      );
      await tester.drag(bodyScrollable, const Offset(0, -500));
      await tester.pump();

      final bodyList = tester.widget<ListView>(bodyListFinder);
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
      final horizontalScrollable = find.descendant(
        of: horizontalFinder,
        matching: find.byType(Scrollable),
      );
      expect(horizontalFinder, findsOneWidget);
      await tester.drag(horizontalScrollable.first, const Offset(-500, 0));
      await tester.pump();

      final horizontal = tester.widget<SingleChildScrollView>(horizontalFinder);
      final header = tester.widget<SingleChildScrollView>(
        find.byKey(const Key('owned-inventory-header-scroll')),
      );
      expect(horizontal.controller!.offset, greaterThan(0));
      expect(
        header.controller!.offset,
        closeTo(horizontal.controller!.offset, 0.1),
      );
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
