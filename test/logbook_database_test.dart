import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_models.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/logbook/logbook_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('concurrent lazy opens share one database operation', () async {
    final backing = await LogbookDatabase.openForTesting();
    final rawDatabase = await backing.database;
    final openCompleter = Completer<Database>();
    var openCalls = 0;
    final database = LogbookDatabase.lazyForTesting(() {
      openCalls += 1;
      return openCompleter.future;
    });
    addTearDown(database.close);

    final first = database.database;
    final second = database.database;

    expect(openCalls, 1);
    expect(identical(first, second), isTrue);
    openCompleter.complete(rawDatabase);
    expect(await first, same(await second));
  });

  test('table change signals only notify the matching log category', () async {
    final database = await LogbookDatabase.openForTesting();
    addTearDown(database.close);
    var battleChanges = 0;
    var developmentChanges = 0;
    database.changesFor(LogbookChangeCategory.battle).addListener(() {
      battleChanges += 1;
    });
    database.changesFor(LogbookChangeCategory.development).addListener(() {
      developmentChanges += 1;
    });

    await database.insertDevelopmentRecord(
      timestamp: 1000,
      success: true,
      equipmentId: 1,
      equipmentName: '测试装备',
      equipmentType: '主炮',
      equipmentIconId: 1,
      fuel: 10,
      ammo: 10,
      steel: 10,
      bauxite: 10,
      secretaryName: '测试秘书舰',
    );

    expect(developmentChanges, 1);
    expect(battleChanges, 0);
  });

  test(
    'resource snapshots are ordered and consecutive duplicates are skipped',
    () async {
      final database = await LogbookDatabase.openForTesting();
      addTearDown(database.close);
      var resourceChanges = 0;
      database.changesFor(LogbookChangeCategory.resource).addListener(() {
        resourceChanges += 1;
      });

      await Future.wait<void>(<Future<void>>[
        database.insertResourceSnapshot(_resourceState(100)),
        database.insertResourceSnapshot(_resourceState(100)),
        database.insertResourceSnapshot(_resourceState(120)),
      ]);

      final rows = await database.getAllResourceLogs();
      expect(rows.map((row) => row['fuel']), <Object?>[100, 120]);
      expect(resourceChanges, 2);
    },
  );

  test(
    'clearing logs resets resource deduplication and notifies every category',
    () async {
      final database = await LogbookDatabase.openForTesting();
      addTearDown(database.close);
      await database.insertResourceSnapshot(_resourceState(100));
      await database.insertConstructionStartRecord(
        dockId: 2,
        timestamp: 1000,
        constructionType: '普通建造',
        shipId: null,
        shipName: '建造中',
        shipType: '—',
        fuel: 30,
        ammo: 30,
        steel: 30,
        bauxite: 30,
        developmentMaterial: 1,
        secretaryName: '测试秘书舰',
      );
      final changes = <LogbookChangeCategory, int>{
        for (final category in LogbookChangeCategory.values) category: 0,
      };
      for (final category in LogbookChangeCategory.values) {
        database.changesFor(category).addListener(() {
          changes[category] = changes[category]! + 1;
        });
      }

      await database.clearAll();

      expect(changes.values, everyElement(1));
      expect(await database.getPendingConstructionRecordForDock(2), isNull);
      await database.insertResourceSnapshot(_resourceState(100));
      expect(await database.getAllResourceLogs(), hasLength(1));
    },
  );

  test(
    'stores new Poi log categories and pages them by descending id',
    () async {
      final database = await LogbookDatabase.openForTesting();
      addTearDown(database.close);

      for (var index = 0; index < 55; index++) {
        await database.insertDevelopmentRecord(
          timestamp: 1000 + index,
          success: index.isEven,
          equipmentId: index,
          equipmentName: '装备$index',
          equipmentType: '主炮',
          equipmentIconId: 1,
          fuel: 10,
          ammo: 20,
          steel: 30,
          bauxite: 40,
          secretaryName: '矢矧改二乙',
        );
      }

      final first = await database.getDevelopmentRecords(limit: 50);
      expect(first, hasLength(50));
      expect(first.first['equipment_name'], '装备54');
      final second = await database.getDevelopmentRecords(
        limit: 50,
        beforeId: first.last['id'] as int,
      );
      expect(second, hasLength(5));
      expect(second.last['equipment_name'], '装备0');

      await database.insertConstructionRecord(
        timestamp: 2000,
        constructionType: '普通建造',
        shipId: 1,
        shipName: '雪风',
        shipType: '驱逐舰',
        fuel: 30,
        ammo: 30,
        steel: 30,
        bauxite: 30,
        developmentMaterial: 1,
        secretaryName: '矢矧改二乙',
      );
      await database.insertRetirementRecord(
        timestamp: 3000,
        type: '改修',
        shipType: '驱逐舰',
        shipName: '深雪',
        level: 1,
      );

      expect(await database.getConstructionRecords(), hasLength(1));
      expect(await database.getRetirementRecords(), hasLength(1));
    },
  );

  test('construction pending mapping survives until collection', () async {
    final database = await LogbookDatabase.openForTesting();
    addTearDown(database.close);

    final id = await database.insertConstructionStartRecord(
      dockId: 2,
      timestamp: 1000,
      constructionType: '普通建造',
      shipId: 1,
      shipName: '雪风',
      shipType: '驱逐舰',
      fuel: 30,
      ammo: 30,
      steel: 30,
      bauxite: 30,
      developmentMaterial: 1,
      secretaryName: '矢矧改二乙',
    );

    expect((await database.getPendingConstructionRecordForDock(2))?['id'], id);

    await database.updateConstructionResult(
      recordId: id,
      dockId: 2,
      shipId: 1,
      shipName: '雪风',
      shipType: '驱逐舰',
    );
    expect((await database.getPendingConstructionRecordForDock(2))?['id'], id);

    await database.updateConstructionResult(
      recordId: id,
      dockId: 2,
      shipId: 1,
      shipName: '雪风',
      shipType: '驱逐舰',
      markCollected: true,
    );

    expect(await database.getPendingConstructionRecordForDock(2), isNull);
  });

  test('expedition records retain two reward items', () async {
    final database = await LogbookDatabase.openForTesting();
    addTearDown(database.close);

    await database.insertExpeditionResult(
      expeditionId: 38,
      name: '东京急行（弐）',
      result: 2,
      materials: const [0, 0, 300, 420],
      item1Id: 1,
      item1Name: '高速修复材',
      item1Count: 1,
      item2Id: 10,
      item2Name: '家具箱（小）',
      item2Count: 1,
    );

    final rows = await database.getExpeditionRecords();
    expect(rows.single['item1_name'], '高速修复材');
    expect(rows.single['item2_name'], '家具箱（小）');
  });

  test('battle records retain the resolved node status label', () async {
    final database = await LogbookDatabase.openForTesting();
    addTearDown(database.close);

    await database.insertBattleRecord(
      BattleRecord(
        battle: const LiveBattle(
          context: BattleContext(
            mapAreaId: 1,
            mapInfoNo: 1,
            node: 3,
            eventId: 4,
            eventKind: 4,
          ),
          friendMain: [
            BattleShipSnapshot(
              masterId: 1,
              name: '矢矧改二乙',
              side: BattleSide.friend,
              fleetRole: BattleFleetRole.main,
              position: 0,
              initialHp: 54,
              maxHp: 54,
              currentHp: 54,
            ),
            BattleShipSnapshot(
              masterId: 2,
              name: '雪风改二',
              side: BattleSide.friend,
              fleetRole: BattleFleetRole.main,
              position: 1,
              initialHp: 35,
              maxHp: 35,
              currentHp: 35,
            ),
          ],
          friendEscort: [
            BattleShipSnapshot(
              masterId: 3,
              name: '能代改二',
              side: BattleSide.friend,
              fleetRole: BattleFleetRole.escort,
              position: 0,
              initialHp: 53,
              maxHp: 53,
              currentHp: 53,
            ),
          ],
          mvpPositions: [1, 6],
        ),
        completedAt: DateTime(2026, 8, 11, 22, 10),
      ),
      mapDifficulty: 3,
      mapName: '南沙諸島沖/オルモック沖/サンベルナルジノ海峡沖',
      nodeLabel: 'Y',
    );

    final rows = await database.getBattleRecords();
    expect(rows.single['node_type'], '空袭战');
    expect(rows.single['flagship_name'], '矢矧改二乙');
    expect(rows.single['escort_flagship_name'], '能代改二');
    expect(rows.single['mvp_name'], '雪风改二');
    expect(rows.single['escort_mvp_name'], '能代改二');
    expect(rows.single['map_difficulty'], 3);
    expect(rows.single['map_name'], '南沙諸島沖/オルモック沖/サンベルナルジノ海峡沖');
    expect(rows.single['node_label'], 'Y');
  });

  test('practice battle records store standardized values', () async {
    final database = await LogbookDatabase.openForTesting();
    addTearDown(database.close);

    await database.insertBattleRecord(
      BattleRecord(
        battle: const LiveBattle(
          context: BattleContext(practice: true),
          friendMain: [
            BattleShipSnapshot(
              masterId: 1,
              name: '矢矧改二乙',
              side: BattleSide.friend,
              fleetRole: BattleFleetRole.main,
              position: 0,
              initialHp: 54,
              maxHp: 54,
              currentHp: 54,
            ),
          ],
          enemyFleetName: '演习对手舰队',
          rank: BattleRank.s,
          mvpPositions: [0],
        ),
        completedAt: DateTime(2026, 8, 19, 22, 30),
      ),
    );

    final rows = await database.getBattleRecords();
    expect(rows.single['map_area'], 0);
    expect(rows.single['map_no'], 0);
    expect(rows.single['map_name'], '演习');
    expect(rows.single['node'], 0);
    expect(rows.single['node_label'], '-');
    expect(rows.single['node_type'], '普通战斗');
    expect(rows.single['enemy_fleet_name'], '-');
    expect(rows.single['flagship_name'], '矢矧改二乙');
    expect(rows.single['escort_flagship_name'], '-');
    expect(rows.single['mvp_name'], '矢矧改二乙');
    expect(rows.single['escort_mvp_name'], '-');
    expect(rows.single['rank'], 's');
  });

  test(
    'sortie records retain battle rewards and merge map resource events',
    () async {
      final database = await LogbookDatabase.openForTesting();
      addTearDown(database.close);
      final battleTime = DateTime.utc(2026, 8, 24, 12);
      await database.insertBattleRecord(
        BattleRecord(
          battle: const LiveBattle(
            context: BattleContext(mapAreaId: 2, mapInfoNo: 2, node: 5),
            rank: BattleRank.s,
            dropShipMasterId: 101,
            dropShipMasterIds: <int>[101, 102],
            rewardItems: <BattleRewardItem>[
              BattleRewardItem(
                kind: BattleRewardKind.item,
                id: 68,
                count: 1,
                name: '秋刀鱼',
              ),
              BattleRewardItem(
                kind: BattleRewardKind.item,
                id: 57,
                count: 2,
                name: '勋章',
              ),
            ],
          ),
          completedAt: battleTime,
        ),
        mapName: '巴士岛近海',
        nodeLabel: 'E',
      );
      await database.insertMapResourceRecord(
        MapResourceLogEntry(
          eventKey: 'sequence:9001',
          timestamp: battleTime.add(const Duration(minutes: 1)),
          mapArea: 2,
          mapNo: 2,
          mapName: '巴士岛近海',
          node: 6,
          nodeLabel: 'F',
          fuelDelta: 80,
          ammoDelta: -30,
          rewardItems: const <BattleRewardItem>[
            BattleRewardItem(
              kind: BattleRewardKind.item,
              id: 11,
              count: 1,
              name: '家具箱（中）',
            ),
          ],
        ),
      );

      final rows = await database.getSortieRecords();
      expect(rows, hasLength(2));
      expect(rows.first['record_type'], 'resource');
      expect(rows.first['fuel_delta'], 80);
      expect(rows.first['ammo_delta'], -30);
      expect(rows.first['node_label'], 'F');
      expect(rows.first['reward_items_json'], contains('家具箱（中）'));
      expect(rows.last['record_type'], 'battle');
      expect(rows.last['drop_ship_ids_json'], '[101,102]');
      expect(rows.last['reward_items_json'], contains('秋刀鱼'));
      expect(rows.last['reward_items_json'], contains('勋章'));
    },
  );

  test('map resource event keys are idempotent', () async {
    final database = await LogbookDatabase.openForTesting();
    addTearDown(database.close);
    final entry = MapResourceLogEntry(
      eventKey: 'sequence:9002',
      timestamp: DateTime.utc(2026, 8, 24, 13),
      mapArea: 3,
      mapNo: 2,
      mapName: '基斯岛沖',
      node: 4,
      ammoDelta: -24,
      radarReduced: true,
    );

    await database.insertMapResourceRecord(entry);
    await database.insertMapResourceRecord(entry);

    final rows = await database.getSortieRecords();
    expect(rows, hasLength(1));
    expect(rows.single['radar_reduced'], 1);
  });

  test('upgrades v8 without losing existing battle records', () async {
    sqfliteFfiInit();
    final directory = await Directory.systemTemp.createTemp(
      'yahagi-logbook-v8-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final path = '${directory.path}${Platform.pathSeparator}logbook.db';
    final oldDatabase = await databaseFactoryFfiNoIsolate.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 8,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE battle_logs (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              timestamp INTEGER NOT NULL,
              map_area INTEGER NOT NULL,
              map_no INTEGER NOT NULL,
              map_name TEXT NOT NULL DEFAULT '',
              node INTEGER NOT NULL,
              node_label TEXT NOT NULL DEFAULT '',
              node_type INTEGER NOT NULL,
              map_difficulty INTEGER NOT NULL DEFAULT 0,
              rank TEXT NOT NULL,
              drop_ship_id INTEGER,
              enemy_fleet_name TEXT NOT NULL,
              friend_fleet_state TEXT NOT NULL,
              enemy_fleet_state TEXT NOT NULL,
              flagship_name TEXT NOT NULL DEFAULT '—',
              escort_flagship_name TEXT NOT NULL DEFAULT '—',
              mvp_name TEXT NOT NULL DEFAULT '—',
              escort_mvp_name TEXT NOT NULL DEFAULT '—'
            )
          ''');
        },
      ),
    );
    await oldDatabase.insert('battle_logs', <String, Object?>{
      'timestamp': 1,
      'map_area': 1,
      'map_no': 1,
      'node': 1,
      'node_type': '普通战斗',
      'rank': 's',
      'enemy_fleet_name': '旧记录',
      'friend_fleet_state': '6/6',
      'enemy_fleet_state': '0/6',
    });
    await oldDatabase.close();

    final upgraded = await LogbookDatabase.openForTesting(path: path);
    addTearDown(upgraded.close);
    final rows = await upgraded.getSortieRecords();
    final raw = await upgraded.database;
    final tables = await raw.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    );

    expect(rows.single['enemy_fleet_name'], '旧记录');
    expect(rows.single['reward_items_json'], '[]');
    expect(tables.map((row) => row['name']), contains('map_resource_logs'));
  });
}

GameState _resourceState(int fuel) => GameState(
  resources: <GameResourceType, int>{
    GameResourceType.fuel: fuel,
    GameResourceType.ammunition: 200,
    GameResourceType.steel: 300,
    GameResourceType.bauxite: 400,
    GameResourceType.instantRepair: 10,
    GameResourceType.instantBuild: 20,
    GameResourceType.developmentMaterial: 30,
    GameResourceType.improvementMaterial: 40,
  },
);
