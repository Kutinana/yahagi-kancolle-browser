import 'dart:convert';
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/development/development_repository.dart';
import 'package:yahagi_kancolle_browser/src/development/equipment_development_page.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/widgets/top_notice.dart';

void main() {
  testWidgets('command dashboard has no persistent search field', (
    tester,
  ) async {
    await tester.pumpWidget(_app(size: const Size(1000, 700)));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('development-command-card')), findsOneWidget);
    expect(find.byKey(const Key('development-wide-layout')), findsOneWidget);
    expect(find.byKey(const Key('development-inline-search')), findsNothing);
    expect(find.text('开发指挥台'), findsOneWidget);
    expect(find.text('其他出货  3%'), findsOneWidget);
    expect(find.byKey(const Key('development-rate-details-7')), findsOneWidget);
    expect(find.byKey(const Key('development-minimum-7')), findsOneWidget);
    expect(find.byKey(const Key('development-rate-details-10')), findsNothing);
  });

  testWidgets('target sheet uses a round button to open the search dialog', (
    tester,
  ) async {
    await tester.pumpWidget(_app(size: const Size(390, 844)));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('development-open-target-picker')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('development-target-sheet')), findsOneWidget);
    expect(find.byKey(const Key('development-inline-search')), findsNothing);

    await tester.tap(find.byKey(const Key('development-search-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('development-search-dialog')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('development-search-dialog')),
        matching: find.byType(TextField),
      ),
      findsOneWidget,
    );
  });

  testWidgets('selecting a target produces recipe rows that can be applied', (
    tester,
  ) async {
    await tester.pumpWidget(_app(size: const Size(1000, 700)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('development-open-target-picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('development-equipment-7')));
    await tester.pumpAndSettle();
    Navigator.of(
      tester.element(find.byKey(const Key('development-target-sheet'))),
    ).pop();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('development-recipe-row-0')), findsOneWidget);
    await tester.tap(find.byKey(const Key('development-recipe-row-0')));
    await tester.pumpAndSettle();
    expect(find.text('11'), findsWidgets);
    expect(find.text('铝土系'), findsWidgets);
    expect(
      tester
          .getSemantics(find.byKey(const Key('development-recipe-row-0')))
          .flagsCollection
          .isSelected,
      Tristate.isTrue,
    );
  });

  testWidgets('resource input updates immediately and normalizes on blur', (
    tester,
  ) async {
    await tester.pumpWidget(_app(size: const Size(1000, 700)));
    await tester.pumpAndSettle();
    final fuel = find.byType(TextFormField).first;

    await tester.enterText(fuel, '20');
    await tester.pump();
    expect(tester.widget<TextFormField>(fuel).controller!.text, '20');

    await tester.enterText(fuel, '9');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(tester.widget<TextFormField>(fuel).controller!.text, '10');
  });

  testWidgets('incompatible equipment stays visible but disabled', (
    tester,
  ) async {
    await tester.pumpWidget(_app(size: const Size(390, 844)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('development-open-target-picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('development-equipment-7')));
    await tester.pumpAndSettle();

    final incompatible = find.byKey(const Key('development-equipment-9'));
    expect(incompatible, findsOneWidget);
    expect(tester.widget<ListTile>(incompatible).enabled, isFalse);
  });

  testWidgets('search trims confirmation and cancel preserves prior query', (
    tester,
  ) async {
    await tester.pumpWidget(_app(size: const Size(390, 844)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('development-open-target-picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('development-search-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('development-search-dialog')),
        matching: find.byType(TextField),
      ),
      '  雷达  ',
    );
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(InputChip, '雷达'), findsOneWidget);

    await tester.tap(find.byKey(const Key('development-search-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('development-search-dialog')),
        matching: find.byType(TextField),
      ),
      '主炮',
    );
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(InputChip, '雷达'), findsOneWidget);
  });

  testWidgets('unsupported current flagship keeps pool and shows notice', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(size: const Size(1000, 700), state: _stateWithUnknownFlagship),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ActionChip, '当前旗舰: 未知旗舰'));
    await tester.pump();

    expect(find.text('当前旗舰没有可用的开发池，已保留原选择'), findsOneWidget);
  });
}

