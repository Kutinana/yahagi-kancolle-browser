import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/src/new_ship/new_ship_reminder_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test(
    'keeps exclusions and pending acquisitions isolated per account',
    () async {
      final store = NewShipReminderStore(await SharedPreferences.getInstance());
      final pending = PendingNewShipAcquisition(
        key: 'battle-42',
        masterIds: const <int>[4, 1],
        source: NewShipAcquisitionSource.battle,
        occurredAt: DateTime.utc(2026, 8, 26, 12),
      );

      await store.saveExcludedFamilyIds(1001, <int>{4, 1});
      expect(await store.loadExcludedFamilyIds(1001), <int>{1, 4});
      expect(await store.loadExcludedFamilyIds(1002), isEmpty);

      await store.savePending(1001, <PendingNewShipAcquisition>[pending]);
      final restored = await store.loadPending(1001);
      expect(restored, hasLength(1));
      expect(restored.single.key, 'battle-42');
      expect(restored.single.masterIds, <int>[1, 4]);
      expect(restored.single.source, NewShipAcquisitionSource.battle);
      expect(await store.loadPending(1002), isEmpty);
    },
  );

  test(
    'corrupt account data returns empty without affecting another account',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'new_ship.excluded.1001': '{broken',
        'new_ship.excluded.1002': '[4]',
        'new_ship.pending.1001': '{broken',
      });
      final store = NewShipReminderStore(await SharedPreferences.getInstance());

      expect(await store.loadExcludedFamilyIds(1001), isEmpty);
      expect(await store.loadPending(1001), isEmpty);
      expect(await store.loadExcludedFamilyIds(1002), <int>{4});
    },
  );
}
