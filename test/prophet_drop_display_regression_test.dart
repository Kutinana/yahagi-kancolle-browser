import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_controller.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_pills.dart';
import 'package:yahagi_kancolle_browser/src/battle/live_battle_card.dart';
import 'package:yahagi_kancolle_browser/src/battle/prediction/battle_prediction_engine.dart';
import 'package:yahagi_kancolle_browser/src/battle/prediction/battle_prediction_executor.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_reducer.dart';

import 'fixtures/kcsapi_fixtures.dart';

final class _InlineExecutor implements BattlePredictionExecutor {
  const _InlineExecutor();
  @override
  Future<BattlePredictionAppendResult> append({
    required BattlePredictionEngine engine,
    required String path,
    required Map<String, Object?> data,
  }) async =>
      (engine: engine, prediction: engine.append(path: path, data: data));
}

BattleController _controller() {
  final reducer = GameStateReducer();
  final state = reducer.reduce(
    reducer.reduce(GameState.empty, start2Event),
    portEvent,
  );
  final result = BattleController(
    gameState: () => state,
    predictionExecutor: const _InlineExecutor(),
  );
  addTearDown(result.dispose);
  return result;
}

const _mixed = <String, Object?>{
  'api_get_ship': {'api_ship_id': 101},
  'api_get_useitem': {'api_useitem_id': 68, 'api_useitem_name': '秋刀魚'},
  'api_get_exmap_useitem_id': '57',
  'api_get_eventitem': [
    {'api_type': 2, 'api_id': 102, 'api_value': 1},
    {'api_type': 2, 'api_id': 99999, 'api_value': 1},
    {'api_type': 3, 'api_id': 201, 'api_value': 2},
    {'api_type': 3, 'api_id': 99999, 'api_value': 99},
    {'api_type': 5, 'api_id': 99999, 'api_value': 1},
  ],
};

// API payload, expected ship count, expected non-ship reward count.
const _cases = <String, (Map<String, Object?>, int, int)>{
  'empty': ({}, 0, 0),
  'ship only': (
    {
      'api_get_ship': {'api_ship_id': 102},
    },
    1,
    0,
  ),
  'medal only': ({'api_get_exmap_useitem_id': 57}, 0, 1),
  'seasonal item': (
    {
      'api_get_useitem': {'api_useitem_id': 68},
    },
    0,
    1,
  ),
  'single event object': (
    {
      'api_get_eventitem': {'api_type': 3, 'api_id': 201, 'api_value': 2},
    },
    0,
    1,
  ),
  'mixed and unknown masters': (_mixed, 3, 5),
  'event ship only': (
    {
      'api_get_eventitem': {'api_type': 2, 'api_id': 102, 'api_value': 1},
    },
    1,
    0,
  ),
  'invalid optional reward fields': (
    {
      'api_get_ship': <Object?>[],
      'api_get_useitem': 'invalid',
      'api_get_exmap_useitem_id': -1,
      'api_get_eventitem': [
        null,
        12,
        <String, Object?>{},
        {'api_id': 0},
      ],
    },
    0,
    0,
  ),
};

