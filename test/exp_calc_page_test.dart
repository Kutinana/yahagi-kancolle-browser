import 'dart:async';
import 'dart:io';
import 'package:yahagi_kancolle_browser/src/toolbox/sortie_map_query/sortie_map_catalog_controller.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/sortie_map_query/sortie_map_catalog_store.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/sortie_map_query/sortie_map_catalog_update_service.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/sortie_map_query/sortie_map_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/account/account_session.dart';
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
  Future<List<ExpCalcTrackItem>> loadTrackItems(int memberId) async =>
      List.of(items);

  @override
  Future<bool> saveTrackItems(
    int memberId,
    List<ExpCalcTrackItem> newItems,
  ) async {
    items = List.of(newItems);
    return true;
  }
}

class _DelayedExpTrackerStore implements ExpTrackerStore {
  final loads = <Completer<List<ExpCalcTrackItem>>>[];
  @override
  Future<List<ExpCalcTrackItem>> loadTrackItems(int memberId) {
    final pending = Completer<List<ExpCalcTrackItem>>();
    loads.add(pending);
    return pending.future;
  }

  @override
  Future<bool> saveTrackItems(
    int memberId,
    List<ExpCalcTrackItem> items,
  ) async => true;
}

class _FailingLoadExpTrackerStore implements ExpTrackerStore {
  int loads = 0;
  final items = <ExpCalcTrackItem>[_accountItem('existing plan')];

  @override
  Future<List<ExpCalcTrackItem>> loadTrackItems(int memberId) async {
    if (loads++ == 0) throw StateError('temporary read failure');
    return List.of(items);
  }

  @override
  Future<bool> saveTrackItems(
    int memberId,
    List<ExpCalcTrackItem> items,
  ) async {
    this.items
      ..clear()
      ..addAll(items);
    return true;
  }
}

class _FailingSaveExpTrackerStore extends FakeExpTrackerStore {
  @override
  Future<bool> saveTrackItems(
    int memberId,
    List<ExpCalcTrackItem> newItems,
  ) async {
    throw StateError('disk unavailable');
  }
}

ExpCalcTrackItem _accountItem(String name) => ExpCalcTrackItem(
  id: name,
  shipInstanceId: 1,
  shipMasterId: 1,
  shipName: name,
  targetLevel: 25,
  targetExp: 10000,
  map: '5-2',
  rank: BattleRank.s,
  isFlagship: true,
  isMvp: true,
  baseExp: 150,
  mapExp: 540,
  recordedLevel: 20,
  recordedExp: 5000,
);

final _assetCatalog = SortieMapCatalogData.fromJsonString(
  File('assets/data/sortie_map_catalog.json').readAsStringSync(),
);
Future<SortieMapCatalogData> _loadCatalog() async => _assetCatalog;

