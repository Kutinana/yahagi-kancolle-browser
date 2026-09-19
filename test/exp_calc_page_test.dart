import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/exp_calc/exp_calc_models.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/exp_calc/exp_calc_page.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/exp_calc/exp_tracker_store.dart';
import 'package:yahagi_kancolle_browser/src/widgets/top_notice.dart';

Widget _testableApp(Widget child) => MaterialApp(
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('zh'),
  home: TopNoticeHost(child: Scaffold(body: child)),
);

class FakeExpTrackerStore implements ExpTrackerStore {
  List<ExpCalcTrackItem> items = [];

  @override
  Future<List<ExpCalcTrackItem>> loadTrackItems() async => List.of(items);

  @override
  Future<void> saveTrackItems(List<ExpCalcTrackItem> newItems) async {
    items = List.of(newItems);
  }
}

void main() {
  testWidgets(
    'renders ExpCalcPage with initial empty state and default fields',
    (tester) async {
      final store = FakeExpTrackerStore();
      const state = GameState(memberId: 1);

      await tester.pumpWidget(
        _testableApp(ExpCalcPage(state: state, store: store)),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('exp-calc-wide-workspace')), findsOneWidget);
      expect(find.byKey(const Key('exp-calc-compact-workspace')), findsNothing);
      expect(find.byKey(const Key('exp-calc-ship-selector')), findsOneWidget);
      expect(find.byKey(const Key('exp-calc-current-level')), findsOneWidget);
      expect(find.byKey(const Key('exp-calc-target-level')), findsOneWidget);
      expect(
        find.byKey(const Key('exp-calc-target-level-decrease')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('exp-calc-target-level-increase')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('exp-calc-map-selector')), findsOneWidget);
      expect(find.byKey(const Key('exp-calc-base-exp-input')), findsOneWidget);
      expect(
        find.byKey(const Key('exp-calc-flagship-checkbox')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('exp-calc-mvp-checkbox')), findsOneWidget);
      expect(find.byKey(const Key('exp-calc-add-node-button')), findsOneWidget);
      expect(find.byKey(const Key('exp-calc-add-button')), findsOneWidget);

      expect(find.text('暂无练级追踪计划，点击上方 ＋ 添加'), findsOneWidget);
    },
  );

  testWidgets(
    'selects ship and auto-populates levels, exp, and next remodel target',
    (tester) async {
      final store = FakeExpTrackerStore();
      final state = GameState(
        memberId: 1,
        masterShips: {
          546: const MasterShip(
            id: 546,
            name: '武藏改二',
            shipTypeId: 9,
            afterShipId: 0,
            afterLv: 0,
          ),
          100: const MasterShip(
            id: 100,
            name: '某练习巡洋舰',
            shipTypeId: 4,
            afterShipId: 200,
            afterLv: 35,
          ),
        },
        ships: {
          1: const OwnedShip(
            id: 1,
            masterId: 546,
            level: 186,
            experience: 17635281,
          ),
          2: const OwnedShip(id: 2, masterId: 100, level: 10, experience: 4500),
        },
      );

      await tester.pumpWidget(
        _testableApp(ExpCalcPage(state: state, store: store)),
      );
      await tester.pumpAndSettle();

      // The highest-level ship (武藏改二 Lv.186) should be automatically selected
      expect(find.textContaining('武藏改二'), findsWidgets);
      expect(find.text('17635281 EXP'), findsOneWidget);
      expect(
        find.text('18600000 EXP'),
        findsOneWidget,
      ); // Target level 187 base exp

      // Base exp 150, S rank, Flagship true, MVP true -> Map exp 540, Battles 1787
      expect(find.text('540'), findsOneWidget);
      expect(find.text('964719'), findsOneWidget);
      expect(find.text('1787'), findsOneWidget);

      // Test Stepper button increase target level
      await tester.tap(find.byKey(const Key('exp-calc-target-level-increase')));
      await tester.pumpAndSettle();
      expect(find.text('20200000 EXP'), findsOneWidget); // Target level 188
    },
  );

  testWidgets(
    'supports multi-node route addition, deletion, and combined experience calculation',
    (tester) async {
      final store = FakeExpTrackerStore();
      final state = GameState(
        memberId: 1,
        masterShips: {
          546: const MasterShip(id: 546, name: '武藏改二', shipTypeId: 9),
        },
        ships: {
          1: const OwnedShip(
            id: 1,
            masterId: 546,
            level: 186,
            experience: 17635281,
          ),
        },
      );

      await tester.pumpWidget(
        _testableApp(ExpCalcPage(state: state, store: store)),
      );
      await tester.pumpAndSettle();

      // Initially 1 node (5-2 C point 150 exp -> 540)
      expect(find.textContaining('1 个战斗点位'), findsOneWidget);
      expect(find.textContaining('540 EXP'), findsWidgets);

      // Tap "增加战斗点位"
      await tester.ensureVisible(
        find.byKey(const Key('exp-calc-add-node-button')),
      );
      await tester.tap(find.byKey(const Key('exp-calc-add-node-button')));
      await tester.pumpAndSettle();

      // Now 2 nodes!
      expect(find.textContaining('2 个战斗点位'), findsOneWidget);
      expect(find.byKey(const Key('exp-calc-remove-node-1')), findsOneWidget);

      // Tap remove on node 2
      await tester.ensureVisible(
        find.byKey(const Key('exp-calc-remove-node-1')),
      );
      await tester.tap(find.byKey(const Key('exp-calc-remove-node-1')));
      await tester.pumpAndSettle();

      // Reverted back to 1 node
      expect(find.textContaining('1 个战斗点位'), findsOneWidget);
    },
  );

  testWidgets(
    'adds track item with route summary, dynamically updates upon level-up, and deletes',
    (tester) async {
      final store = FakeExpTrackerStore();
      final state = GameState(
        memberId: 1,
        masterShips: {
          546: const MasterShip(id: 546, name: '武藏改二', shipTypeId: 9),
        },
        ships: {
          1: const OwnedShip(
            id: 1,
            masterId: 546,
            level: 186,
            experience: 17635281,
          ),
        },
      );

      tester.view.physicalSize = const Size(1280, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _testableApp(ExpCalcPage(state: state, store: store)),
      );
      await tester.pumpAndSettle();

      // Click add button
      await tester.ensureVisible(find.byKey(const Key('exp-calc-add-button')));
      await tester.tap(find.byKey(const Key('exp-calc-add-button')));
      await tester.pumpAndSettle();

      expect(store.items.length, 1);
      expect(find.byKey(const Key('exp-calc-track-list')), findsOneWidget);
      expect(find.text('1787 次'), findsOneWidget);

      // Simulate ship leveling up in port
      final updatedState = GameState(
        memberId: 1,
        masterShips: {
          546: const MasterShip(id: 546, name: '武藏改二', shipTypeId: 9),
        },
        ships: {
          1: const OwnedShip(
            id: 1,
            masterId: 546,
            level: 187,
            experience: 18600000,
          ),
        },
      );

      await tester.pumpWidget(
        _testableApp(ExpCalcPage(state: updatedState, store: store)),
      );
      await tester.pumpAndSettle();

      // Battles remaining should now be 0 (completed) in the table!
      expect(find.text('0 次 (已达成)'), findsOneWidget);

      // Delete track item
      final deleteButtonKey = Key(
        'exp-calc-delete-button-${store.items.first.id}',
      );
      await tester.ensureVisible(find.byKey(deleteButtonKey));
      await tester.tap(find.byKey(deleteButtonKey));
      await tester.pumpAndSettle();

      expect(store.items, isEmpty);
      expect(find.text('暂无练级追踪计划，点击上方 ＋ 添加'), findsOneWidget);
    },
  );

  testWidgets(
    'renders cleanly without overflow in narrow mode (360px width) and toggles view modes',
    (tester) async {
      final store = FakeExpTrackerStore();
      final state = GameState(
        memberId: 1,
        masterShips: {
          546: const MasterShip(id: 546, name: '武藏改二', shipTypeId: 9),
        },
        ships: {
          1: const OwnedShip(
            id: 1,
            masterId: 546,
            level: 186,
            experience: 17635281,
          ),
        },
      );

      // Set narrow smartphone / HD portrait sidebar dimensions
      tester.view.physicalSize = const Size(360, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _testableApp(ExpCalcPage(state: state, store: store)),
      );
      await tester.pumpAndSettle();

      // Verify key elements render without exception or overflow
      expect(find.byKey(const Key('exp-calc-wide-workspace')), findsNothing);
      expect(
        find.byKey(const Key('exp-calc-compact-workspace')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('exp-calc-ship-selector')), findsOneWidget);
      expect(find.byKey(const Key('exp-calc-current-level')), findsOneWidget);
      expect(find.byKey(const Key('exp-calc-target-level')), findsOneWidget);
      expect(find.text('540'), findsOneWidget);
      expect(find.text('964719'), findsOneWidget);

      // Add track item
      await tester.ensureVisible(find.byKey(const Key('exp-calc-add-button')));
      await tester.tap(find.byKey(const Key('exp-calc-add-button')));
      await tester.pumpAndSettle();

      // On narrow screen, compact card view is active by default
      expect(find.byKey(const Key('exp-calc-track-list')), findsOneWidget);
      expect(find.text('1787 次'), findsOneWidget);

      // Toggle to Table View
      await tester.ensureVisible(find.byKey(const Key('exp-calc-view-table')));
      await tester.tap(find.byKey(const Key('exp-calc-view-table')));
      await tester.pumpAndSettle();
      expect(find.byType(DataTable), findsOneWidget);

      // Toggle back to Card View
      await tester.tap(find.byKey(const Key('exp-calc-view-card')));
      await tester.pumpAndSettle();
      expect(find.byType(DataTable), findsNothing);
    },
  );
}
