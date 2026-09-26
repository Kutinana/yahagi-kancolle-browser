import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_controller.dart';
import 'package:yahagi_kancolle_browser/src/battle/live_battle_card.dart';
import 'package:yahagi_kancolle_browser/src/battle/prediction/battle_prediction_engine.dart';
import 'package:yahagi_kancolle_browser/src/battle/prediction/battle_prediction_executor.dart';
import 'package:yahagi_kancolle_browser/src/bridge/captured_api_event.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_workspace_visibility.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_reducer.dart';

import 'fixtures/kcsapi_fixtures.dart';

final _popover = find.byKey(const Key('battle-ship-details-popover'));

Map<String, Object?> _data(CapturedApiEvent event) => Map<String, Object?>.from(
  (jsonDecode(event.responseBody) as Map)['api_data'] as Map,
);

BattleController _controller({
  bool combined = false,
  ValueNotifier<GameState>? stateHolder,
}) {
  final reducer = GameStateReducer();
  final port = _data(portEvent);
  final ships = port['api_ship']! as List;
  ships[0] = Map<String, Object?>.from(ships[0] as Map)..['api_slot_ex'] = 7003;
  final masterData = _data(start2Event);
  masterData['api_mst_ship'] = [
    ...masterData['api_mst_ship']! as List,
    {
      'api_id': 501,
      'api_name': '空母ヲ級',
      'api_stype': 11,
      'api_yomi': 'flagship',
    },
  ];
  var state = reducer.reduce(
    GameState.empty,
    kcsapiEvent(start2Event.path, masterData),
  );
  state = reducer.reduce(state, kcsapiEvent(portEvent.path, port));
  state = reducer.reduce(state, slotItemEvent);
  if (combined) {
    state = state.copyWith(
      combinedFleetType: CombinedFleetType.carrierTaskForce,
      fleets: const [
        Fleet(id: 1, name: 'Main', shipIds: [9001]),
        Fleet(id: 2, name: 'Escort', shipIds: [9002]),
      ],
    );
  }
  stateHolder?.value = state;
  final controller = BattleController(
    gameState: () => stateHolder?.value ?? state,
    predictionExecutor: const _InlineExecutor(),
  );
  addTearDown(controller.dispose);
  return controller;
}

CapturedApiEvent _battle({bool withDetails = true}) {
  final data = _data(dayBattleEvent)
    // Equal master IDs must still expose each position's own battle data.
    ..['api_ship_ke'] = [501, 501]
    ..['api_ship_lv'] = [17, 28];
  if (withDetails) {
    data['api_eParam'] = [
      [25, 26, 68, 80],
      [11, 12, 13, 14],
    ];
    data['api_eSlot'] = [
      [201, 202, -1],
      [-1, -1],
    ];
  }
  return kcsapiEvent(dayBattleEvent.path, data, sequence: 21);
}

Future<void> _pumpCard(
  WidgetTester tester,
  BattleController controller, {
  bool compact = false,
  bool collapsed = false,
  bool workspaceActive = true,
  Rect? panelBounds,
  double textScale = 1,
}) async {
  final panel = SingleChildScrollView(
    child: GameWorkspaceActive(
      active: workspaceActive,
      child: Offstage(
        offstage: !workspaceActive,
        child: LiveBattleCard(
          key: const PageStorageKey('dashboard-live-battle'),
          controller: controller,
          collapsed: collapsed,
          onToggleCollapse: () {},
          showEnemyPortraits: false,
        ),
      ),
    ),
  );
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: SafeArea(
          child: SizedBox.expand(
            child: panelBounds == null
                ? panel
                : Stack(
                    children: [
                      Positioned.fromRect(rect: panelBounds, child: panel),
                    ],
                  ),
          ),
        ),
      ),
    ),
  );
  if (compact) {
    await tester.tap(find.byKey(const Key('battle-mode-compact')));
    await tester.pump();
  }
}

Future<void> _startBattle(BattleController controller) async {
  controller.accept(mapStartEvent);
  controller.accept(_battle());
  await controller.idle;
}

Finder _row(String side, int position, {bool compact = false}) => find
    .ancestor(
      of: find.byKey(
        Key('${compact ? 'compact-bar' : 'battle-ship'}-$side-$position'),
      ),
      matching: find.byType(InkWell),
    )
    .first;

