import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_completion_drawer.dart';
import 'package:yahagi_kancolle_browser/src/widgets/top_notice.dart';

void main() {
  testWidgets(
    'native fullscreen notice follows quest visibility and account clearing',
    (tester) async {
      const channel = MethodChannel(
        'app.yahagi.kancollebrowser/game_fullscreen',
      );
      final messages = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        if (call.method == 'questNotice') {
          messages.add((call.arguments as Map)['message'] as String);
        }
        return null;
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      final controller = TopNoticeController();
      addTearDown(controller.dispose);
      Widget page(bool fullscreen) => MaterialApp(
        home: Scaffold(
          body: QuestCompletionDrawerHost(
            controller: controller,
            fullscreen: fullscreen,
            nativeQuestOverlay: true,
            child: const SizedBox.expand(),
          ),
        ),
      );
      await tester.pumpWidget(page(true));
      controller.show(message: '任务达成：出击', tone: TopNoticeTone.quest);
      await tester.pump();
      expect(messages, contains('任务达成：出击'));
      controller.removeByTone(TopNoticeTone.quest);
      await tester.pump();
      expect(messages.last, '');
      controller.show(message: '任务达成：工厂', tone: TopNoticeTone.quest);
      await tester.pump();
      expect(messages.last, '任务达成：工厂');
      await tester.pumpWidget(page(false));
      await tester.pump();
      expect(messages.last, '');
      controller.hide();
    },
  );

  testWidgets('completion remains visible over fullscreen game', (
    tester,
  ) async {
    late BuildContext target;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QuestCompletionDrawerHost(
            fullscreen: true,
            child: Builder(
              builder: (context) {
                target = context;
                return const SizedBox.expand(key: Key('game-surface'));
              },
            ),
          ),
        ),
      ),
    );
    QuestCompletionDrawerHost.show(target, '任务达成：出击');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('任务达成：出击'), findsOneWidget);
    expect(find.byKey(const Key('game-surface')), findsOneWidget);
  });

  testWidgets('completion remains visible while game toolbar is expanded', (
    tester,
  ) async {
    late BuildContext target;
    await tester.pumpWidget(
      MaterialApp(
        home: QuestCompletionDrawerHost(
          child: Builder(
            builder: (context) {
              target = context;
              return const SizedBox(
                height: 44,
                child: QuestCompletionHeaderSlot(
                  toolbarVisible: true,
                  child: Text('controls'),
                ),
              );
            },
          ),
        ),
      ),
    );
    QuestCompletionDrawerHost.show(
      target,
      '任务达成：出击',
      duration: const Duration(seconds: 15),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('任务达成：出击'), findsOneWidget);
  });

  testWidgets(
    'notice occupies header toolbar slot, yields to controls and expires after 15 seconds',
    (tester) async {
      late BuildContext target;
      var toolbar = false;
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuestCompletionDrawerHost(
              child: StatefulBuilder(
                builder: (context, setState) {
                  target = context;
                  return Column(
                    children: [
                      SizedBox(
                        height: 44,
                        child: Row(
                          children: [
                            SizedBox(
                              width: 120,
                              child: TextButton(
                                onPressed: () =>
                                    setState(() => toolbar = !toolbar),
                                child: const Text('Yahagi'),
                              ),
                            ),
                            Expanded(
                              child: QuestCompletionHeaderSlot(
                                toolbarVisible: toolbar,
                                child: TextButton(
                                  onPressed: () => taps++,
                                  child: Text(toolbar ? 'controls' : 'stats'),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: SizedBox.expand(key: const Key('workspace')),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );
      final workspace = tester.getRect(find.byKey(const Key('workspace')));
      // Normal brand interaction still opens functional controls.
      await tester.tap(find.text('Yahagi'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('controls'));
      expect(taps, 1);
      // Incoming completion must not replace controls the user is using.
      QuestCompletionDrawerHost.show(
        target,
        '有任务已完成',
        tone: TopNoticeTone.info,
      );
      await tester.pumpAndSettle();
      expect(find.text('有任务已完成'), findsNothing);
      await tester.tap(find.text('controls'));
      expect(taps, 2);
      await tester.tap(find.text('Yahagi'));
      await tester.pumpAndSettle();
      QuestCompletionDrawerHost.show(
        target,
        '有任务已完成',
        tone: TopNoticeTone.info,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      final notice = tester.getRect(
        find.byKey(const Key('quest-completion-drawer')),
      );
      expect(notice.left, 120);
      expect(notice.top, 5);
      expect(notice.height, 34);
      expect(notice.bottom, lessThanOrEqualTo(workspace.top));
      expect(tester.getRect(find.byKey(const Key('workspace'))), workspace);
      await tester.tap(find.text('Yahagi'));
      await tester.pumpAndSettle();
      expect(find.text('有任务已完成'), findsNothing);
      await tester.tap(find.text('controls'));
      expect(taps, 3);
      await tester.tap(find.text('Yahagi'));
      await tester.pumpAndSettle();
      expect(find.text('有任务已完成'), findsOneWidget);
      await tester.tap(find.byKey(const Key('quest-completion-drawer')));
      await tester.pumpAndSettle();
      expect(find.text('有任务已完成'), findsNothing);
      expect(taps, 3); // Dismissal must not click through to the header.
      QuestCompletionDrawerHost.show(
        target,
        '有任务已完成',
        tone: TopNoticeTone.info,
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 10));
      QuestCompletionDrawerHost.show(
        target,
        '有任务已完成',
        tone: TopNoticeTone.info,
        duration: const Duration(seconds: 15),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 14));
      expect(find.text('有任务已完成'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('有任务已完成'), findsNothing);
      await tester.tap(find.text('Yahagi'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('controls'));
      expect(taps, 4);
      expect(tester.getRect(find.byKey(const Key('workspace'))), workspace);
      expect(tester.takeException(), isNull);
    },
  );
}
