import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_controller.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_reducer.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_catalog.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_center_page.dart';

import 'fixtures/kcsapi_fixtures.dart';

void main() {
  testWidgets(
    'search finds Chinese translations and rewards with Poi OR semantics',
    (tester) async {
      final controller = GameStateController();
      final filters = QuestFilterController();
      addTearDown(controller.dispose);
      addTearDown(filters.dispose);
      final catalog = QuestCatalog(const [
        QuestCatalogEntry(
          gameId: 101,
          code: 'A1',
          name: '編成',
          description: '',
          translatedName: '组建舰队',
        ),
        QuestCatalogEntry(
          gameId: 201,
          code: 'Bd1',
          name: '出撃',
          description: '',
          rewards: '勲章',
          translatedDescription: '击败敌军',
        ),
        QuestCatalogEntry(gameId: 301, code: 'C1', name: '演習', description: ''),
      ]);
      await tester.pumpWidget(
        MaterialApp(
          home: QuestCenterPage(
            controller: controller,
            catalog: catalog,
            mode: QuestCenterMode.all,
            filterController: filters,
          ),
        ),
      );
      filters.setQuery('组建 勲章');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('quest-card-101')), findsOneWidget);
      expect(find.byKey(const Key('quest-card-201')), findsOneWidget);
      expect(find.byKey(const Key('quest-card-301')), findsNothing);
      filters.setCategory(2);
      filters.setPeriod(1);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('quest-card-101')), findsNothing);
      expect(find.byKey(const Key('quest-card-201')), findsOneWidget);
      filters.setQuery('does-not-exist');
      await tester.pumpAndSettle();
      expect(find.text('没有符合条件的任务'), findsOneWidget);
      await tester.tap(find.byKey(const Key('quest-empty-clear')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('quest-card-301')), findsOneWidget);
    },
  );

  for (final locale in [
    const Locale('zh'),
    const Locale('zh', 'Hant'),
    const Locale('ja'),
  ]) {
    for (final size in [const Size(740, 320), const Size(360, 640)]) {
      testWidgets('quest filters fit $size with $locale and enlarged text', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        final controller = GameStateController();
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          MaterialApp(
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.3)),
              child: child!,
            ),
            home: QuestCenterPage(
              controller: controller,
              catalog: QuestCatalog([]),
              mode: QuestCenterMode.all,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('quest-filter-button')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final completed = find.byKey(
          const Key('quest-filter-unlock-completed'),
        );
        await tester.ensureVisible(completed);
        await tester.tap(completed);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final acceptedOnly = find.byKey(
          const Key('quest-filter-accepted-only'),
        );
        await tester.ensureVisible(acceptedOnly);
        await tester.tap(acceptedOnly);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }

  test('complete unpaginated all-tab response replaces stale availability', () {
    final reducer = GameStateReducer();
    GameState receive(
      GameState state,
      Map<int, int> quests,
      String tab, {
      int? pages,
    }) => reducer.reduce(
      state,
      kcsapiEvent(
        '/kcsapi/api_get_member/questlist',
        {
          'api_count': quests.length,
          'api_exec_count': quests.values.where((s) => s >= 2).length,
          'api_page_count': ?pages,
          'api_list': [
            for (final q in quests.entries)
              {'api_no': q.key, 'api_state': q.value},
          ],
        },
        requestParams: {'api_tab_id': tab},
      ),
    );
    var state = receive(GameState.empty, {101: 1, 102: 2}, '0');
    state = receive(state, {103: 1}, '1');
    expect(state.availableQuests.keys, unorderedEquals([101, 102, 103]));
    state = receive(state, {104: 1}, '0', pages: 2);
    expect(state.availableQuests.containsKey(101), isTrue);
    state = receive(state, {105: 1}, '0');
    expect(state.availableQuests.keys, [105]);
    expect(state.quests, isEmpty);
    state = receive(state, {}, '0');
    expect(state.availableQuests, isEmpty);
  });

  test(
    'full refresh prunes missing quests without resetting exact progress',
    () {
      final reducer = GameStateReducer();
      final state = GameState.empty.copyWith(
        quests: {
          504: const GameQuest(
            id: 504,
            title: '',
            detail: '',
            category: 5,
            type: 1,
            state: 2,
            progressFlag: 0,
            progressCurrent: 3,
            progressRequired: 15,
          ),
          999: const GameQuest(
            id: 999,
            title: '',
            detail: '',
            category: 1,
            type: 4,
            state: 2,
            progressFlag: 0,
          ),
        },
      );
      final next = reducer.reduce(
        state,
        kcsapiEvent(
          '/kcsapi/api_get_member/questlist',
          {
            'api_count': 1,
            'api_exec_count': 1,
            'api_list': [
              {'api_no': 504, 'api_state': 2, 'api_progress_flag': 0},
            ],
          },
          requestParams: {'yahagi_full_quest_snapshot': 1},
        ),
      );
      expect(next.quests[504]?.progressCurrent, 3);
      expect(next.quests.containsKey(999), isFalse);
    },
  );

  test(
    'accepting a visible quest immediately updates active and available states',
    () {
      final reducer = GameStateReducer();
      final state = reducer.reduce(
        GameState.empty,
        kcsapiEvent('/kcsapi/api_get_member/questlist', {
          'api_exec_count': 0,
          'api_list': [
            {'api_no': 101, 'api_state': 1},
          ],
        }),
      );
      final event = kcsapiEvent(
        '/kcsapi/api_req_quest/start',
        {},
        requestParams: {'api_quest_id': 101},
      );
      final next = reducer.reduce(state, event);
      expect(next.quests[101]?.state, 2);
      expect(next.availableQuests[101]?.state, 2);
      expect(next.activeQuestCount, 1);
      expect(reducer.reduce(next, event).activeQuestCount, 1);
    },
  );
  test(
    'availability follows partial lists, stop, claim and full snapshots',
    () {
      final reducer = GameStateReducer();
      var state = GameState.empty;
      void receive(Map<int, int> quests, {bool full = false}) {
        state = reducer.reduce(
          state,
          kcsapiEvent(
            '/kcsapi/api_get_member/questlist',
            {
              'api_exec_count': quests.values
                  .where((state) => state >= 2)
                  .length,
              'api_list': [
                for (final entry in quests.entries)
                  {
                    'api_no': entry.key,
                    'api_state': entry.value,
                    'api_title': 'Quest ${entry.key}',
                  },
                -1,
              ],
            },
            requestParams: {if (full) 'yahagi_full_quest_snapshot': '1'},
          ),
        );
      }

      receive({101: 1, 102: 2});
      receive({103: 3});
      expect(state.availableQuests.keys, unorderedEquals([101, 102, 103]));
      expect(state.quests.keys, unorderedEquals([102, 103]));
      state = reducer.reduce(
        state,
        kcsapiEvent(
          '/kcsapi/api_req_quest/stop',
          {},
          requestParams: {'api_quest_id': '102'},
        ),
      );
      expect(state.availableQuests[102]?.state, 1);
      expect(state.quests.containsKey(102), isFalse);
      state = reducer.reduce(
        state,
        kcsapiEvent(
          '/kcsapi/api_req_quest/clearitemget',
          {},
          requestParams: {'api_quest_id': '103'},
        ),
      );
      expect(state.availableQuests.containsKey(103), isFalse);
      expect(state.quests.containsKey(103), isFalse);

      receive({101: 2});
      expect(state.quests.keys, [101]);
      receive({102: 1}, full: true);
      expect(state.availableQuests.keys, [102]);
      expect(state.quests, isEmpty);
      receive({}, full: true);
      expect(state.availableQuests, isEmpty);
    },
  );

  test('unseen tasks remain unknown until actually returned by the game', () {
    final catalog = QuestCatalog([
      const QuestCatalogEntry(
        gameId: 101,
        code: 'A1',
        name: '',
        description: '',
      ),
    ]);
    expect(
      catalog.project({}).byGameId(101).unlockState,
      QuestUnlockState.unknown,
    );
  });

  testWidgets(
    'unlocked filter includes unaccepted quests but excludes unseen quests',
    (tester) async {
      final controller = GameStateController();
      final filters = QuestFilterController()
        ..setUnlockState(QuestUnlockState.unlocked);
      addTearDown(controller.dispose);
      addTearDown(filters.dispose);
      final catalog = QuestCatalog([
        for (final id in [101, 102, 103, 104])
          QuestCatalogEntry(
            gameId: id,
            code: 'A$id',
            name: 'Quest $id',
            description: '',
          ),
      ]);
      controller.accept(
        kcsapiEvent('/kcsapi/api_get_member/questlist', {
          'api_exec_count': 2,
          'api_list': [
            for (final entry in {101: 1, 102: 2, 103: 3}.entries)
              {
                'api_no': entry.key,
                'api_state': entry.value,
                'api_title': 'Quest ${entry.key}',
              },
          ],
        }),
      );
      await controller.idle;
      await tester.pumpWidget(
        MaterialApp(
          home: QuestCenterPage(
            controller: controller,
            catalog: catalog,
            mode: QuestCenterMode.all,
            filterController: filters,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('quest-card-101')), findsOneWidget);
      expect(find.byKey(const Key('quest-card-102')), findsOneWidget);
      expect(find.byKey(const Key('quest-card-103')), findsOneWidget);
      expect(find.byKey(const Key('quest-card-104')), findsNothing);

      for (final label in {101: '未接取', 102: '进行中', 103: '待领取'}.entries) {
        expect(
          find.descendant(
            of: find.byKey(Key('quest-card-status-${label.key}')),
            matching: find.text(label.value),
          ),
          findsOneWidget,
        );
      }
      expect(find.text('共 3 个任务'), findsOneWidget);
      filters.setAcceptedOnly(true);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('quest-card-101')), findsNothing);
      expect(find.byKey(const Key('quest-card-102')), findsOneWidget);
      expect(find.byKey(const Key('quest-card-103')), findsOneWidget);
      filters.setUnlockState(QuestUnlockState.completed);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('quest-card-102')), findsNothing);
      expect(find.byKey(const Key('quest-card-103')), findsOneWidget);
      filters.setAcceptedOnly(false);

      filters.setUnlockState(QuestUnlockState.locked);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('quest-card-104')), findsOneWidget);
      expect(find.byKey(const Key('quest-card-101')), findsNothing);
      filters.setUnlockState(QuestUnlockState.completed);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('quest-card-103')), findsOneWidget);
      expect(find.byKey(const Key('quest-card-102')), findsNothing);
      expect(find.byKey(const Key('quest-card-104')), findsNothing);
      await tester.tap(find.byKey(const Key('quest-filter-button')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('quest-filter-unlock-completed')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('quest-filter-close')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('进行中').first);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('quest-card-101')), findsNothing);
      expect(find.byKey(const Key('quest-card-102')), findsOneWidget);
      expect(find.byKey(const Key('quest-card-103')), findsOneWidget);
      await controller.clearQuestsCache();
      expect(controller.state.availableQuests, isEmpty);
    },
  );
}
