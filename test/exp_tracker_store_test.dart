import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/src/account/account_session.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/exp_calc/exp_calc_models.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/exp_calc/exp_tracker_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'SharedPreferencesExpTrackerStore saves and loads track items per account',
    () async {
      final sessionA = AccountSession(initialMemberId: 1001);
      final sessionB = AccountSession(initialMemberId: 2002);

      final storeA = SharedPreferencesExpTrackerStore(accountSession: sessionA);
      final storeB = SharedPreferencesExpTrackerStore(accountSession: sessionB);

      expect(await storeA.loadTrackItems(1001), isEmpty);
      expect(await storeB.loadTrackItems(2002), isEmpty);

      final itemA = ExpCalcTrackItem(
        id: 'item-a',
        shipInstanceId: 1,
        shipMasterId: 546,
        shipName: '武藏改二',
        targetLevel: 187,
        targetExp: 18600000,
        map: '5-2',
        rank: BattleRank.s,
        isFlagship: true,
        isMvp: true,
        baseExp: 150,
        mapExp: 540,
        recordedLevel: 186,
        recordedExp: 17635281,
      );

      await storeA.saveTrackItems(1001, [itemA]);

      final loadedA = await storeA.loadTrackItems(1001);
      expect(loadedA.length, 1);
      expect(loadedA.first.id, 'item-a');
      expect(loadedA.first.shipName, '武藏改二');
      expect(loadedA.first.targetLevel, 187);

      // Account B still sees empty list
      expect(await storeB.loadTrackItems(2002), isEmpty);
    },
  );

  test('stale page owner cannot write into a newly selected account', () async {
    final session = AccountSession(initialMemberId: 1001);
    final store = SharedPreferencesExpTrackerStore(accountSession: session);
    session.selectMember(2002);
    expect(await store.saveTrackItems(1001, const []), isFalse);
    expect(await store.loadTrackItems(2002), isEmpty);
  });

  test(
    'corrupt tracking data is reported instead of overwritten as empty',
    () async {
      SharedPreferences.setMockInitialValues({
        'account.1001.exp_calc.track_items.v1': '{invalid-json',
      });
      final store = SharedPreferencesExpTrackerStore(
        accountSession: AccountSession(initialMemberId: 1001),
      );
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString('account.1001.exp_calc.track_items.v1'),
        '{invalid-json',
      );
      await expectLater(store.loadTrackItems(1001), throwsFormatException);
    },
  );
}
