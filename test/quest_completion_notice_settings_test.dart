import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_controller.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_completion_drawer.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_completion_feedback.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_store.dart';
import 'package:yahagi_kancolle_browser/src/widgets/top_notice.dart';

import 'fixtures/kcsapi_fixtures.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_api_event_pipeline.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_progress_engine.dart';
import 'package:yahagi_kancolle_browser/src/notice/game_info_notice_controller.dart';
import 'package:yahagi_kancolle_browser/src/performance/frame_notification_coalescer.dart';

void main() {
  setUp(() {
    GameStateController.disableTimerForTest = true;
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() => GameStateController.disableTimerForTest = false);

  Future<void> completeQuest(GameStateController game) async {
    game.accept(
      kcsapiEvent(
        '/kcsapi/api_get_member/questlist',
        {
          'api_exec_count': 1,
          'api_count': 1,
          'api_page_count': 1,
          'api_list': [
            {
              'api_no': 9001,
              'api_title': '测试任务',
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
  }

  Future<void> pumpHarness(
    WidgetTester tester, {
    required GameStateController game,
    required LayoutSettingsController layout,
    required TopNoticeController notices,
  }) => tester.pumpWidget(
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
                  builder: (_, count) => Text('count:$count'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  for (final succeeded in [false, true]) {
    testWidgets(
      'real improvement pipeline shows result and quest completion: $succeeded',
      (tester) async {
        final game = GameStateController(
          initialState: GameState.empty.copyWith(
            memberId: 100,
            quests: {
              619: GameQuest(
                id: 619,
                title: '装备的改修强化',
                detail: '',
                category: 6,
                type: 1,
                state: 2,
                progressFlag: 0,
                updatedAt: DateTime.now().toUtc(),
              ),
            },
          ),
          questProgress: await tester.runAsync(QuestProgressEngine.load),
        );
        final layout = await LayoutSettingsController.load(
          SharedPreferencesLayoutSettingsStore(),
        );
        final notices = TopNoticeController();
        addTearDown(game.dispose);
        addTearDown(layout.dispose);
        addTearDown(notices.dispose);
        await game.initialize();
        await pumpHarness(tester, game: game, layout: layout, notices: notices);
        final info = GameInfoNoticeController(
          stateProvider: () => game.state,
          layoutSettingsController: layout,
          topNoticeController: notices,
        );
        final pipeline = GameApiEventPipeline(
          consumers: [game, info],
          settleGameState: () => game.idle,
        );
        pipeline.add(
          kcsapiEvent(
            '/kcsapi/api_req_kousyou/remodel_slot',
            {'api_remodel_flag': succeeded ? 1 : 0},
            capturedAt: DateTime.now().toUtc(),
          ),
        );
        await pipeline.idle;
        expect(game.lastError, isNull);
        expect(game.state.quests[619]?.isCompleted, isTrue);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
        expect(find.text('任务达成：装备的改修强化'), findsOneWidget);
        expect(find.text(succeeded ? '装备改修成功' : '装备改修失败'), findsOneWidget);
        expect(notices.notices, hasLength(2));
        await tester.pumpWidget(const SizedBox.shrink());
        notices.hide();
      },
    );
  }
  testWidgets('task completion obeys the top notice enabled setting', (
    tester,
  ) async {
    final game = GameStateController();
    final layout = await LayoutSettingsController.load(
      SharedPreferencesLayoutSettingsStore(),
    );
    final notices = TopNoticeController();
    addTearDown(game.dispose);
    addTearDown(layout.dispose);
    addTearDown(notices.dispose);
    await game.initialize();
    await layout.setTopNoticeEnabled(false);
    await pumpHarness(tester, game: game, layout: layout, notices: notices);

    await completeQuest(game);
    await tester.pump();
    await tester.pump();

    expect(notices.notices, isEmpty);
    expect(find.text('count:1'), findsOneWidget);
  });

  testWidgets('task completion uses the configured display duration', (
    tester,
  ) async {
    final game = GameStateController();
    final layout = await LayoutSettingsController.load(
      SharedPreferencesLayoutSettingsStore(),
    );
    final notices = TopNoticeController();
    addTearDown(game.dispose);
    addTearDown(layout.dispose);
    addTearDown(notices.dispose);
    await game.initialize();
    await layout.setTopNoticeDurationSeconds(10);
    await pumpHarness(tester, game: game, layout: layout, notices: notices);

    await completeQuest(game);
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(seconds: 6));

    expect(notices.current?.message, '任务达成：测试任务');
    await tester.pump(const Duration(seconds: 4));
    expect(notices.current, isNull);
  });

  testWidgets(
    'completion keeps its title across another state update before display',
    (tester) async {
      final game = GameStateController(
        captureNotifications: FrameNotificationCoalescer(
          scheduleFrame: (callback) => callback(),
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
      await pumpHarness(tester, game: game, layout: layout, notices: notices);
      await completeQuest(game);
      await completeQuest(game);
      await tester.pump();
      expect(notices.current?.message, '任务达成：测试任务');
      await tester.pumpWidget(const SizedBox.shrink());
      notices.hide();
    },
  );
}
