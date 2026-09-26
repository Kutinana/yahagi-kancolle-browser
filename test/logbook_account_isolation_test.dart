import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/account/account_session.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/logbook/logbook_database.dart';
import 'package:yahagi_kancolle_browser/src/logbook/logbook_event_recorder.dart';

import 'fixtures/kcsapi_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final session = AccountSession.shared;
  final opened = <LogbookDatabase>{};

  setUp(() => session.reset());
  tearDown(() async {
    for (final database in opened) {
      await database.close();
    }
    opened.clear();
    session.reset();
  });

  test(
    'logbook queries and clearing are limited to the selected account',
    () async {
      session.selectMember(1001);
      final first = LogbookDatabase.instance;
      opened.add(first);
      await first.insertRetirementRecord(
        timestamp: 100,
        type: '解体',
        shipType: '驱逐舰',
        shipName: '三日月',
        level: 1,
      );

      session.selectMember(2002);
      final second = LogbookDatabase.instance;
      opened.add(second);
      expect(await second.getRetirementRecords(), isEmpty);
      await second.insertRetirementRecord(
        timestamp: 200,
        type: '解体',
        shipType: '驱逐舰',
        shipName: '五月雨',
        level: 2,
      );
      await second.clearAll();

      session.selectMember(1001);
      expect(
        (await LogbookDatabase.instance.getRetirementRecords())
            .single['ship_name'],
        '三日月',
      );
      session.reset();
      opened.add(LogbookDatabase.instance);
      expect(await LogbookDatabase.instance.getRetirementRecords(), isEmpty);
    },
  );

  test(
    'another account empty dock does not consume the first account pending construction',
    () async {
      final recorder = LogbookEventRecorder();
      session.selectMember(1001);
      final first = LogbookDatabase.instance;
      opened.add(first);
      await recorder.record(
        kcsapiEvent(
          '/kcsapi/api_req_kousyou/createship',
          <String, Object?>{},
          requestParams: const {
            'api_kdock_id': '1',
            'api_item1': '30',
            'api_item2': '30',
            'api_item3': '30',
            'api_item4': '30',
            'api_item5': '1',
          },
        ),
        const GameState(memberId: 1001),
      );
      expect(await first.getPendingConstructionRecordForDock(1), isNotNull);

      session.selectMember(2002);
      opened.add(LogbookDatabase.instance);
      await recorder.record(
        kcsapiEvent('/kcsapi/api_get_member/kdock', const [
          {'api_id': 1, 'api_state': 0, 'api_created_ship_id': 0},
        ]),
        const GameState(memberId: 2002),
      );
      expect(await first.getPendingConstructionRecordForDock(1), isNotNull);
      expect(
        await LogbookDatabase.instance.getPendingConstructionRecordForDock(1),
        isNull,
      );
    },
  );
}
