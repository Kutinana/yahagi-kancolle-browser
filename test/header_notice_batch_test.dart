import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_completion_drawer.dart';
import 'package:yahagi_kancolle_browser/src/widgets/top_notice.dart';

void main() {
  testWidgets('removing latest keyed notice keeps remaining batch expiry', (
    tester,
  ) async {
    final controller = TopNoticeController();
    addTearDown(controller.dispose);
    controller.show(message: '任务完成', duration: const Duration(seconds: 2));
    controller.show(
      message: '演习经验',
      replacementKey: 'practice',
      duration: const Duration(seconds: 2),
    );
    controller.removeByKey('practice');
    expect(controller.notices.map((n) => n.message), ['任务完成']);
    await tester.pump(const Duration(seconds: 2));
    expect(controller.notices, isEmpty);
  });

  testWidgets(
    'keyed replacement refreshes expiry without old timer clearing it',
    (tester) async {
      final controller = TopNoticeController();
      addTearDown(controller.dispose);
      controller.show(
        message: '旧对手',
        replacementKey: 'practice',
        duration: const Duration(seconds: 2),
      );
      await tester.pump(const Duration(seconds: 1));
      controller.show(
        message: '新对手',
        replacementKey: 'practice',
        duration: const Duration(seconds: 2),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(controller.notices.map((n) => n.message), ['新对手']);
      await tester.pump(const Duration(seconds: 1));
      expect(controller.notices, isEmpty);
      controller.show(message: '新演习', replacementKey: 'practice');
      controller.removeByKey('practice');
      expect(controller.notices, isEmpty);
    },
  );

  test(
    'near-simultaneous notices share one batch without replacing either',
    () {
      final controller = TopNoticeController();
      addTearDown(controller.dispose);

      controller.show(
        message: '装备改修成功',
        tone: TopNoticeTone.success,
        duration: const Duration(seconds: 10),
        appendWithin: const Duration(milliseconds: 500),
      );
      controller.show(
        message: '任务达成：装备的改修强化',
        tone: TopNoticeTone.quest,
        duration: const Duration(seconds: 10),
        appendWithin: const Duration(milliseconds: 500),
      );

      expect(controller.notices.map((notice) => notice.message), [
        '装备改修成功',
        '任务达成：装备的改修强化',
      ]);
    },
  );

  testWidgets(
    'batched notices render side by side and can scroll horizontally',
    (tester) async {
      final controller = TopNoticeController();
      addTearDown(controller.dispose);
      await tester.binding.setSurfaceSize(const Size(320, 160));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuestCompletionDrawerHost(
              controller: controller,
              child: const SizedBox(
                height: 44,
                child: QuestCompletionHeaderSlot(child: SizedBox.expand()),
              ),
            ),
          ),
        ),
      );
      controller.show(
        message: '装备改修成功',
        tone: TopNoticeTone.success,
        duration: const Duration(seconds: 10),
        appendWithin: const Duration(milliseconds: 500),
      );
      controller.show(
        message: '任务达成：这是一个需要横向滑动才能完整查看的装备改修任务',
        tone: TopNoticeTone.quest,
        duration: const Duration(seconds: 10),
        appendWithin: const Duration(milliseconds: 500),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.text('装备改修成功'), findsOneWidget);
      expect(find.text('任务达成：这是一个需要横向滑动才能完整查看的装备改修任务'), findsOneWidget);
      final scrollable = tester.state<ScrollableState>(
        find.descendant(
          of: find.byKey(const Key('header-notice-scroll')),
          matching: find.byType(Scrollable),
        ),
      );
      expect(scrollable.position.maxScrollExtent, greaterThan(0));
      final before = scrollable.position.pixels;
      await tester.drag(
        find.byKey(const Key('header-notice-scroll')),
        const Offset(-180, 0),
      );
      await tester.pumpAndSettle();
      expect(scrollable.position.pixels, greaterThan(before));
      // Appending to this batch preserves the user's reading position.
      final readingPosition = scrollable.position.pixels;
      controller.show(
        message: '追加通知',
        appendWithin: const Duration(seconds: 30),
      );
      await tester.pumpAndSettle();
      expect(scrollable.position.pixels, readingPosition);

      // A replacement is a new batch and must start at its beginning.
      controller.show(message: '新通知：${'完整消息内容' * 30}');
      await tester.pumpAndSettle();
      final replacement = tester.state<ScrollableState>(
        find.descendant(
          of: find.byKey(const Key('header-notice-scroll')),
          matching: find.byType(Scrollable),
        ),
      );
      expect(replacement.position.pixels, 0);
      controller.hide();
      await tester.pump();
    },
  );
}
