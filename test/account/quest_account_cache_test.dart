import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/quest/shared_preferences_quest_store.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_progress_engine.dart';
import '../fixtures/kcsapi_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'unowned legacy quest cache is not assigned to the next login',
    () async {
      SharedPreferences.setMockInitialValues({
        'yahagi_quests': jsonEncode([
          {
            'id': 201,
            'state': 3,
            'title': 'old',
            'detail': '',
            'category': 1,
            'type': 1,
            'progressFlag': 0,
          },
        ]),
      });
      expect(await SharedPreferencesQuestStore().loadQuests(), isEmpty);
    },
  );

  test(
    'new login clears claimed quest memory without deleting its owner ledger',
    () async {
      final now = DateTime.utc(2026, 9, 12);
      final storage = _ProgressStorage()
        ..values[1001] = jsonEncode({
          'account': 1001,
          'records': {
            '201': {'period': 'once', 'type': 4, 'claimed': true},
          },
        });
      final engine = QuestProgressEngine(goals: {}, storage: storage);
      await engine.restore(const GameState(memberId: 1001), now);
      expect(engine.completedIds(now), {201});
      await engine.process(
        const GameState(memberId: 1001),
        GameState.empty,
        kcsapiEvent('/kcsapi/api_start2/getData', {}, capturedAt: now),
      );
      expect(engine.completedIds(now), isEmpty);
      expect(storage.values[1001], contains('claimed'));
    },
  );
}

class _ProgressStorage implements QuestProgressStorage {
  final values = <int, String>{};
  @override
  Future<String?> read(int account) async => values[account];
  @override
  Future<void> write(int account, String value) async {
    values[account] = value;
  }
}
