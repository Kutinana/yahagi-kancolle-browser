import 'dart:convert';
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/account/account_session.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/src/bridge/captured_api_event.dart';
import 'package:yahagi_kancolle_browser/src/development/development_workbench_state_store.dart';
import 'package:yahagi_kancolle_browser/src/expedition/expedition_selection_store.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/improvement/improvement_favorites_store.dart';
import 'package:yahagi_kancolle_browser/src/improvement/improvement_dataset.dart';
import 'package:yahagi_kancolle_browser/src/improvement/improvement_planner_controller.dart';
import 'package:yahagi_kancolle_browser/src/kcwiki_report/kcwiki_report_collector.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    AccountSession.shared.reset();
    await SharedPreferencesDevelopmentWorkbenchStateStore.resetForTesting();
    SharedPreferences.setMockInitialValues({
      'expedition.selected_mission.fleet_2': 105,
      'improvement.favorite-equipment-ids.v1': <String>['1'],
      'development_workbench_state_v1': jsonEncode(
        const DevelopmentWorkbenchState(targetIds: [1]).toJson(),
      ),
    });
  });

  test(
    'switching accounts clears loaded improvement favorites immediately',
    () async {
      AccountSession.shared.selectMember(1001);
      final planner = ImprovementPlannerController(
        dataset: ImprovementDataset(
          version: const ImprovementDatasetVersion(
            dataVersion: 'test',
            commitSha: '',
          ),
          entries: [],
        ),
      );
      addTearDown(planner.dispose);
      await planner.toggleFavorite(7);
      AccountSession.shared.selectMember(2002);
      expect(planner.favoriteEquipmentIds, isEmpty);
    },
  );

  test(
    'account A and B keep independent plans across immediate queued saves',
    () async {
      final session = AccountSession(initialMemberId: 1001);
      addTearDown(session.dispose);
      final expedition = SharedPreferencesExpeditionSelectionStore(
        accountSession: session,
      );
      final improvement = SharedPreferencesImprovementFavoritesStore(
        accountSession: session,
      );
      final development = SharedPreferencesDevelopmentWorkbenchStateStore(
        accountSession: session,
      );
      final oldSaves = Future.wait([
        expedition.saveMissionId(2, 105),
        improvement.save({7}),
        development.save(const DevelopmentWorkbenchState(targetIds: [7])),
      ]);
      session.selectMember(2002);
      expect(await expedition.loadMissionId(2), isNull);
      expect(await improvement.load(), isEmpty);
      expect(await development.load(), isNull);
      await Future.wait([
        expedition.saveMissionId(2, 112),
        improvement.save({8}),
        development.save(const DevelopmentWorkbenchState(targetIds: [8])),
      ]);
      await oldSaves;
      expect(await expedition.loadMissionId(2), 112);
      expect(await improvement.load(), {8});
      expect((await development.load())!.targetIds, [8]);
      session.selectMember(1001);
      expect(await expedition.loadMissionId(2), 105);
      expect(await improvement.load(), {7});
      expect((await development.load())!.targetIds, [7]);
    },
  );

  test(
    'old favorites load cannot overwrite newly loaded account favorites',
    () async {
      final session = AccountSession(initialMemberId: 1001);
      addTearDown(session.dispose);
      final store = _DeferredFavorites();
      final planner = ImprovementPlannerController(
        accountSession: session,
        favoritesStore: store,
        dataset: ImprovementDataset(
          version: const ImprovementDatasetVersion(
            dataVersion: 'test',
            commitSha: '',
          ),
          entries: [],
        ),
      );
      addTearDown(planner.dispose);
      final oldLoad = planner.loadFavorites();
      session.selectMember(2002);
      store.loads[1].complete({8});
      await Future<void>.delayed(Duration.zero);
      expect(planner.favoriteEquipmentIds, {8});
      store.loads[0].complete({7});
      await oldLoad;
      expect(planner.favoriteEquipmentIds, {8});
    },
  );

  test(
    'unidentified account cannot inherit legacy expedition selection',
    () async {
      expect(
        await const SharedPreferencesExpeditionSelectionStore().loadMissionId(
          2,
        ),
        isNull,
      );
    },
  );

  test(
    'unidentified account cannot inherit legacy improvement favorites',
    () async {
      expect(
        await SharedPreferencesImprovementFavoritesStore().load(),
        isEmpty,
      );
    },
  );

  test(
    'unidentified account cannot inherit legacy development targets',
    () async {
      expect(
        await SharedPreferencesDevelopmentWorkbenchStateStore().load(),
        isNull,
      );
    },
  );

  test('unidentified account does not persist private plans', () async {
    await const SharedPreferencesExpeditionSelectionStore().saveMissionId(
      2,
      112,
    );
    await SharedPreferencesImprovementFavoritesStore().save({8});
    await SharedPreferencesDevelopmentWorkbenchStateStore().save(
      const DevelopmentWorkbenchState(targetIds: [8]),
    );
    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getKeys().where((key) => key.startsWith('account.')),
      isEmpty,
    );
    expect(preferences.getInt('expedition.selected_mission.fleet_2'), 105);
    expect(preferences.getStringList('improvement.favorite-equipment-ids.v1'), [
      '1',
    ]);
  });

  test('report collector reset forgets previous account quest details', () {
    final collector = KcwikiReportCollector();
    collector.accept(
      _event('/kcsapi/api_get_member/questlist', {
        'api_list': [
          {'api_no': 101, 'api_title': 'old account'},
        ],
      }),
      GameState.empty,
    );
    collector.reset();
    collector.accept(
      _event(
        '/kcsapi/api_req_quest/clearitemget',
        {},
        params: {'api_quest_id': 101},
      ),
      GameState.empty,
    );
    final reports = collector.accept(
      _event('/kcsapi/api_get_member/questlist', {
        'api_list': [
          {'api_no': 102},
        ],
      }),
      GameState.empty,
    );
    expect(jsonEncode(reports.single.fields), isNot(contains('old account')));
  });
}

class _DeferredFavorites implements ImprovementFavoritesStore {
  final List<Completer<Set<int>>> loads = [];
  @override
  Future<Set<int>> load() {
    final result = Completer<Set<int>>();
    loads.add(result);
    return result.future;
  }

  @override
  Future<void> save(Set<int> equipmentIds) async {}
}

CapturedApiEvent _event(
  String path,
  Object data, {
  Map<String, Object?> params = const {},
}) {
  final envelope = <String, Object?>{'api_result': 1, 'api_data': data};
  return CapturedApiEvent(
    path: path,
    responseBody: jsonEncode(envelope),
    decodedEnvelope: envelope,
    requestParams: params,
    source: CaptureSource.manual,
    capturedAt: DateTime.utc(2026, 9, 12),
  );
}
