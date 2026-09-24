import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/account/account_session.dart';
import 'package:yahagi_kancolle_browser/src/expedition/expedition_check_page.dart';
import 'package:yahagi_kancolle_browser/src/expedition/expedition_selection_store.dart';
import 'package:yahagi_kancolle_browser/src/expedition/expedition_completion_estimate.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_controller.dart';

import 'fixtures/kcsapi_fixtures.dart';

void main() {
  setUp(() => AccountSession.shared.selectMember(1001));
  testWidgets('远征检查详情按舰队恢复上次选择的 A6', (tester) async {
    final controller = GameStateController();
    final store = _MemoryExpeditionSelectionStore(<int, int>{2: 105});
    addTearDown(controller.dispose);
    controller
      ..accept(start2Event)
      ..accept(portEvent)
      ..accept(slotItemEvent);
    await controller.idle;

    await tester.pumpWidget(
      MaterialApp(
        home: ExpeditionCheckPage(
          controller: controller,
          onBack: () {},
          selectionStore: store,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<Text>(find.byKey(const Key('expedition-mission-label')))
          .data,
      startsWith('A6'),
    );

    await tester.tap(find.byKey(const Key('expedition-mission-picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('expedition-mission-option-3')));
    await tester.pumpAndSettle();
    expect(store.values[2], 3);
  });

  testWidgets('详情页无大发开关并在条件末尾始终显示提醒', (tester) async {
    final controller = GameStateController();
    addTearDown(controller.dispose);
    controller
      ..accept(start2Event)
      ..accept(portEvent)
      ..accept(slotItemEvent);
    await controller.idle;

    await tester.pumpWidget(
      MaterialApp(
        home: ExpeditionCheckPage(controller: controller, onBack: () {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('expedition-daihatsu-optimization-switch')),
      findsNothing,
    );
    expect(find.text('尽量装满大发'), findsNothing);
    final daihatsuReminder = find.text('尽可能多的大发动艇或特大发动艇');
    expect(daihatsuReminder, findsOneWidget);
    expect(find.textContaining('收益优化'), findsNothing);
    expect(
      tester.getTopLeft(daihatsuReminder).dy,
      greaterThan(tester.getTopLeft(find.text('舰队完成补给')).dy),
    );
  });

  testWidgets('远征检查详情默认选择远征 1', (tester) async {
    final controller = GameStateController();
    addTearDown(controller.dispose);
    controller
      ..accept(start2Event)
      ..accept(portEvent)
      ..accept(slotItemEvent);
    await controller.idle;

    await tester.pumpWidget(
      MaterialApp(
        home: ExpeditionCheckPage(controller: controller, onBack: () {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('expedition-mission-picker')), findsOneWidget);
    expect(find.textContaining('1 ·'), findsOneWidget);
  });

  testWidgets('远征检查在所需时间下显示当前远征的本地完成时刻', (tester) async {
    final completion = DateTime.now().add(const Duration(hours: 1));
    final port =
        (jsonDecode(portEvent.responseBody) as Map)['api_data']
            as Map<String, dynamic>;
    final fleets = port['api_deck_port'] as List;
    (fleets[1]['api_mission'] as List)[2] = completion.millisecondsSinceEpoch;
    final controller = GameStateController();
    addTearDown(controller.dispose);
    controller
      ..accept(start2Event)
      ..accept(kcsapiEvent('/kcsapi/api_port/port', port));
    await controller.idle;

    await tester.pumpWidget(
      MaterialApp(
        home: ExpeditionCheckPage(
          controller: controller,
          onBack: () {},
          selectionStore: _MemoryExpeditionSelectionStore(<int, int>{2: 5}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final estimate = find.byKey(const Key('expedition-estimated-completion'));
    expect(estimate, findsOneWidget);
    expect(
      tester.getTopLeft(estimate).dy,
      greaterThan(tester.getBottomLeft(find.text('所需时间')).dy),
    );
    expect(
      find.descendant(of: estimate, matching: find.text('预计完成时间')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: estimate,
        matching: find.text(
          formatExpeditionCompletionTime(completion, now: DateTime.now()),
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: estimate, matching: find.text('远征进行中')),
      findsNothing,
    );
  });

  testWidgets('空闲舰队预计完成时间下不显示起算说明', (tester) async {
    final port =
        (jsonDecode(portEvent.responseBody) as Map)['api_data']
            as Map<String, dynamic>;
    final fleets = port['api_deck_port'] as List;
    fleets[1]['api_mission'] = <int>[0, 0, 0, 0];
    final controller = GameStateController();
    addTearDown(controller.dispose);
    controller
      ..accept(start2Event)
      ..accept(kcsapiEvent('/kcsapi/api_port/port', port));
    await controller.idle;

    await tester.pumpWidget(
      MaterialApp(
        home: ExpeditionCheckPage(
          controller: controller,
          onBack: () {},
          selectionStore: _MemoryExpeditionSelectionStore(<int, int>{2: 5}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final estimate = find.byKey(const Key('expedition-estimated-completion'));
    expect(estimate, findsOneWidget);
    expect(
      find.descendant(of: estimate, matching: find.text('若现在出发')),
      findsNothing,
    );
    expect(
      find.descendant(of: estimate, matching: find.text('--')),
      findsNothing,
    );
  });

  testWidgets('检查其他远征时当前时间估算在日文手机宽度不溢出', (tester) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final port =
        (jsonDecode(portEvent.responseBody) as Map)['api_data']
            as Map<String, dynamic>;
    final fleets = port['api_deck_port'] as List;
    (fleets[1]['api_mission'] as List)[2] = DateTime.now()
        .add(const Duration(hours: 1))
        .millisecondsSinceEpoch;
    final controller = GameStateController();
    addTearDown(controller.dispose);
    controller
      ..accept(start2Event)
      ..accept(kcsapiEvent('/kcsapi/api_port/port', port));
    await controller.idle;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ja'),
        supportedLocales: const [Locale('ja')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: ExpeditionCheckPage(
          controller: controller,
          onBack: () {},
          selectionStore: _MemoryExpeditionSelectionStore(<int, int>{2: 21}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final estimate = find.byKey(const Key('expedition-estimated-completion'));
    expect(estimate, findsOneWidget);
    expect(
      find.descendant(of: estimate, matching: find.text('現在時刻から計算')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('详情页在窄屏显示耗时、消耗、收入与条件', (tester) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = GameStateController();
    addTearDown(controller.dispose);
    controller
      ..accept(start2Event)
      ..accept(portEvent)
      ..accept(slotItemEvent);
    await controller.idle;

    await tester.pumpWidget(
      MaterialApp(
        home: ExpeditionCheckPage(controller: controller, onBack: () {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('远征检查'), findsOneWidget);
    expect(find.text('远征时间与消耗'), findsOneWidget);
    expect(find.text('预计收入'), findsOneWidget);
    expect(find.text('远征条件'), findsOneWidget);

    await tester.tap(find.text('大成功'));
    await tester.pumpAndSettle();
    expect(find.text('100%'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('大成功模式在宽屏完整单行显示且不使用横向滚动', (tester) async {
    tester.view.physicalSize = const Size(1100, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = GameStateController();
    addTearDown(controller.dispose);
    controller
      ..accept(start2Event)
      ..accept(portEvent)
      ..accept(slotItemEvent);
    await controller.idle;

    await tester.pumpWidget(
      MaterialApp(
        home: ExpeditionCheckPage(
          controller: controller,
          onBack: () {},
          showHeader: false,
        ),
      ),
    );
    await tester.tap(find.text('大成功'));
    await tester.pumpAndSettle();
    expect(find.textContaining('大成功: 未通过 ('), findsNothing);
    expect(find.text('大成功: 未通过'), findsOneWidget);

    final controls = find.byKey(const Key('expedition-header-controls'));
    final results = find.byKey(const Key('expedition-header-results'));
    expect(controls, findsOneWidget);
    expect(results, findsOneWidget);
    expect(
      (tester.getCenter(controls).dy - tester.getCenter(results).dy).abs(),
      lessThan(2),
    );
    expect(
      tester
          .widgetList<SingleChildScrollView>(find.byType(SingleChildScrollView))
          .where((scroll) => scroll.scrollDirection == Axis.horizontal),
      isEmpty,
    );
    expect(
      tester
          .widget<Text>(find.byKey(const Key('expedition-mission-label')))
          .overflow,
      isNot(TextOverflow.ellipsis),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('大成功模式在窄屏仅将两个检查结果换到第二行', (tester) async {
    tester.view.physicalSize = const Size(700, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = GameStateController();
    addTearDown(controller.dispose);
    controller
      ..accept(start2Event)
      ..accept(portEvent)
      ..accept(slotItemEvent);
    await controller.idle;

    await tester.pumpWidget(
      MaterialApp(
        home: ExpeditionCheckPage(
          controller: controller,
          onBack: () {},
          showHeader: false,
        ),
      ),
    );
    await tester.tap(find.text('大成功'));
    await tester.pumpAndSettle();

    final controls = find.byKey(const Key('expedition-header-controls'));
    final results = find.byKey(const Key('expedition-header-results'));
    expect(controls, findsOneWidget);
    expect(results, findsOneWidget);
    expect(
      tester.getTopLeft(results).dy,
      greaterThan(tester.getBottomLeft(controls).dy),
    );
    expect(
      find.descendant(of: results, matching: find.byType(Text)),
      findsNWidgets(2),
    );
    expect(
      tester
          .widgetList<SingleChildScrollView>(find.byType(SingleChildScrollView))
          .where((scroll) => scroll.scrollDirection == Axis.horizontal),
      isEmpty,
    );
    expect(tester.takeException(), isNull);
  });
}

final class _MemoryExpeditionSelectionStore
    implements ExpeditionSelectionStore {
  _MemoryExpeditionSelectionStore(this.values);

  final Map<int, int> values;

  @override
  Future<int?> loadMissionId(int fleetId) async => values[fleetId];

  @override
  Future<void> saveMissionId(int fleetId, int missionId) async {
    values[fleetId] = missionId;
  }
}
