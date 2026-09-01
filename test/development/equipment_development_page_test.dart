import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/development/development_repository.dart';
import 'package:yahagi_kancolle_browser/src/development/equipment_development_page.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';

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
    await tester.tap(find.byKey(const Key('development-apply-recipe-0')));
    await tester.pumpAndSettle();
    expect(find.text('11'), findsWidgets);
  });
}

Widget _app({required Size size}) => MediaQuery(
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
    home: Scaffold(
      body: EquipmentDevelopmentPage(
        state: _state,
        repository: DevelopmentRepository(
          loadString: (_) async => jsonEncode(_snapshot),
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
  },
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
    'pool_count': 1,
    'selectable_pool_count': 1,
    'equipment_count': 2,
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
  ],
  'pools': [
    {
      'pool_key': 'carrier-akagi#1',
      'name': 'carrier-akagi',
      'labels': {'zh': '空母系-赤城', 'zh_Hant': '空母系-赤城', 'ja': '空母系-赤城'},
      'pool_id': 1,
      'ship_ids': [101],
      'drop_rates': {'7': 2, '8': 1},
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
