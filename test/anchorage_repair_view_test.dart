import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/bridge/captured_api_event.dart';
import 'package:yahagi_kancolle_browser/src/fleet/anchorage_repair_view.dart';
import 'package:yahagi_kancolle_browser/src/fleet/fleet_information_center.dart';
import 'package:yahagi_kancolle_browser/src/fleet/ship_portrait.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_controller.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_reducer.dart';
import 'package:yahagi_kancolle_browser/src/layout/workspace_context_header.dart';

import 'anchorage_repair_calculator_test.dart' show buildAnchorageTestState;

const _longShipName = '超长测试舰娘名称改二型甲完全版';

void main() {
  setUp(() => GameStateController.disableTimerForTest = true);

  testWidgets('right aligns the repair modes in a rounded segmented capsule', (
    tester,
  ) async {
    await _setSurfaceSize(tester, const Size(1180, 720));
    final controller = await _controller();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 44,
            child: WorkspaceContextHeader(
              workspaceIndex: 3,
              state: controller.state,
              selectedFleetId: 1,
            ),
          ),
        ),
      ),
    );

    final header = find.byType(WorkspaceContextHeader);
    final title = find.byKey(const Key('workspace-title-repair-fleet'));
    final segmented = find.byKey(const Key('repair-mode-segmented'));
    expect(title, findsOneWidget);
    expect(segmented, findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(tester.getSize(segmented).height, lessThanOrEqualTo(38));
    expect(
      tester.getRect(title).right,
      lessThan(tester.getRect(segmented).left),
    );
    expect(
      tester.getRect(header).right - tester.getRect(segmented).right,
      inInclusiveRange(0, 16),
    );

    final selectedMaterial = find.descendant(
      of: find.byKey(const Key('repair-mode-dock')),
      matching: find.byType(Material),
    );
    expect(selectedMaterial, findsOneWidget);
    final material = tester.widget<Material>(selectedMaterial);
    final roundedShape = material.shape is RoundedRectangleBorder
        ? material.shape! as RoundedRectangleBorder
        : null;
    final borderRadius = material.borderRadius ?? roundedShape?.borderRadius;
    expect(borderRadius, isNotNull);
    expect(borderRadius!.resolve(TextDirection.ltr).topLeft.x, greaterThan(0));
  });

  testWidgets('uses full fleet names and status dots in the fleet switcher', (
    tester,
  ) async {
    await _setSurfaceSize(tester, const Size(1180, 720));
    final controller = await _controller();
    addTearDown(controller.dispose);

    await tester.pumpWidget(_app(controller, const Size(1180, 720)));
    await tester.tap(find.byKey(const Key('repair-mode-anchorage')));
    await tester.pump();

    final switcher = find.byType(FleetSwitcherBar);
    expect(switcher, findsOneWidget);
    expect(
      find.descendant(
        of: switcher,
        matching: find.byKey(const Key('workspace-title-fleet')),
      ),
      findsNothing,
    );
    for (final id in <int>[1, 2]) {
      expect(find.byKey(Key('fleet-button-$id')), findsOneWidget);
      expect(find.byKey(Key('fleet-selector-status-dot-$id')), findsOneWidget);
    }
    expect(find.text('第一舰队'), findsOneWidget);
    expect(find.text('第二水雷战队'), findsOneWidget);
    expect(_anchorageRepairRows(), findsNWidgets(5));

    await tester.tap(find.byKey(const Key('fleet-button-2')));
    await tester.pump();
    expect(_anchorageRepairRows(), findsNothing);
  });

  testWidgets('falls back when the selected anchorage fleet disappears', (
    tester,
  ) async {
    await _setSurfaceSize(tester, const Size(1180, 720));
    final initialState = _testState();
    final reducer = _MutableReducer(initialState);
    final controller = GameStateController(reducer: reducer);
    addTearDown(controller.dispose);
    controller.accept(_stateRefreshEvent('/initial'));
    await controller.idle;

    await tester.pumpWidget(_app(controller, const Size(1180, 720)));
    await tester.tap(find.byKey(const Key('repair-mode-anchorage')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('fleet-button-2')));
    await tester.pump();
    expect(_anchorageRepairRows(), findsNothing);

    reducer.nextState = initialState.copyWith(
      fleets: <Fleet>[initialState.fleets.first],
    );
    controller.accept(_stateRefreshEvent('/fleet-refresh'));
    await controller.idle;
    await tester.pump();

    expect(_anchorageRepairRows(), findsNWidgets(5));
  });

  testWidgets('applies, updates, and clears the requested anchorage fleet', (
    tester,
  ) async {
    await _setSurfaceSize(tester, const Size(1180, 720));
    final controller = await _controller();
    addTearDown(controller.dispose);

    Widget app(int? fleetId) => MaterialApp(
      home: Scaffold(
        body: RepairCenterView(
          controller: controller,
          mode: RepairCenterMode.anchorage,
          initialFleetId: fleetId,
        ),
      ),
    );

    await tester.pumpWidget(app(2));
    expect(_anchorageRepairRows(), findsNothing);

    await tester.pumpWidget(app(null));
    await tester.pump();
    expect(_anchorageRepairRows(), findsNWidgets(5));
  });

  testWidgets('renders keyed ShipPortrait widgets with the correct source', (
    tester,
  ) async {
    await _setSurfaceSize(tester, const Size(1180, 720));
    final controller = await _controller();
    addTearDown(controller.dispose);

    await tester.pumpWidget(_app(controller, const Size(1180, 720)));
    await tester.tap(find.byKey(const Key('repair-mode-anchorage')));
    await tester.pump();

    _expectAnchoragePortraits(tester);
  });

  testWidgets('renders the same keyed portraits in the narrow repair table', (
    tester,
  ) async {
    await _setSurfaceSize(tester, const Size(740, 360));
    final controller = await _controller();
    addTearDown(controller.dispose);

    await tester.pumpWidget(_app(controller, const Size(740, 360)));
    await tester.tap(find.byKey(const Key('repair-mode-anchorage')));
    await tester.pump();

    expect(find.byKey(const Key('anchorage-repair-table')), findsOneWidget);
    expect(find.byKey(const Key('anchorage-compact-list')), findsNothing);
    _expectAnchoragePortraits(tester);
  });

  testWidgets('uses text-only compact status and one-line capacity summaries', (
    tester,
  ) async {
    await _setSurfaceSize(tester, const Size(1180, 720));
    final controller = await _controller();
    addTearDown(controller.dispose);

    await tester.pumpWidget(_app(controller, const Size(1180, 720)));
    await tester.tap(find.byKey(const Key('repair-mode-anchorage')));
    await tester.pump();

    final status = find.byKey(const Key('anchorage-summary-status'));
    expect(
      find.descendant(of: status, matching: find.byType(ShipPortrait)),
      findsNothing,
    );
    expect(
      find.byKey(const Key('anchorage-summary-flagship-portrait')),
      findsNothing,
    );
    expect(find.text('5 艘（修理设施 X 3）'), findsOneWidget);
    expect(find.text('4 艘'), findsNothing);
    expect(find.text('已装备修理设施 X 3'), findsNothing);
    expect(find.textContaining('已装备修理设施'), findsNothing);
  });

  for (final surface in const <Size>[Size(1180, 720), Size(740, 360)]) {
    testWidgets(
      'matches all summary capsule heights to fleet buttons at ${surface.width.toInt()} wide',
      (tester) async {
        await _setSurfaceSize(tester, surface);
        final controller = await _controller();
        addTearDown(controller.dispose);

        await tester.pumpWidget(_app(controller, surface));
        await tester.tap(find.byKey(const Key('repair-mode-anchorage')));
        await tester.pump();

        final fleetButtonHeight = tester
            .getSize(find.byKey(const Key('fleet-button-1')))
            .height;
        for (final key in const <Key>[
          Key('anchorage-summary-status'),
          Key('anchorage-summary-elapsed'),
          Key('anchorage-summary-capacity'),
        ]) {
          expect(tester.getSize(find.byKey(key)).height, fleetButtonHeight);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('shows current status and readiness on the same line', (
    tester,
  ) async {
    await _setSurfaceSize(tester, const Size(1180, 720));
    final controller = await _controller();
    addTearDown(controller.dispose);

    await tester.pumpWidget(_app(controller, const Size(1180, 720)));
    await tester.tap(find.byKey(const Key('repair-mode-anchorage')));
    await tester.pump();

    final status = find.byKey(const Key('anchorage-summary-status'));
    final label = find.descendant(of: status, matching: find.text('当前状态'));
    final value = find.descendant(of: status, matching: find.text('HP 修理准备就绪'));
    expect(label, findsOneWidget);
    expect(value, findsOneWidget);
    expect(
      tester.getRect(value).center.dy,
      closeTo(tester.getRect(label).center.dy, 1),
    );
    expect(tester.getRect(label).right, lessThan(tester.getRect(value).left));
  });

  testWidgets('keeps every summary label and value on one adaptive line', (
    tester,
  ) async {
    await _setSurfaceSize(tester, const Size(740, 360));
    final controller = await _controller();
    addTearDown(controller.dispose);

    await tester.pumpWidget(_app(controller, const Size(682, 360)));
    await tester.tap(find.byKey(const Key('repair-mode-anchorage')));
    await tester.pump();

    for (final key in const <Key>[
      Key('anchorage-summary-status'),
      Key('anchorage-summary-elapsed'),
      Key('anchorage-summary-capacity'),
    ]) {
      final card = find.byKey(key);
      final texts = find.descendant(of: card, matching: find.byType(Text));
      expect(texts, findsNWidgets(2));
      final textWidgets = tester.widgetList<Text>(texts);
      expect(textWidgets.every((text) => text.maxLines == 1), isTrue);
      expect(textWidgets.every((text) => text.softWrap == false), isTrue);
      expect(
        tester.getRect(texts.at(0)).center.dy,
        closeTo(tester.getRect(texts.at(1)).center.dy, 1),
      );
      expect(
        find.descendant(of: card, matching: find.byType(FittedBox)),
        findsOneWidget,
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps all three summary capsules on one row at 682 wide', (
    tester,
  ) async {
    await _setSurfaceSize(tester, const Size(740, 360));
    final controller = await _controller();
    addTearDown(controller.dispose);

    await tester.pumpWidget(_app(controller, const Size(682, 360)));
    await tester.tap(find.byKey(const Key('repair-mode-anchorage')));
    await tester.pump();

    final status = tester.getRect(
      find.byKey(const Key('anchorage-summary-status')),
    );
    final elapsed = tester.getRect(
      find.byKey(const Key('anchorage-summary-elapsed')),
    );
    final capacity = tester.getRect(
      find.byKey(const Key('anchorage-summary-capacity')),
    );
    expect(elapsed.top, inInclusiveRange(status.top - 1, status.top + 1));
    expect(capacity.top, inInclusiveRange(status.top - 1, status.top + 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows the confirmed anchorage summary and ship statuses', (
    tester,
  ) async {
    await _setSurfaceSize(tester, const Size(1180, 720));
    final controller = await _controller();
    addTearDown(controller.dispose);

    await tester.pumpWidget(_app(controller, const Size(1180, 720)));
    await tester.tap(find.byKey(const Key('repair-mode-anchorage')));
    await tester.pump();

    expect(find.text('泊地修理已计时'), findsOneWidget);
    expect(find.textContaining('第 1～4 舰队共用'), findsNothing);
    expect(find.text('HP 修理准备就绪'), findsOneWidget);
    expect(find.text('5 艘（修理设施 X 3）'), findsOneWidget);
    expect(find.text('修理已完成'), findsWidgets);
    expect(find.text('正在修理中'), findsNWidgets(2));
    expect(find.text('超出修理范围'), findsOneWidget);
    expect(find.text('♥'), findsWidgets);
    expect(find.byKey(const Key('anchorage-repair-row-2')), findsOneWidget);
    expect(find.byKey(const Key('anchorage-repair-table')), findsOneWidget);
  });

  for (final surface in const <Size>[
    Size(740, 360),
    Size(844, 390),
    Size(1180, 720),
  ]) {
    testWidgets(
      'uses one repair table without overflow at ${surface.width.toInt()} wide',
      (tester) async {
        await _setSurfaceSize(tester, surface);
        final controller = await _controller();
        addTearDown(controller.dispose);

        await tester.pumpWidget(_app(controller, surface));
        await tester.tap(find.byKey(const Key('repair-mode-anchorage')));
        await tester.pump();

        expect(find.byKey(const Key('anchorage-repair-table')), findsOneWidget);
        expect(find.byKey(const Key('anchorage-compact-list')), findsNothing);
        expect(_anchorageRepairRows(), findsNWidgets(5));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('keeps every wide repair table row below 64 pixels', (
    tester,
  ) async {
    await _setSurfaceSize(tester, const Size(1180, 720));
    final controller = await _controller();
    addTearDown(controller.dispose);

    await tester.pumpWidget(_app(controller, const Size(1180, 720)));
    await tester.tap(find.byKey(const Key('repair-mode-anchorage')));
    await tester.pump();

    for (var position = 1; position <= 5; position++) {
      final row = find.byKey(Key('anchorage-repair-row-$position'));
      expect(row, findsOneWidget);
      expect(tester.getSize(row).height, lessThan(64));
    }
  });

  testWidgets('fits the complete long ship name without ellipsis', (
    tester,
  ) async {
    await _setSurfaceSize(tester, const Size(1180, 720));
    final controller = await _controller();
    addTearDown(controller.dispose);

    await tester.pumpWidget(_app(controller, const Size(1180, 720)));
    await tester.tap(find.byKey(const Key('repair-mode-anchorage')));
    await tester.pump();

    final name = find.text(_longShipName);
    expect(name, findsOneWidget);
    expect(
      find.ancestor(of: name, matching: find.byType(FittedBox)),
      findsOneWidget,
    );
    expect(tester.widget<Text>(name).overflow, isNot(TextOverflow.ellipsis));
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            (widget.data?.startsWith(RegExp(r'\d+\. ')) ?? false),
      ),
      findsNothing,
    );
    expect(find.textContaining('修理旗舰'), findsNothing);
  });

  testWidgets('fleet information repair page uses the new repair center', (
    tester,
  ) async {
    final controller = await _controller();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FleetInformationCenter(
            controller: controller,
            page: FleetInformationPage.repair,
            showContextHeader: false,
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('repair-mode-dock')), findsOneWidget);
    expect(find.byKey(const Key('repair-mode-anchorage')), findsOneWidget);
  });

  testWidgets('workspace repair header owns the controlled mode tabs', (
    tester,
  ) async {
    final controller = await _controller();
    addTearDown(controller.dispose);
    var selected = RepairCenterMode.dock;
    final state = controller.state;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => Column(
              children: [
                WorkspaceContextHeader(
                  workspaceIndex: 3,
                  state: state,
                  selectedFleetId: 1,
                  repairMode: selected,
                  onRepairModeChanged: (mode) =>
                      setState(() => selected = mode),
                ),
                Expanded(
                  child: FleetInformationCenter(
                    controller: controller,
                    page: FleetInformationPage.repair,
                    showContextHeader: false,
                    repairMode: selected,
                    showRepairModeTabs: false,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('repair-mode-dock')), findsOneWidget);
    await tester.tap(find.byKey(const Key('repair-mode-anchorage')));
    await tester.pump();
    expect(find.text('泊地修理已计时'), findsOneWidget);
    expect(find.byKey(const Key('repair-mode-dock')), findsOneWidget);
  });
}

Finder _anchorageRepairRows() => find.byWidgetPredicate((widget) {
  final key = widget.key;
  return key is ValueKey<String> &&
      key.value.startsWith('anchorage-repair-row-');
});

void _expectAnchoragePortraits(WidgetTester tester) {
  const serverOrigin = 'https://example.test';
  const expectedMasterIds = <int, int>{1: 182, 2: 502, 3: 503, 4: 504, 5: 505};

  for (final entry in expectedMasterIds.entries) {
    final portrait = find.byKey(Key('anchorage-repair-portrait-${entry.key}'));
    expect(portrait, findsOneWidget);
    final widget = tester.widget<ShipPortrait>(portrait);
    expect(widget.ship?.id, entry.value);
    expect(widget.serverOrigin, serverOrigin);
    expect(widget.width, 68);
    expect(widget.height, 34);
  }
}

Widget _app(GameStateController controller, Size size) => MaterialApp(
  home: Scaffold(
    body: Center(
      child: SizedBox(
        width: size.width,
        height: size.height,
        child: RepairCenterView(controller: controller),
      ),
    ),
  ),
);

Future<void> _setSurfaceSize(WidgetTester tester, Size size) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

Future<GameStateController> _controller() async {
  final testState = _testState();
  final controller = GameStateController(reducer: _StaticReducer(testState));
  controller.accept(_stateRefreshEvent('/initial'));
  await controller.idle;
  return controller;
}

GameState _testState() {
  final baseState = buildAnchorageTestState(facilities: 3);
  return baseState.copyWith(
    serverOrigin: 'https://example.test',
    masterShips: <int, MasterShip>{
      for (final entry in baseState.masterShips.entries)
        if (entry.key != 502)
          entry.key: entry.value.copyWith(portraitVersion: '1'),
      502: const MasterShip(
        id: 502,
        name: _longShipName,
        shipTypeId: 2,
        portraitVersion: '1',
      ),
    },
    fleets: <Fleet>[
      ...baseState.fleets,
      const Fleet(id: 2, name: '第二水雷战队'),
    ],
  );
}

CapturedApiEvent _stateRefreshEvent(String path) => CapturedApiEvent(
  path: path,
  responseBody: '{"api_result":1,"api_data":{}}',
  source: CaptureSource.manual,
  capturedAt: DateTime.now().toUtc(),
);

class _StaticReducer extends GameStateReducer {
  _StaticReducer(this.nextState);

  final GameState nextState;

  @override
  GameState reduce(GameState state, CapturedApiEvent event) => nextState;
}

class _MutableReducer extends GameStateReducer {
  _MutableReducer(this.nextState);

  GameState nextState;

  @override
  GameState reduce(GameState state, CapturedApiEvent event) => nextState;
}