Widget _app({required Size size, GameState state = _state}) => MediaQuery(
  data: MediaQueryData(size: size),
  child: MaterialApp(
    locale: const Locale('zh'),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: TopNoticeHost(
      child: Scaffold(
        body: EquipmentDevelopmentPage(
          state: state,
          repository: DevelopmentRepository(
            loadString: (_) async => jsonEncode(_snapshot),
          ),
        ),
      ),
    ),
  ),
);

const _state = GameState(
  hasPortData: true,
  ships: {1: OwnedShip(id: 1, masterId: 101, level: 1)},
  fleets: [
    Fleet(id: 1, name: '第一舰队', shipIds: [1]),
  ],
  masterShips: {101: MasterShip(id: 101, name: '赤城', shipTypeId: 11)},
  masterSlotItems: {
    7: MasterSlotItem(id: 7, name: '测试舰攻', type: [0, 0, 8]),
    8: MasterSlotItem(id: 8, name: '测试雷达', type: [0, 0, 12]),
    9: MasterSlotItem(id: 9, name: '测试爆雷', type: [0, 0, 15]),
    10: MasterSlotItem(id: 10, name: '高耗测试装备', type: [0, 0, 1]),
  },
);

const _stateWithUnknownFlagship = GameState(
  hasPortData: true,
  ships: {2: OwnedShip(id: 2, masterId: 999, level: 1)},
  fleets: [
    Fleet(id: 1, name: '第一舰队', shipIds: [2]),
  ],
  masterShips: {999: MasterShip(id: 999, name: '未知旗舰', shipTypeId: 2)},
);

final _snapshot = <String, Object?>{
  'schema_version': 1,
  'generated_at': '2026-09-01T00:00:00.000Z',
  'source': {
    'repository': 'https://example.invalid',
    'commit': 'abc',
    'hashes': {'pool': 'hash'},
  },
  'summary': {
    'pool_count': 3,
    'selectable_pool_count': 3,
    'equipment_count': 4,
    'negative_pool_count': 0,
    'minimum_resource_pool_count': 0,
  },
  'equipment': [
    {
      'id': 7,
      'name': '测试舰攻',
      'type_id': 8,
      'minimum_resources': [10, 10, 10, 10],
    },
    {
      'id': 8,
      'name': '测试雷达',
      'type_id': 12,
      'minimum_resources': [10, 10, 10, 10],
    },
    {
      'id': 9,
      'name': '测试爆雷',
      'type_id': 15,
      'minimum_resources': [10, 10, 10, 10],
    },
    {
      'id': 10,
      'name': '高耗测试装备',
      'type_id': 1,
      'minimum_resources': [20, 20, 20, 20],
    },
  ],
  'pools': [
    {
      'pool_key': 'carrier-akagi#1',
      'name': 'carrier-akagi',
      'labels': {'zh': '空母系-赤城', 'zh_Hant': '空母系-赤城', 'ja': '空母系-赤城'},
      'pool_id': 1,
      'ship_ids': [101],
      'drop_rates': {'7': 2, '8': 1, '10': 1},
      'criteria': {
        'ship_types': <Object?>[],
        'class_types': <Object?>[],
        'ship_names': <Object?>[],
        'ship_ids': <Object?>[],
        'excluded_ship_ids': <Object?>[],
      },
    },
    {
      'pool_key': 'depth-charge#1',
      'name': 'depth-charge',
      'labels': {'zh': '爆雷系', 'zh_Hant': '爆雷系', 'ja': '爆雷系'},
      'pool_id': 1,
      'ship_ids': [202],
      'drop_rates': {'9': 2},
      'criteria': {
        'ship_types': <Object?>[],
        'class_types': <Object?>[],
        'ship_names': <Object?>[],
        'ship_ids': <Object?>[],
        'excluded_ship_ids': <Object?>[],
      },
    },
    {
      'pool_key': 'carrier-akagi#3',
      'name': 'carrier-akagi',
      'labels': {'zh': '空母系-赤城', 'zh_Hant': '空母系-赤城', 'ja': '空母系-赤城'},
      'pool_id': 3,
      'ship_ids': [101],
      'drop_rates': {'7': 2, '8': 1, '10': 1},
      'criteria': {
        'ship_types': <Object?>[],
        'class_types': <Object?>[],
        'ship_names': <Object?>[],
        'ship_ids': <Object?>[],
        'excluded_ship_ids': <Object?>[],
      },
    },
  ],
  'secretaries': [
    {'ship_id': 101, 'pool_key': 'carrier-akagi#1'},
  ],
};
