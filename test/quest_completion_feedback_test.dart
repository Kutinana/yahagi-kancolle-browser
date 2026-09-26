import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/main.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_controller.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_completion_feedback.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_progress_engine.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_progress_rules.dart';
import 'package:yahagi_kancolle_browser/src/quest/pinned_quests_summary.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_store.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_completion_drawer.dart';
import 'package:yahagi_kancolle_browser/src/widgets/top_notice.dart';
import 'fixtures/kcsapi_fixtures.dart';

void main() {
  setUp(() {
    GameStateController.disableTimerForTest = true;
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() => GameStateController.disableTimerForTest = false);

  testWidgets('switching accounts removes the previous completion notice', (
    tester,
  ) async {
    final first = GameStateController(
      initialState: const GameState(memberId: 1),
    );
    final second = GameStateController(
      initialState: const GameState(memberId: 2),
    );
    final layout = await LayoutSettingsController.load(
      SharedPreferencesLayoutSettingsStore(),
    );
    final notices = TopNoticeController();
    final active = ValueNotifier<GameStateController>(first);
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    addTearDown(layout.dispose);
    addTearDown(notices.dispose);
    addTearDown(active.dispose);
    await first.initialize();
    await second.initialize();
    final page = MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: QuestCompletionDrawerHost(
          controller: notices,
          child: Column(
            children: [
              const SizedBox(
                height: 44,
                child: QuestCompletionHeaderSlot(child: SizedBox.expand()),
              ),
              Expanded(
                child: ValueListenableBuilder<GameStateController>(
                  valueListenable: active,
                  builder: (_, game, _) => QuestCompletionFeedback(
                    controller: game,
                    layoutSettingsController: layout,
                    builder: (_, count) => Text('$count'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpWidget(page);
    first.accept(
      kcsapiEvent(
        '/kcsapi/api_get_member/questlist',
        {
          'api_exec_count': 1,
          'api_count': 1,
          'api_page_count': 1,
          'api_list': [
            {
              'api_no': 9001,
              'api_title': 'A 出击任务',
              'api_detail': '',
              'api_category': 1,
              'api_type': 4,
              'api_state': 3,
              'api_progress_flag': 0,
            },
          ],
        },
        requestParams: {'yahagi_full_quest_snapshot': 1},
      ),
    );
    await first.idle;
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('任务达成：A 出击任务'), findsOneWidget);
    active.value = second;
    await tester.pump();
    await tester.pump();
    expect(
      notices.notices.where((notice) => notice.tone == TopNoticeTone.quest),
      isEmpty,
    );
    expect(find.text('任务达成：A 出击任务'), findsNothing);
  });

  testWidgets('same frame keeps both completed and awaiting notices', (
    tester,
  ) async {
    final game = GameStateController(
      initialState: const GameState(
        memberId: 100,
        quests: {
          503: GameQuest(
            id: 503,
            title: '入渠任务',
            detail: '',
            category: 5,
            type: 1,
            state: 2,
            progressFlag: 0,
          ),
          609: GameQuest(
            id: 609,
            title: '解体任务',
            detail: '',
            category: 6,
            type: 1,
            state: 2,
            progressFlag: 0,
          ),
        },
      ),
      questProgress: QuestProgressEngine(
        goals: {
          503: QuestProgressGoal(503, {
            'type': 1,
            'repair': {'required': 1, 'init': 0},
          }),
          609: QuestProgressGoal(609, {
            'type': 1,
            'destroy_ship': {'required': 1, 'init': 0},
          }),
        },
        storage: _MemoryQuestProgressStorage(),
      ),
    );
    final layout = await LayoutSettingsController.load(
      SharedPreferencesLayoutSettingsStore(),
    );
    final notices = TopNoticeController();
    addTearDown(game.dispose);
    addTearDown(layout.dispose);
    addTearDown(notices.dispose);
    await game.initialize();
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: QuestCompletionDrawerHost(
            controller: notices,
            child: Column(
              children: [
                const SizedBox(
                  height: 44,
                  child: QuestCompletionHeaderSlot(child: SizedBox.expand()),
                ),
                Expanded(
                  child: QuestCompletionFeedback(
                    controller: game,
                    layoutSettingsController: layout,
                    builder: (_, count) => Text('$count'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final now = DateTime.now().toUtc();
    game.accept(
      kcsapiEvent(
        '/kcsapi/api_req_nyukyo/start',
        const {},
        includeApiData: false,
        capturedAt: now,
        requestParams: const {
          'api_ndock_id': '1',
          'api_ship_id': '999',
          'api_highspeed': '0',
        },
      ),
    );
    game.accept(
      kcsapiEvent(
        '/kcsapi/api_req_kousyou/destroyship',
        const {},
        capturedAt: now,
        requestParams: const {'api_ship_id': '1'},
      ),
    );
    await game.idle;
    await tester.pump();
    await tester.pump();
    expect(
      notices.notices.map((notice) => notice.message),
      containsAll(['任务达成：入渠任务', '任务目标已达成（待游戏确认）：解体任务']),
    );
    notices.hide();
  });

  testWidgets(
    'destruction count first alerts pending, then server confirmation alerts completed',
    (tester) async {
      final game = GameStateController(
        initialState: const GameState(
          memberId: 100,
          quests: {
            609: GameQuest(
              id: 609,
              title: '工厂解体任务',
              detail: '',
              category: 6,
              type: 1,
              state: 2,
              progressFlag: 0,
              progressCurrent: 0,
              progressRequired: 2,
              localCompletionVerified: false,
            ),
          },
        ),
        questProgress: QuestProgressEngine(
          goals: {
            609: QuestProgressGoal(609, {
              'type': 1,
              'destroy_ship': {'required': 2, 'init': 0},
            }),
          },
          storage: _MemoryQuestProgressStorage(),
        ),
      );
      final layout = await LayoutSettingsController.load(
        SharedPreferencesLayoutSettingsStore(),
      );
      addTearDown(game.dispose);
      addTearDown(layout.dispose);
      await game.initialize();
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: QuestCompletionDrawerHost(
              child: Column(
                children: [
                  const SizedBox(
                    height: 44,
                    child: QuestCompletionHeaderSlot(child: SizedBox.expand()),
                  ),
                  Expanded(
                    child: QuestCompletionFeedback(
                      controller: game,
                      layoutSettingsController: layout,
                      builder: (_, count) => PinnedQuestsSummary(
                        controller: game,
                        collapsed: false,
                        onToggleCollapse: () {},
                        onOpenQuest: (_) {},
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      game.accept(
        kcsapiEvent(
          '/kcsapi/api_req_kousyou/destroyship',
          const {},
          requestParams: const {'api_ship_id': '1,2'},
          capturedAt: DateTime.now().toUtc(),
        ),
      );
      await game.idle;
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(game.state.quests[609]?.exactProgressLabel, '2/2');
      expect(game.state.quests[609]?.isCompleted, isFalse);
      expect(find.text('2/2 · 已达成（待确认）'), findsOneWidget);
      expect(find.text('任务目标已达成（待游戏确认）：工厂解体任务'), findsOneWidget);

      game.accept(
        kcsapiEvent(
          '/kcsapi/api_get_member/questlist',
          {
            'api_exec_count': 1,
            'api_count': 1,
            'api_page_count': 1,
            'api_list': [
              {
                'api_no': 609,
                'api_title': '工厂解体任务',
                'api_detail': '',
                'api_category': 6,
                'api_type': 1,
                'api_state': 3,
                'api_progress_flag': 0,
              },
            ],
          },
          requestParams: {'yahagi_full_quest_snapshot': 1},
          capturedAt: DateTime.now().toUtc(),
        ),
      );
      await game.idle;
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(game.state.quests[609]?.isCompleted, isTrue);
      expect(find.text('完成'), findsOneWidget);
      expect(find.text('任务达成：工厂解体任务'), findsOneWidget);
    },
  );

  testWidgets(
    'real repair goal completes and alerts on action without questlist',
    (tester) async {
      final game = GameStateController(
        initialState: GameState.empty.copyWith(
          memberId: 100,
          quests: {
            503: const GameQuest(
              id: 503,
              title: '修理五次',
              detail: '',
              category: 5,
              type: 1,
              state: 2,
              progressFlag: 2,
              progressCurrent: 4,
              progressRequired: 5,
            ),
          },
        ),
        questProgress: QuestProgressEngine(
          goals: {
            503: QuestProgressGoal(503, {
              'type': 1,
              'repair': {'required': 5, 'init': 0},
            }),
          },
          storage: _MemoryQuestProgressStorage(),
        ),
      );
      final layout = await LayoutSettingsController.load(
        SharedPreferencesLayoutSettingsStore(),
      );
      addTearDown(game.dispose);
      addTearDown(layout.dispose);
      await game.initialize();
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: QuestCompletionDrawerHost(
              child: Column(
                children: [
                  const SizedBox(
                    height: 44,
                    child: QuestCompletionHeaderSlot(child: SizedBox.expand()),
                  ),
                  Expanded(
                    child: QuestCompletionFeedback(
                      controller: game,
                      layoutSettingsController: layout,
                      builder: (_, count) => PinnedQuestsSummary(
                        controller: game,
                        collapsed: false,
                        onToggleCollapse: () {},
                        onOpenQuest: (_) {},
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      game.accept(
        kcsapiEvent(
          '/kcsapi/api_req_nyukyo/start',
          const <String, Object?>{},
          includeApiData: false,
          capturedAt: DateTime.now().toUtc(),
          requestParams: const {
            'api_ndock_id': '1',
            'api_ship_id': '999',
            'api_highspeed': '0',
          },
        ),
      );
      await game.idle;
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(game.state.quests[503]?.isCompleted, isTrue);
      expect(find.text('完成'), findsOneWidget);
      expect(find.text('任务达成：修理五次'), findsOneWidget);
    },
  );

  testWidgets('completion shows a temporary notice and persistent task count', (
    tester,
  ) async {
    final game = GameStateController();
    final layout = await LayoutSettingsController.load(
      SharedPreferencesLayoutSettingsStore(),
    );
    await layout.setTopNoticeDurationSeconds(15);
    addTearDown(game.dispose);
    addTearDown(layout.dispose);
    await game.initialize();
    var selected = 0;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: QuestCompletionDrawerHost(
            child: Column(
              children: [
                const SizedBox(
                  height: 44,
                  child: QuestCompletionHeaderSlot(child: SizedBox.expand()),
                ),
                Expanded(
                  child: QuestCompletionFeedback(
                    controller: game,
                    layoutSettingsController: layout,
                    builder: (context, count) => WorkspaceNavigation(
                      controller: layout,
                      selectedIndex: selected,
                      onRight: false,
                      completedQuestCount: count,
                      onSelected: (value) => selected = value,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('quest-completion-count')), findsNothing);

    Future<void> update(List<int> ids) async {
      game.accept(
        kcsapiEvent(
          '/kcsapi/api_get_member/questlist',
          {
            'api_exec_count': ids.length,
            'api_count': ids.length,
            'api_page_count': 1,
            'api_list': [
              for (final id in ids)
                {
                  'api_no': id,
                  'api_title': '任务 $id',
                  'api_detail': '',
                  'api_category': 1,
                  'api_type': 4,
                  'api_state': 3,
                  'api_progress_flag': 0,
                },
            ],
          },
          requestParams: {'yahagi_full_quest_snapshot': 1},
        ),
      );
      await game.idle;
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
    }

    await update([9001, 9002]);
    expect(find.text('2 个任务已达成，请前往任务界面'), findsOneWidget);
    final badge = find.byKey(const Key('quest-completion-count'));
    expect(
      find.descendant(of: badge, matching: find.text('②')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('workspace-nav-quests')),
        matching: badge,
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('workspace-nav-quests')));
    expect(selected, 5);
    expect(badge, findsOneWidget);
    await tester.pump(const Duration(seconds: 14));
    expect(find.text('2 个任务已达成，请前往任务界面'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('2 个任务已达成，请前往任务界面'), findsNothing);
    expect(badge, findsOneWidget);
    await update([9001, 9002]);
    expect(find.text('2 个任务已达成，请前往任务界面'), findsNothing);
    await update([9002, 9003]);
    expect(find.text('任务达成：任务 9003'), findsOneWidget);
    expect(
      find.descendant(of: badge, matching: find.text('②')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('quest-completion-drawer')));
    await tester.pumpAndSettle();
    expect(find.text('任务达成：任务 9003'), findsNothing);
    expect(selected, 5);
    expect(
      find.descendant(of: badge, matching: find.text('②')),
      findsOneWidget,
    );
    await update([9002, 9003]);
    expect(find.text('任务达成：任务 9003'), findsNothing);
    game.accept(
      kcsapiEvent(
        '/kcsapi/api_req_quest/clearitemget',
        {},
        requestParams: {'api_quest_id': 9003},
      ),
    );
    await game.idle;
    await tester.pump();
    await tester.pump();
    expect(
      find.descendant(of: badge, matching: find.text('①')),
      findsOneWidget,
    );
    await update([]);
    expect(badge, findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'blue count remains attached to selected task in reordered right menu',
    (tester) async {
      final layout = await LayoutSettingsController.load(
        SharedPreferencesLayoutSettingsStore(),
      );
      addTearDown(layout.dispose);
      layout.reorderWorkspaceMenu(5, 0);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: WorkspaceNavigation(
              controller: layout,
              selectedIndex: 5,
              onRight: true,
              completedQuestCount: 12,
              onSelected: (_) {},
            ),
          ),
        ),
      );
      final badge = find.byKey(const Key('quest-completion-count'));
      final text = tester.widget<Text>(
        find.descendant(of: badge, matching: find.text('⑫')),
      );
      expect(text.style!.color, const Color(0xff69c7ff));
      expect(text.style!.shadows, isNotEmpty);
      expect(
        tester
            .getRect(find.byKey(const Key('workspace-nav-quests')))
            .contains(tester.getCenter(badge)),
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );
}

class _MemoryQuestProgressStorage implements QuestProgressStorage {
  String? value;

  @override
  Future<String?> read(int account) async => value;

  @override
  Future<void> write(int account, String value) async {
    this.value = value;
  }
}
