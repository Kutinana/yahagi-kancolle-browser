import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_completion_tracker.dart';

final now = DateTime.utc(2026, 9, 11, 10);
GameQuest quest(
  int id, {
  int state = 3,
  int type = 1,
  int? current,
  bool? verified,
  DateTime? at,
}) => GameQuest(
  id: id,
  title: '任务 $id',
  detail: '',
  category: 1,
  type: type,
  state: state,
  progressFlag: 0,
  progressCurrent: current,
  progressRequired: current == null ? null : 3,
  localCompletionVerified: verified,
  updatedAt: at ?? now,
);
GameState snapshot(List<GameQuest> quests, {int member = 1}) => GameState.empty
    .copyWith(memberId: member, quests: {for (final q in quests) q.id: q});

void main() {
  test('counts cached completions without replaying notices', () {
    final state = snapshot([quest(1), quest(2, state: 2)]);
    final tracker = QuestCompletionTracker(state, now: now);
    expect(tracker.completedCount, 1);
    expect(tracker.update(state, now: now), isFalse);
  });

  test('new completions alert once, including when count stays unchanged', () {
    final tracker = QuestCompletionTracker(snapshot([]), now: now);
    expect(tracker.update(snapshot([quest(1)]), now: now), isTrue);
    expect(tracker.update(snapshot([quest(1)]), now: now), isFalse);
    expect(tracker.update(snapshot([quest(2)]), now: now), isTrue);
    expect(tracker.completedCount, 1);
    expect(tracker.update(snapshot([]), now: now), isFalse);
    expect(tracker.completedCount, 0);
    // A repeated page or reaccepted task must not replay the same alert.
    expect(tracker.update(snapshot([quest(1)]), now: now), isFalse);
  });

  test('local completion and server confirmation share one alert', () {
    final tracker = QuestCompletionTracker(snapshot([]), now: now);
    expect(
      tracker.update(snapshot([quest(1, state: 2, current: 3)]), now: now),
      isTrue,
    );
    expect(tracker.update(snapshot([quest(1)]), now: now), isFalse);
    expect(tracker.completedCount, 1);
  });

  test('ignores unaccepted, expired and unverified local completions', () {
    final tracker = QuestCompletionTracker(snapshot([]), now: now);
    expect(
      tracker.update(
        snapshot([
          quest(1, state: 1, current: 3),
          quest(2, at: now.subtract(const Duration(days: 1))),
          quest(3, state: 2, current: 3, verified: false),
        ]),
        now: now,
      ),
      isFalse,
    );
    expect(tracker.completedCount, 0);
  });

  test('daily reset clears badge and permits next period notification', () {
    final tracker = QuestCompletionTracker(snapshot([quest(1)]), now: now);
    final tomorrow = now.add(const Duration(days: 1));
    expect(tracker.update(snapshot([quest(1)]), now: tomorrow), isFalse);
    expect(tracker.completedCount, 0);
    expect(
      tracker.update(snapshot([quest(1, at: tomorrow)]), now: tomorrow),
      isTrue,
    );
  });

  test('account switch seeds a new baseline without old-account alerts', () {
    final tracker = QuestCompletionTracker(snapshot([quest(1)]), now: now);
    expect(tracker.update(snapshot([quest(2)], member: 2), now: now), isFalse);
    expect(tracker.completedCount, 1);
    expect(
      tracker.update(snapshot([quest(2), quest(1)], member: 2), now: now),
      isTrue,
    );
  });
}