Finder _detailText(String value) =>
    find.descendant(of: _popover, matching: find.text(value));

void main() {
  testWidgets(
    'opening details reads newly received proficiency without another battle phase',
    (tester) async {
      final stateHolder = ValueNotifier<GameState>(GameState.empty);
      addTearDown(stateHolder.dispose);
      final controller = _controller(stateHolder: stateHolder);
      await _startBattle(controller);
      await _pumpCard(tester, controller);
      stateHolder.value = stateHolder.value.copyWith(
        slotItems: {
          ...stateHolder.value.slotItems,
          7002: const OwnedSlotItem(
            instanceId: 7002,
            masterSlotItemId: 202,
            proficiency: 7,
          ),
        },
      );
      await tester.tap(_row('friend', 0));
      await tester.pump();
      final icon = find.descendant(
        of: _popover,
        matching: find.byKey(const Key('battle-equipment-proficiency-202')),
      );
      expect(
        (tester.widget<Image>(icon).image as AssetImage).assetName,
        'assets/images/airplane/alv7.png',
      );
    },
  );

  for (final compact in [false, true]) {
    testWidgets(
      'friendly aircraft uses the fleet proficiency rank icon (compact: $compact)',
      (tester) async {
        final controller = _controller();
        await _startBattle(controller);
        await _pumpCard(tester, controller, compact: compact);
        await tester.tap(_row('friend', 0, compact: compact));
        await tester.pump();

        final icons = find.descendant(
          of: _popover,
          matching: find.byKey(const Key('battle-equipment-proficiency-202')),
        );
        expect(icons, findsOneWidget);
        expect(
          (tester.widget<Image>(icons).image as AssetImage).assetName,
          'assets/images/airplane/alv6.png',
        );
        expect(_detailText('≫ 6'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('friendly progression aligns with level and fuel', (
    tester,
  ) async {
    final controller = _controller();
    await _startBattle(controller);
    await _pumpCard(tester, controller);
    await tester.tap(_row('friend', 0));
    await tester.pump();
    final next = find.byKey(const Key('battle-ship-next'));
    final remodel = find.byKey(const Key('battle-ship-remodel'));
    expect(next, findsOneWidget);
    expect(remodel, findsOneWidget);
    expect(
      tester.getTopLeft(next).dx,
      tester.getTopLeft(find.byKey(const Key('battle-ship-level'))).dx,
    );
    expect(
      tester.getTopLeft(remodel).dx,
      tester.getTopLeft(find.byKey(const Key('battle-ship-fuel'))).dx,
    );
    expect(tester.widget<Text>(next).style?.fontSize, 12);
    expect(tester.widget<Text>(remodel).style?.fontSize, 12);
    expect(tester.takeException(), isNull);
  });

  testWidgets('large system text remains usable inside a narrow panel', (
    tester,
  ) async {
    final controller = _controller();
    await _startBattle(controller);
    await _pumpCard(
      tester,
      controller,
      textScale: 2,
      panelBounds: const Rect.fromLTWH(500, 0, 300, 600),
    );
    await tester.tap(_row('enemy', 0));
    await tester.pump();
    expect(_popover, findsOneWidget);
    expect(tester.takeException(), isNull);
    final rect = tester.getRect(_popover);
    expect(rect.left, greaterThanOrEqualTo(500));
    expect(rect.right, lessThanOrEqualTo(800));
    expect(rect.bottom, lessThanOrEqualTo(600));
    await tester.tap(find.byKey(const Key('battle-ship-details-close')));
    await tester.pump();
    expect(_popover, findsNothing);
  });

  testWidgets('resizing the information panel dismisses stale popover bounds', (
    tester,
  ) async {
    final controller = _controller();
    await _startBattle(controller);
    await _pumpCard(
      tester,
      controller,
      panelBounds: const Rect.fromLTWH(400, 0, 400, 600),
    );
    await tester.tap(_row('enemy', 0));
    await tester.pump();
    expect(_popover, findsOneWidget);
    await _pumpCard(
      tester,
      controller,
      panelBounds: const Rect.fromLTWH(550, 0, 250, 600),
    );
    await tester.pump();
    expect(_popover, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('covering the card with another route clears its back entry', (
    tester,
  ) async {
    final controller = _controller();
    await _startBattle(controller);
    await _pumpCard(tester, controller);
    await tester.tap(_row('enemy', 0));
    await tester.pump();
    final context = tester.element(find.byType(LiveBattleCard));
    final route = ModalRoute.of(context)!;
    final navigator = Navigator.of(context);
    navigator.push(MaterialPageRoute<void>(builder: (_) => const Scaffold()));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(route.willHandlePopInternally, isFalse);
    navigator.pop();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(_popover, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('rapid programmatic ship switches leave only one back entry', (
    tester,
  ) async {
    final controller = _controller();
    await _startBattle(controller);
    await _pumpCard(tester, controller);
    for (var i = 0; i < 12; i++) {
      tester.widget<InkWell>(_row(i.isEven ? 'enemy' : 'friend', 0)).onTap!();
      await tester.pump();
      expect(_popover, findsOneWidget);
    }
    final context = tester.element(find.byType(LiveBattleCard));
    final route = ModalRoute.of(context)!;
    await Navigator.of(context).maybePop();
    await tester.pump();
    expect(_popover, findsNothing);
    expect(route.willHandlePopInternally, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('details open after switching compact then detailed mode', (
    tester,
  ) async {
    final controller = _controller();
    await _startBattle(controller);
    await _pumpCard(tester, controller, compact: true);
    await tester.tap(find.byKey(const Key('battle-mode-detailed')));
    await tester.pump();
    for (final side in ['enemy', 'friend']) {
      await tester.tap(_row(side, 0));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(_popover, findsOneWidget);
      expect(find.byType(ErrorWidget), findsNothing);
      // Even saving a scroll offset must not replace the card's String mode.
      await tester.drag(
        find.descendant(of: _popover, matching: find.byType(Scrollable)).first,
        const Offset(0, -60),
      );
      await tester.pump(const Duration(seconds: 1));
      final cardContext = tester.element(find.byType(LiveBattleCard));
      expect(PageStorage.of(cardContext).readState(cardContext), 'detailed');
      await tester.tap(find.byKey(const Key('battle-ship-details-close')));
      await tester.pump();
    }
  });

  for (final compact in [false, true]) {
    testWidgets('battle enemy opens captured details (compact: $compact)', (
      tester,
    ) async {
      final controller = _controller();
      await _startBattle(controller);
      await _pumpCard(tester, controller, compact: compact);

      await tester.tap(_row('enemy', 0, compact: compact));
      await tester.pump();

      expect(_popover, findsOneWidget);
      expect(_detailText('Flagship'), findsOneWidget);
      for (final text in ['Lv. 17', '28', '26', '71', '80']) {
        expect(_detailText(text), findsOneWidget);
      }
      expect(_detailText('12.7cm 连装炮'), findsOneWidget);
      expect(_detailText('零式水上侦察机'), findsOneWidget);
      expect(_detailText('—'), findsAtLeastNWidgets(2));
      expect(_detailText('100%'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'navigation friendly opens supply and equipment (compact: $compact)',
      (tester) async {
        final controller = _controller();
        controller.accept(mapStartEvent);
        await controller.idle;
        await _pumpCard(tester, controller, compact: compact);

        // Navigation shares the full friendly rows in both display modes.
        await tester.tap(_row('friend', 0));
        await tester.pump();

        expect(_popover, findsOneWidget);
        for (final text in ['Lv. 50', '100%', '87%', '55', '42', '38', '46']) {
          expect(_detailText(text), findsOneWidget);
        }
        expect(_detailText('12.7cm 连装炮'), findsNWidgets(2));
        expect(_detailText('★+4'), findsOneWidget);
        expect(_detailText('三式水中探信仪'), findsOneWidget);
        expect(_detailText('增设'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'same ship toggles and another position replaces details (compact: $compact)',
      (tester) async {
        final controller = _controller();
        await _startBattle(controller);
        await _pumpCard(tester, controller, compact: compact);
        final first = _row('enemy', 0, compact: compact);
        final second = _row('enemy', 1, compact: compact);

        await tester.tap(first);
        await tester.pump();
        expect(_detailText('Lv. 17'), findsOneWidget);
        await tester.tap(first);
        await tester.pump();
        expect(_popover, findsNothing);

        await tester.tap(first);
        await tester.pump();
        await tester.tap(second);
        await tester.pump();
        expect(_popover, findsOneWidget);
        expect(_detailText('Lv. 28'), findsOneWidget);
        expect(_detailText('Lv. 17'), findsNothing);
        expect(_detailText('13'), findsOneWidget);
        expect(_detailText('12.7cm 连装炮'), findsNothing);
      },
    );
  }

  testWidgets('close button, outside click, Escape and back dismiss details', (
    tester,
  ) async {
    final controller = _controller();
    await _startBattle(controller);
    await _pumpCard(tester, controller);

    Future<void> open() async {
      await tester.tap(_row('friend', 0));
      await tester.pump();
      expect(_popover, findsOneWidget);
    }

    await open();
    await tester.tap(find.byKey(const Key('battle-ship-details-close')));
    await tester.pump();
    expect(_popover, findsNothing);

    await open();
    await tester.tapAt(const Offset(790, 590));
    await tester.pump();
    expect(_popover, findsNothing);

    await open();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(_popover, findsNothing);

    await open();
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(_popover, findsNothing);
    expect(find.byType(LiveBattleCard), findsOneWidget);
  });

  testWidgets('missing enemy fields stay unknown', (tester) async {
    final controller = _controller();
    controller.accept(mapStartEvent);
    controller.accept(_battle(withDetails: false));
    await controller.idle;
    await _pumpCard(tester, controller);
    await tester.tap(_row('enemy', 0));
    await tester.pump();

    expect(_detailText('Lv. 17'), findsOneWidget);
    expect(_detailText('—'), findsAtLeastNWidgets(6));
    expect(_detailText('12.7cm 连装炮'), findsNothing);
    expect(_detailText('100%'), findsNothing);
  });

  for (final viewport in [const Size(320, 640), const Size(740, 320)]) {
    testWidgets('details stay within safe viewport $viewport', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = viewport;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      const padding = EdgeInsets.fromLTRB(8, 24, 8, 16);
      tester.view.padding = const FakeViewPadding(
        left: 8,
        top: 24,
        right: 8,
        bottom: 16,
      );
      tester.view.viewPadding = const FakeViewPadding(
        left: 8,
        top: 24,
        right: 8,
        bottom: 16,
      );
      addTearDown(tester.view.resetPadding);
      addTearDown(tester.view.resetViewPadding);
      final controller = _controller();
      await _startBattle(controller);
      await _pumpCard(tester, controller);
      await tester.tap(_row('friend', 0));
      await tester.pump();

      expect(_popover, findsOneWidget);
      final rect = tester.getRect(_popover);
      expect(rect.left, greaterThanOrEqualTo(padding.left));
      expect(rect.top, greaterThanOrEqualTo(padding.top));
      expect(rect.right, lessThanOrEqualTo(viewport.width - padding.right));
      expect(rect.bottom, lessThanOrEqualTo(viewport.height - padding.bottom));
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const Key('battle-ship-details-close')));
      await tester.pump();
      expect(_popover, findsNothing);
    });
  }

  for (final bounds in [
    const Rect.fromLTWH(400, 0, 400, 600),
    const Rect.fromLTWH(0, 300, 800, 300),
  ]) {
    testWidgets('details remain in information panel $bounds', (tester) async {
      final controller = _controller();
      await _startBattle(controller);
      await _pumpCard(tester, controller, panelBounds: bounds);
      await tester.tap(_row('friend', 0));
      await tester.pump();

      expect(_popover, findsOneWidget);
      final rect = tester.getRect(_popover);
      expect(rect.left, greaterThanOrEqualTo(bounds.left));
      expect(rect.top, greaterThanOrEqualTo(bounds.top));
      expect(rect.right, lessThanOrEqualTo(bounds.right));
      expect(rect.bottom, lessThanOrEqualTo(bounds.bottom));
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const Key('battle-ship-details-close')));
      await tester.pump();
      expect(_popover, findsNothing);
    });
  }

  testWidgets('next node removes old enemy details', (tester) async {
    final controller = _controller();
    await _startBattle(controller);
    await _pumpCard(tester, controller);
    await tester.tap(_row('enemy', 0));
    await tester.pump();
    expect(_detailText('Lv. 17'), findsOneWidget);

    controller.accept(
      kcsapiEvent(
        '/kcsapi/api_req_map/next',
        _data(mapStartEvent)..['api_no'] = 2,
        sequence: 24,
      ),
    );
    await controller.idle;
    await tester.pump();
    await tester.pump();
    expect(_popover, findsNothing);
    expect(find.byKey(const Key('battle-ship-enemy-0')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mode switch and collapse clear an open popover', (tester) async {
    final controller = _controller();
    await _startBattle(controller);
    await _pumpCard(tester, controller);
    await tester.tap(_row('enemy', 0));
    await tester.pump();
    expect(_popover, findsOneWidget);

    await tester.tap(find.byKey(const Key('battle-mode-compact')));
    await tester.pump();
    await tester.pump();
    expect(_popover, findsNothing);
    await tester.tap(_row('enemy', 0, compact: true));
    await tester.pump();
    expect(_popover, findsOneWidget);

    await _pumpCard(tester, controller, collapsed: true);
    await tester.pump();
    expect(_popover, findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('programmatic workspace switch clears details and back history', (
    tester,
  ) async {
    final controller = _controller();
    await _startBattle(controller);
    await _pumpCard(tester, controller);
    await tester.tap(_row('enemy', 0));
    await tester.pump();
    final route = ModalRoute.of(tester.element(find.byType(LiveBattleCard)))!;
    expect(_popover, findsOneWidget);
    expect(route.willHandlePopInternally, isTrue);

    // No pointer event: exercise keyboard/programmatic navigation too.
    await _pumpCard(tester, controller, workspaceActive: false);
    await tester.pump();
    expect(_popover, findsNothing);
    expect(route.willHandlePopInternally, isFalse);

    await _pumpCard(tester, controller);
    await tester.pump();
    expect(_popover, findsNothing);
    expect(route.willHandlePopInternally, isFalse);
    expect(tester.takeException(), isNull);
  });

  for (final compact in [false, true]) {
    testWidgets(
      'combined escort rows retain their fleet identity (compact: $compact)',
      (tester) async {
        final controller = _controller(combined: true);
        controller.accept(mapStartEvent);
        controller.accept(
          kcsapiEvent('/kcsapi/api_req_combined_battle/each_battle', {
            'api_deck_id': 1,
            'api_formation': [1, 1, 1],
            'api_f_nowhps': [30],
            'api_f_maxhps': [30],
            'api_f_nowhps_combined': [15],
            'api_f_maxhps_combined': [15],
            'api_ship_ke': [501],
            'api_ship_lv': [17],
            'api_e_nowhps': [20],
            'api_e_maxhps': [20],
            'api_eParam': [
              [25, 26, 68, 80],
            ],
            'api_eSlot': [
              [201],
            ],
            'api_ship_ke_combined': [501],
            'api_ship_lv_combined': [39],
            'api_e_nowhps_combined': [57],
            'api_e_maxhps_combined': [57],
            'api_eParam_combined': [
              [31, 32, 33, 34],
            ],
            'api_eSlot_combined': [
              [202],
            ],
          }, sequence: 21),
        );
        await controller.idle;
        await _pumpCard(tester, controller, compact: compact);

        await tester.tap(
          _row(
            compact ? 'enemy-escort' : 'enemy',
            compact ? 0 : 6,
            compact: compact,
          ),
        );
        await tester.pump();
        expect(_detailText('Lv. 39'), findsOneWidget);
        expect(_detailText('31'), findsOneWidget);
        expect(_detailText('零式水上侦察机'), findsOneWidget);

        await tester.tap(find.byKey(const Key('battle-ship-details-close')));
        await tester.pump();
        await tester.tap(
          _row(
            compact ? 'friend-escort' : 'friend',
            compact ? 0 : 6,
            compact: compact,
          ),
        );
        await tester.pump();
        expect(_detailText('Lv. 44'), findsOneWidget);
        expect(_detailText('53%'), findsOneWidget);
        expect(_detailText('50%'), findsOneWidget);
        expect(_detailText('12.7cm 连装炮'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

class _InlineExecutor implements BattlePredictionExecutor {
  const _InlineExecutor();

  @override
  Future<BattlePredictionAppendResult> append({
    required BattlePredictionEngine engine,
    required String path,
    required Map<String, Object?> data,
  }) async =>
      (engine: engine, prediction: engine.append(path: path, data: data));
}