class _Harness extends StatefulWidget {
  const _Harness({
    required this.controller,
    required this.width,
    required this.locale,
    required this.scale,
    super.key,
  });
  final BattleController controller;
  final double width;
  final Locale locale;
  final double scale;
  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  final bucket = PageStorageBucket();
  bool visible = true;
  bool collapsed = false;
  void show(bool value) => setState(() => visible = value);
  @override
  Widget build(BuildContext context) => MaterialApp(
    locale: widget.locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    theme: ThemeData.dark(useMaterial3: true),
    home: Scaffold(
      body: MediaQuery(
        data: MediaQueryData(
          size: const Size(1000, 1000),
          textScaler: TextScaler.linear(widget.scale),
        ),
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: widget.width,
            child: PageStorage(
              bucket: bucket,
              child: SingleChildScrollView(
                key: const PageStorageKey('dashboard-column'),
                child: visible
                    ? LiveBattleCard(
                        key: const PageStorageKey('dashboard-live-battle'),
                        controller: widget.controller,
                        collapsed: collapsed,
                        onToggleCollapse: () =>
                            setState(() => collapsed = !collapsed),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> _frame(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
  expect(tester.takeException(), isNull);
  expect(find.byType(ErrorWidget), findsNothing);
}

Future<void> _mode(WidgetTester tester, bool compact) async {
  await tester.tap(
    find.byKey(Key('battle-mode-${compact ? 'compact' : 'detailed'}')),
  );
  await _frame(tester);
}

Future<void> _result(
  BattleController controller,
  Map<String, Object?> data, {
  int sequence = 200,
}) async {
  controller.accept(
    kcsapiEvent('/kcsapi/api_req_sortie/battleresult', {
      'api_win_rank': 'S',
      ...data,
    }, sequence: sequence),
  );
  await controller.idle;
}

void _checkDrops(
  WidgetTester tester,
  BattleController controller,
  int ships,
  int items,
) {
  final battle = controller.current!;
  expect(battle.effectiveDropShipMasterIds, hasLength(ships));
  expect(battle.rewardItems, hasLength(items));
  expect(find.byType(DropPill), ships == 0 ? findsNothing : findsOneWidget);
  expect(
    find.byType(RewardItemsPill),
    items == 0 ? findsNothing : findsOneWidget,
  );
  if (ships > 0) {
    final names = battle.effectiveDropShipMasterIds
        .map(
          (id) =>
              controller.gameStateSnapshot.masterShips[id]?.name ?? 'ID: $id',
        )
        .join('、');
    final l10n = AppLocalizations.of(tester.element(find.byType(DropPill)))!;
    expect(find.text(l10n.dropLabel(names)), findsOneWidget);
  }
  for (final item in battle.rewardItems) {
    expect(find.text('${item.name} ×${item.count}'), findsOneWidget);
  }
  if (items > 0) {
    final size = tester.getSize(
      find.byKey(const Key('battle-reward-items-pill')),
    );
    expect(size.height, lessThan(45));
    expect(size.width, lessThanOrEqualTo(280));
  }
}

void main() {
  for (final config in <(double, double, Locale)>[
    (240, 1, const Locale('zh')),
    (360, 1.5, const Locale('zh')),
    (640, 1, const Locale('en')),
    (320, 1, const Locale('ja')),
    (320, 1, const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant')),
  ]) {
    for (final compact in [false, true]) {
      for (final entry in _cases.entries) {
        testWidgets(
          'drop lifecycle ${entry.key} width=${config.$1} scale=${config.$2} ${config.$3} compact=$compact',
          (tester) async {
            final controller = _controller();
            controller
              ..accept(mapStartEvent)
              ..accept(dayBattleEvent);
            await controller.idle;
            await tester.pumpWidget(
              _Harness(
                controller: controller,
                width: config.$1,
                scale: config.$2,
                locale: config.$3,
              ),
            );
            await _frame(tester);
            await _mode(tester, !compact);
            await _mode(tester, compact);
            _checkDrops(tester, controller, 0, 0);
            await _result(controller, entry.value.$1);
            await _frame(tester);
            _checkDrops(tester, controller, entry.value.$2, entry.value.$3);
            await _mode(tester, !compact);
            _checkDrops(tester, controller, entry.value.$2, entry.value.$3);
            controller.accept(
              kcsapiEvent('/kcsapi/api_req_map/next', {
                'api_no': 2,
                'api_event_id': 4,
              }, sequence: 201),
            );
            await controller.idle;
            await _frame(tester);
            _checkDrops(tester, controller, 0, 0);
            controller.accept(
              kcsapiEvent(
                dayBattleEvent.path,
                (jsonDecode(dayBattleEvent.responseBody) as Map)['api_data'],
                sequence: 202,
              ),
            );
            await controller.idle;
            await _result(controller, {}, sequence: 203);
            await _frame(tester);
            _checkDrops(tester, controller, 0, 0);
            expect(controller.records.first.battle.rewardItems, isEmpty);
            expect(
              controller.records.last.battle.rewardItems,
              hasLength(entry.value.$3),
            );
          },
        );
      }
    }
  }

  for (final compact in [false, true]) {
    testWidgets(
      'reward scrolling collapse and remount preserve panel mode compact=$compact',
      (tester) async {
        final controller = _controller();
        controller
          ..accept(mapStartEvent)
          ..accept(dayBattleEvent);
        await controller.idle;
        final key = GlobalKey<_HarnessState>();
        await tester.pumpWidget(
          _Harness(
            key: key,
            controller: controller,
            width: 320,
            scale: 1,
            locale: const Locale('zh'),
          ),
        );
        await _frame(tester);
        await _mode(tester, !compact);
        await _mode(tester, compact);
        await _result(controller, _mixed);
        await _frame(tester);
        final scroll = find.descendant(
          of: find.byType(RewardItemsPill),
          matching: find.byType(Scrollable),
        );
        await tester.drag(scroll, const Offset(-180, 0));
        // Damage indicators animate continuously; only settle the scroll gesture.
        await tester.pump(const Duration(seconds: 2));
        await _frame(tester);
        final offset = tester.state<ScrollableState>(scroll).position.pixels;
        expect(offset, greaterThan(0));
        await tester.tap(find.bySemanticsLabel('折叠未卜先知'));
        await _frame(tester);
        expect(find.byType(RewardItemsPill), findsNothing);
        await tester.tap(find.bySemanticsLabel('展开未卜先知'));
        await _frame(tester);
        expect(
          tester.state<ScrollableState>(scroll).position.pixels,
          closeTo(offset, 1),
        );
        key.currentState!.show(false);
        await _frame(tester);
        key.currentState!.show(true);
        await _frame(tester);
        expect(
          find.byKey(
            Key(compact ? 'compact-battle-panel' : 'detailed-battle-panel'),
          ),
          findsOneWidget,
        );
        expect(
          tester.state<ScrollableState>(scroll).position.pixels,
          closeTo(offset, 1),
        );
        _checkDrops(tester, controller, 3, 5);
        // Rotation/reflow must not mix the scroll offset with the saved mode.
        await tester.pumpWidget(
          _Harness(
            key: key,
            controller: controller,
            width: 640,
            scale: 1.5,
            locale: const Locale('zh'),
          ),
        );
        await _frame(tester);
        _checkDrops(tester, controller, 3, 5);
        await _mode(tester, !compact);
        _checkDrops(tester, controller, 3, 5);
      },
    );

    testWidgets(
      'navigation resource and long item rewards fit narrow card compact=$compact',
      (tester) async {
        final controller = _controller();
        final key = GlobalKey<_HarnessState>();
        await tester.pumpWidget(
          _Harness(
            key: key,
            controller: controller,
            width: 240,
            scale: 1.5,
            locale: const Locale('zh'),
          ),
        );
        await _frame(tester);
        await _mode(tester, compact);
        controller.accept(
          kcsapiEvent('/kcsapi/api_req_map/next', {
            'api_maparea_id': 2,
            'api_mapinfo_no': 5,
            'api_no': 2,
            'api_event_id': 2,
            'api_itemget': [
              for (var id = 1; id <= 4; id++)
                {'api_usemst': 4, 'api_id': id, 'api_getcount': 999},
              {
                'api_usemst': 11,
                'api_id': 901,
                'api_getcount': 2,
                'api_name': '特别活动作战纪念兑换券超长名称',
              },
              {
                'api_usemst': 11,
                'api_id': 902,
                'api_getcount': 3,
                'api_name': '试制甲板弹用改修资材箱',
              },
            ],
          }, sequence: 300),
        );
        await controller.idle;
        await _frame(tester);
        expect(find.text('+999'), findsNWidgets(4));
        _checkDrops(tester, controller, 0, 2);
        final resources = find.descendant(
          of: find.byType(ResourceChangesPill),
          matching: find.byType(Scrollable),
        );
        final items = find.descendant(
          of: find.byType(RewardItemsPill),
          matching: find.byType(Scrollable),
        );
        await tester.drag(resources, const Offset(-75, 0));
        await tester.pump(const Duration(seconds: 2));
        await _frame(tester);
        final resourceOffset = tester
            .state<ScrollableState>(resources)
            .position
            .pixels;
        expect(resourceOffset, greaterThan(0));
        expect(tester.state<ScrollableState>(items).position.pixels, 0);
        await tester.drag(items, const Offset(-140, 0));
        await tester.pump(const Duration(seconds: 2));
        await _frame(tester);
        final itemOffset = tester.state<ScrollableState>(items).position.pixels;
        expect(itemOffset, greaterThan(0));
        expect(
          tester.state<ScrollableState>(resources).position.pixels,
          resourceOffset,
        );
        key.currentState!.show(false);
        await _frame(tester);
        key.currentState!.show(true);
        await _frame(tester);
        expect(
          tester.state<ScrollableState>(resources).position.pixels,
          resourceOffset,
        );
        expect(
          tester.state<ScrollableState>(items).position.pixels,
          itemOffset,
        );
        // A subsequent short reward must clamp the old horizontal offset.
        controller.accept(
          kcsapiEvent('/kcsapi/api_req_map/next', {
            'api_no': 3,
            'api_event_id': 2,
            'api_itemget': {'api_usemst': 11, 'api_id': 57, 'api_getcount': 1},
          }, sequence: 301),
        );
        await controller.idle;
        await _frame(tester);
        expect(find.byType(ResourceChangesPill), findsNothing);
        expect(tester.state<ScrollableState>(items).position.pixels, 0);
        expect(find.text('勋章 ×1'), findsOneWidget);
      },
    );
  }
}