void main() {
  testWidgets('failed tracking save does not claim success or alter list', (
    tester,
  ) async {
    final store = _FailingSaveExpTrackerStore();
    await tester.pumpWidget(
      _testableApp(
        ExpCalcPage(
          state: const GameState(memberId: 1),
          store: store,
          catalogLoader: _loadCatalog,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('exp-calc-add-button')));
    await tester.tap(find.byKey(const Key('exp-calc-add-button')));
    await tester.pump();
    expect(store.items, isEmpty);
    expect(find.text('追踪列表保存失败，请重试'), findsOneWidget);
  });
  testWidgets('failed tracking load blocks writes until retry succeeds', (
    tester,
  ) async {
    final store = _FailingLoadExpTrackerStore();
    await tester.pumpWidget(
      _testableApp(
        ExpCalcPage(
          state: const GameState(memberId: 1),
          store: store,
          catalogLoader: _loadCatalog,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('exp-calc-track-retry')), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('exp-calc-add-button')))
          .onPressed,
      isNull,
    );
    expect(store.items.single.shipName, 'existing plan');

    await tester.tap(find.byKey(const Key('exp-calc-track-retry')));
    await tester.pumpAndSettle();
    expect(find.text('existing plan'), findsWidgets);
    expect(find.byKey(const Key('exp-calc-track-retry')), findsNothing);
  });
  testWidgets('switching accounts immediately clears ship and tracking data', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final session = AccountSession(initialMemberId: 1);
    final store = SharedPreferencesExpTrackerStore(accountSession: session);
    await store.saveTrackItems(1, [_accountItem('A tracking')]);
    GameState account(int memberId, String name, int level) => GameState(
      memberId: memberId,
      masterShips: {1: MasterShip(id: 1, name: name, shipTypeId: 2)},
      ships: {1: OwnedShip(id: 1, masterId: 1, level: level)},
    );
    Widget page(GameState state) => _testableApp(
      ExpCalcPage(state: state, store: store, catalogLoader: _loadCatalog),
    );

    await tester.pumpWidget(page(account(1, 'A ship', 20)));
    await tester.pumpAndSettle();
    expect(find.text('A tracking'), findsWidgets);
    session.selectMember(2);
    await tester.pumpWidget(page(account(2, 'B ship', 30)));
    await tester.pump();
    expect(find.text('A tracking'), findsNothing);
    expect(find.text('A ship · Lv.20'), findsNothing);
    expect(find.text('B ship · Lv.30'), findsOneWidget);
  });

  testWidgets('late account A load cannot replace account B plans', (
    tester,
  ) async {
    final store = _DelayedExpTrackerStore();
    Widget page(int memberId) => _testableApp(
      ExpCalcPage(
        state: GameState(memberId: memberId),
        store: store,
        catalogLoader: _loadCatalog,
      ),
    );
    await tester.pumpWidget(page(1));
    await tester.pumpWidget(page(2));
    expect(store.loads, hasLength(2));
    store.loads[1].complete([_accountItem('B tracking')]);
    await tester.pump();
    expect(find.text('B tracking'), findsWidgets);
    store.loads[0].complete([_accountItem('A tracking')]);
    await tester.pump();
    expect(find.text('B tracking'), findsWidgets);
    expect(find.text('A tracking'), findsNothing);
  });

  testWidgets('narrow landscape keeps five-digit point earnings on one line', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(760, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      _testableApp(
        ExpCalcPage(
          state: const GameState(),
          store: FakeExpTrackerStore(),
          catalogLoader: _loadCatalog,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('exp-calc-add-node-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('exp-calc-add-point-C')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('exp-calc-base-exp-input')),
      '9999',
    );
    await tester.pumpAndSettle();
    final yieldFinder = find.byKey(const Key('exp-calc-point-yield-0'));
    expect(
      tester.widget<Text>(yieldFinder).data,
      matches(RegExp(r'^\d{5} EXP$')),
    );
    expect(tester.getSize(yieldFinder).height, lessThan(24));
    expect(
      tester.getSize(find.byKey(const Key('exp-calc-base-exp-input'))).height,
      44,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'landscape panels share one row and point inputs have equal height',
    (tester) async {
      tester.view.physicalSize = const Size(1120, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        _testableApp(
          ExpCalcPage(
            state: const GameState(),
            store: FakeExpTrackerStore(),
            catalogLoader: _loadCatalog,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final target = tester.getTopLeft(find.text('舰娘与目标'));
      final route = tester.getTopLeft(find.text('出击路线'));
      final result = tester.getTopLeft(find.text('计算结果'));
      expect(route.dy, target.dy);
      expect(result.dy, target.dy);
      expect(target.dx, lessThan(route.dx));
      expect(route.dx, lessThan(result.dx));
      double checkPanelHeight() {
        final bounds = ['舰娘与目标', '出击路线', '计算结果']
            .map(
              (title) =>
                  tester.getRect(find.byKey(ValueKey('exp-calc-panel-$title'))),
            )
            .toList();
        expect(bounds[0].bottom, bounds[1].bottom);
        expect(bounds[2].bottom, bounds[1].bottom);
        return bounds[1].height;
      }

      final initialHeight = checkPanelHeight();
      await tester.tap(find.byKey(const Key('exp-calc-details-0')));
      await tester.pumpAndSettle();
      expect(checkPanelHeight(), greaterThan(initialHeight));
      await tester.tap(find.byKey(const Key('exp-calc-details-0')));
      await tester.pumpAndSettle();
      expect(checkPanelHeight(), initialHeight);
      expect(
        tester
            .getSize(find.byKey(const Key('exp-calc-point-capsule-0')))
            .height,
        tester.getSize(find.byKey(const Key('exp-calc-base-exp-input'))).height,
      );
    },
  );
  testWidgets(
    'route uses one sea selector and shared bonuses for every added point',
    (tester) async {
      final store = FakeExpTrackerStore();
      await tester.pumpWidget(
        _testableApp(
          ExpCalcPage(
            state: const GameState(),
            store: store,
            catalogLoader: _loadCatalog,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const Key('exp-calc-add-node-button')),
      );
      await tester.tap(find.byKey(const Key('exp-calc-add-node-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('exp-calc-add-point-C')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('exp-calc-map-selector-1')), findsNothing);
      expect(find.byKey(const Key('exp-calc-mvp-1')), findsNothing);
      expect(find.text('1080'), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const Key('exp-calc-mvp-checkbox')),
      );
      await tester.tap(find.byKey(const Key('exp-calc-mvp-checkbox')));
      await tester.pumpAndSettle();
      expect(find.text('540'), findsOneWidget);
      final first = tester.getRect(
        find.byKey(const Key('exp-calc-point-selector-0')),
      );
      final second = tester.getRect(
        find.byKey(const Key('exp-calc-point-selector-1')),
      );
      expect(second.top - first.top, lessThan(85));
      await tester.ensureVisible(find.byKey(const Key('exp-calc-details-1')));
      await tester.tap(find.byKey(const Key('exp-calc-details-1')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const Key('exp-calc-mvp-detail-1')),
      );
      await tester.tap(find.byKey(const Key('exp-calc-mvp-detail-1')));
      await tester.pumpAndSettle();
      expect(find.text('810'), findsOneWidget);
      tester
          .widget<DropdownButton<String>>(
            find.byKey(const Key('exp-calc-map-selector')),
          )
          .onChanged!('7-1');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('exp-calc-point-selector-1')), findsNothing);
    },
  );

  testWidgets(
    'changing sea area and point uses catalog averages instead of old presets',
    (tester) async {
      await tester.pumpWidget(
        _testableApp(
          ExpCalcPage(
            state: const GameState(),
            store: FakeExpTrackerStore(),
            catalogLoader: _loadCatalog,
          ),
        ),
      );
      await tester.pumpAndSettle();
      tester
          .widget<DropdownButton<String>>(
            find.byKey(const Key('exp-calc-map-selector')),
          )
          .onChanged!('7-1');
      await tester.pumpAndSettle();
      tester
          .widget<DropdownButton<String>>(
            find.byKey(const Key('exp-calc-point-selector-0')),
          )
          .onChanged!('D');
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('exp-calc-base-exp-input')))
            .controller!
            .text,
        '180',
      );
      expect(find.text('648'), findsOneWidget);
    },
  );

  for (final width in [320.0, 760.0]) {
    testWidgets('fits $width px with larger Japanese text', (tester) async {
      tester.view.physicalSize = Size(width, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ja'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!,
          ),
          home: ExpCalcPage(
            state: const GameState(),
            store: FakeExpTrackerStore(),
            catalogLoader: _loadCatalog,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'catalog updates refresh automatic EXP and preserve manual overrides',
    (tester) async {
      final updater = _CatalogUpdater(_catalogWithExperience([200, 300]));
      final controller = SortieMapCatalogController(
        data: _catalogWithExperience([100, 200]),
        updater: updater,
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _testableApp(
          ExpCalcPage(
            state: const GameState(),
            store: FakeExpTrackerStore(),
            catalogController: controller,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final input = find.byKey(const Key('exp-calc-base-exp-input'));
      String value() => tester.widget<TextField>(input).controller!.text;
      expect(value(), '150');
      await controller.checkForUpdates();
      await tester.pumpAndSettle();
      expect(value(), '250');
      await tester.enterText(input, '123.5');
      updater.next = _catalogWithExperience([300, 400]);
      await controller.checkForUpdates();
      await tester.pumpAndSettle();
      expect(value(), '123.5');
      expect(find.byKey(const Key('exp-calc-restore-0')), findsNothing);
      final selector = find.byKey(const Key('exp-calc-point-selector-0'));
      final selectedPoint = tester
          .widget<DropdownButton<String>>(selector)
          .value!;
      await tester.ensureVisible(selector);
      await tester.tap(selector);
      await tester.pumpAndSettle();
      await tester.tap(find.text(selectedPoint).last);
      await tester.pumpAndSettle();
      expect(value(), '350');
    },
  );

  testWidgets(
    'unknown EXP is visible, partial coverage is disclosed and manual input works',
    (tester) async {
      final store = FakeExpTrackerStore();
      await tester.pumpWidget(
        _testableApp(
          ExpCalcPage(
            state: const GameState(),
            store: store,
            catalogLoader: () async => _catalogWithExperience([null]),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('暂无经验资料，请手动输入'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('exp-calc-add-button')))
            .onPressed,
        isNull,
      );
      await tester.enterText(
        find.byKey(const Key('exp-calc-base-exp-input')),
        '200',
      );
      await tester.pumpAndSettle();
      expect(find.text('720'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('exp-calc-add-button')));
      await tester.tap(find.byKey(const Key('exp-calc-add-button')));
      await tester.pumpAndSettle();
      expect(store.items.single.baseExp, 200);
      await tester.pumpWidget(
        _testableApp(
          ExpCalcPage(
            state: const GameState(),
            store: store,
            catalogLoader: () async => _catalogWithExperience([100, null, 200]),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('部分经验缺失，仅按已知编成估算'), findsOneWidget);
    },
  );

  testWidgets(
    'load failure offers retry and loading the real bundled asset succeeds',
    (tester) async {
      var attempts = 0;
      await tester.pumpWidget(
        _testableApp(
          ExpCalcPage(
            state: const GameState(),
            store: FakeExpTrackerStore(),
            catalogLoader: () async {
              if (++attempts == 1) throw StateError('load failed');
              return _assetCatalog;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('海域资料读取失败，可重试或手动输入'), findsOneWidget);
      await tester.tap(find.text('重试'));
      await tester.pumpAndSettle();
      expect(find.text('540'), findsOneWidget);
      await tester.pumpWidget(
        _testableApp(
          ExpCalcPage(state: const GameState(), store: FakeExpTrackerStore()),
        ),
      );
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pumpAndSettle();
      expect(find.text('540'), findsOneWidget);
    },
  );

  testWidgets(
    'compact target fields share a row and legacy branding is removed',
    (tester) async {
      tester.view.physicalSize = const Size(390, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        _testableApp(
          ExpCalcPage(
            catalogLoader: _loadCatalog,
            state: const GameState(),
            store: FakeExpTrackerStore(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Yahagi Route Planner'), findsNothing);
      expect(find.textContaining('阶段'), findsNothing);
      expect(find.textContaining('STEP'), findsNothing);
      final current = tester.getCenter(
        find.byKey(const Key('exp-calc-current-level')),
      );
      final target = tester.getCenter(
        find.byKey(const Key('exp-calc-target-level')),
      );
      expect((current.dy - target.dy).abs(), lessThan(24));
      expect(current.dx, lessThan(target.dx));
    },
  );

  testWidgets(
    'invalid base experience cannot create a fabricated tracking estimate',
    (tester) async {
      final store = FakeExpTrackerStore();
      await tester.pumpWidget(
        _testableApp(
          ExpCalcPage(
            catalogLoader: _loadCatalog,
            state: const GameState(),
            store: store,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('exp-calc-base-exp-input')),
        '',
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('exp-calc-add-button')));
      await tester.tap(find.byKey(const Key('exp-calc-add-button')));
      await tester.pumpAndSettle();
      expect(store.items, isEmpty);
    },
  );

  testWidgets(
    'renders ExpCalcPage with initial empty state and default fields',
    (tester) async {
      final store = FakeExpTrackerStore();
      const state = GameState(memberId: 1);

      await tester.pumpWidget(
        _testableApp(
          ExpCalcPage(catalogLoader: _loadCatalog, state: state, store: store),
        ),
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
        _testableApp(
          ExpCalcPage(catalogLoader: _loadCatalog, state: state, store: store),
        ),
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

      await tester.tap(find.byKey(const Key('exp-calc-ship-selector')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('exp-calc-ship-category-cl')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('exp-calc-ship-option-1')), findsNothing);
      expect(find.byKey(const Key('exp-calc-ship-option-2')), findsOneWidget);
      expect(
        tester
            .getTopLeft(find.byKey(const Key('exp-calc-ship-option-custom')))
            .dy,
        lessThan(
          tester.getTopLeft(find.byKey(const Key('exp-calc-ship-option-2'))).dy,
        ),
      );
      await tester.tap(find.byKey(const Key('exp-calc-ship-option-2')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('exp-calc-ship-dialog')), findsNothing);
      expect(find.text('4500 EXP'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('exp-calc-current-level')))
            .controller!
            .text,
        '10',
      );
      await tester.tap(find.byKey(const Key('exp-calc-ship-selector')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('exp-calc-ship-category-cv')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('exp-calc-ship-option-custom')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('exp-calc-ship-option-2')), findsNothing);
      await tester.tap(find.byKey(const Key('exp-calc-ship-option-custom')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('exp-calc-current-level')))
            .readOnly,
        isFalse,
      );
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
        _testableApp(
          ExpCalcPage(catalogLoader: _loadCatalog, state: state, store: store),
        ),
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
      await tester.tap(find.byKey(const Key('exp-calc-add-point-C')));
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
        _testableApp(
          ExpCalcPage(catalogLoader: _loadCatalog, state: state, store: store),
        ),
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
        _testableApp(
          ExpCalcPage(
            catalogLoader: _loadCatalog,
            state: updatedState,
            store: store,
          ),
        ),
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
    'renders only the tracking table without overflow at 360px width',
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
        _testableApp(
          ExpCalcPage(catalogLoader: _loadCatalog, state: state, store: store),
        ),
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

      // Narrow screens keep the same horizontally scrollable table.
      expect(find.byKey(const Key('exp-calc-track-list')), findsOneWidget);
      expect(find.text('1787 次'), findsOneWidget);

      expect(find.byType(DataTable), findsOneWidget);
      expect(find.byKey(const Key('exp-calc-view-card')), findsNothing);
      expect(find.text('母港数据变动时自动刷新剩余经验与场次'), findsNothing);
      expect(find.text('总收益'), findsOneWidget);
      expect(find.text('删除'), findsNothing);
      expect(find.byIcon(Icons.cancel_outlined), findsOneWidget);
    },
  );

  testWidgets('uses the table tracker throughout the single-column range', (
    tester,
  ) async {
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

    tester.view.physicalSize = const Size(700, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      _testableApp(
        ExpCalcPage(catalogLoader: _loadCatalog, state: state, store: store),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('exp-calc-compact-workspace')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('exp-calc-add-button')));
    await tester.tap(find.byKey(const Key('exp-calc-add-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('exp-calc-track-list')), findsOneWidget);
    expect(find.byType(DataTable), findsOneWidget);
  });
}

SortieMapCatalogData _catalogWithExperience(List<int?> values) =>
    SortieMapCatalogData.fromJson({
      'version': 1,
      'source': 'test',
      'maps': [
        {
          'id': '5-2',
          'nameJa': '珊瑚諸島沖',
          'difficulty': 1,
          'coverAsset': '',
          'mapAsset': '',
          'nodes': [
            {
              'point': 'C',
              'kind': 'battle',
              'typeLabel': '',
              'battleTypeLabel': '',
              'formations': [
                for (var i = 0; i < values.length; i++)
                  {
                    'variant': i + 1,
                    'experience': values[i],
                    'fleetGroups': [],
                    'final': i == values.length - 1,
                  },
              ],
            },
          ],
        },
      ],
    });

class _CatalogUpdater implements SortieMapCatalogUpdateClient {
  _CatalogUpdater(this.next);
  SortieMapCatalogData next;
  @override
  Future<SortieMapCatalogUpdateResult> checkAndUpdate({
    required SortieMapCatalogData current,
  }) async => SortieMapCatalogUpdated(
    InstalledSortieMapCatalog(data: next, root: Directory.systemTemp),
    sourceHost: 'test',
  );
}
