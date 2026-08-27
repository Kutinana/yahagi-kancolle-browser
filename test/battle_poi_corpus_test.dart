import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_models.dart';
import 'package:yahagi_kancolle_browser/src/battle/prediction/battle_prediction_engine.dart';
import 'package:yahagi_kancolle_browser/src/battle/prediction/poi/poi_battle_prediction_engine.dart';
import 'package:yahagi_kancolle_browser/src/battle/prediction/yahagi_battle_prediction_engine.dart';

Map<String, Object?> _map(Object? value) => value is Map
    ? value.map((key, child) => MapEntry(key.toString(), child))
    : const <String, Object?>{};

List<Object?> _list(Object? value) =>
    value is List ? List<Object?>.from(value) : const <Object?>[];

int _int(Object? value) => value is num ? value.toInt() : 0;

Map<String, Object?> _loadUpstreamPoiOracle(Directory fixtureRoot) {
  final sourceRoot = fixtureRoot.parent.parent.parent;
  final entry = File('${sourceRoot.path}${Platform.pathSeparator}index.js');
  if (!entry.existsSync()) {
    markTestSkipped('Build poi-lib-battle first with npm run build.');
    return const <String, Object?>{};
  }
  const script = r'''
const fs=require('fs'),path=require('path'),lib=require(process.argv[1]);
const root=process.argv[2], out={};
const isBattle=p=>!p.poi_path.endsWith('battleresult')&&
  !p.poi_path.endsWith('battle_result')&&
  (p.poi_path.includes('battle')||p.poi_path.includes('ld_shooting'));
function walk(dir){for(const e of fs.readdirSync(dir,{withFileTypes:true})){
  const p=path.join(dir,e.name); if(e.isDirectory()) walk(p); else if(p.endsWith('.json')){
    const j=JSON.parse(fs.readFileSync(p,'utf8'));
    const hp=x=>(x||[]).filter(Boolean).map(v=>v.nowHP);
    const packets=[],steps=[];
    for(const packet of j.packet){
      if(!isBattle(packet)) continue;
      packets.push(packet);
      const prediction={...j,packet:[...packets]};
      const s=lib.Simulator.auto(new lib.Battle(prediction),{usePoiAPI:false});
      steps.push({path:packet.poi_path,
        friend:[...hp(s.mainFleet),...hp(s.escortFleet)],
        enemy:[...hp(s.enemyFleet),...hp(s.enemyEscort)],
        rank:s.result.rank,mvp:s.result.mvp});
    }
    out[path.relative(root,p).replaceAll('\\','/')]={steps};
  }
}}
walk(root); process.stdout.write(JSON.stringify(out));
''';
  final result = Process.runSync('node', <String>[
    '-e',
    script,
    entry.path,
    fixtureRoot.path,
  ]);
  expect(result.exitCode, 0, reason: result.stderr.toString());
  return _map(jsonDecode(result.stdout.toString()));
}

List<int> _reportedMvp(BattlePrediction prediction) {
  if (prediction.friendEscort.isEmpty) {
    return <int>[
      prediction.mvpPositions.isEmpty ? -1 : prediction.mvpPositions.first,
      -1,
    ];
  }
  var main = -1;
  var escort = -1;
  for (final position in prediction.mvpPositions) {
    if (position >= 6) {
      escort = position - 6;
    } else if (main < 0) {
      main = position;
    }
  }
  return <int>[main, escort];
}

List<BattleShipSnapshot> _friendFleet(Object? value, BattleFleetRole role) {
  final ships = _list(value);
  return <BattleShipSnapshot>[
    for (var position = 0; position < ships.length; position++)
      if (_map(ships[position]) case final ship when ship.isNotEmpty)
        BattleShipSnapshot(
          masterId: _int(ship['api_ship_id']),
          ownedShipId: _int(ship['api_id']),
          name: 'friend-${ship['api_ship_id']}',
          side: BattleSide.friend,
          fleetRole: role,
          position: position,
          initialHp: _int(ship['api_nowhp']),
          maxHp: _int(ship['api_maxhp']),
          currentHp: _int(ship['api_nowhp']),
          equipmentMasterIds: <int>[
            for (final raw in _list(ship['poi_slot']))
              if (_int(_map(raw)['api_slotitem_id']) > 0)
                _int(_map(raw)['api_slotitem_id']),
            if (_int(_map(ship['poi_slot_ex'])['api_slotitem_id']) > 0)
              _int(_map(ship['poi_slot_ex'])['api_slotitem_id']),
          ],
        ),
  ];
}

List<BattleShipSnapshot> _enemyFleet(
  Map<String, Object?> packet,
  String idsKey,
  String hpKey,
  String maxHpKey,
  BattleFleetRole role,
) {
  final ids = _list(packet[idsKey]);
  final hp = _list(packet[hpKey]);
  final maxHp = _list(packet[maxHpKey]);
  return <BattleShipSnapshot>[
    for (var position = 0; position < ids.length; position++)
      if (_int(ids[position]) > 0)
        BattleShipSnapshot(
          masterId: _int(ids[position]),
          name: 'enemy-${ids[position]}',
          side: BattleSide.enemy,
          fleetRole: role,
          position: position,
          initialHp: position < hp.length ? _int(hp[position]) : 0,
          maxHp: position < maxHp.length ? _int(maxHp[position]) : 0,
          currentHp: position < hp.length ? _int(hp[position]) : 0,
        ),
  ];
}

void main() {
  test('poi 304-fixture corpus matches authoritative sink results', () {
    final rootPath = Platform.environment['YAHAGI_POI_BATTLE_FIXTURES'];
    if (rootPath == null || rootPath.isEmpty) {
      markTestSkipped(
        'Set YAHAGI_POI_BATTLE_FIXTURES to poi-lib-battle fixtures.',
      );
      return;
    }
    final root = Directory(rootPath);
    final files =
        root
            .listSync(recursive: true)
            .whereType<File>()
            .where((file) => file.path.endsWith('.json'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    expect(files, hasLength(304));
    final upstream = _loadUpstreamPoiOracle(root);
    expect(upstream, hasLength(304));
    var comparedPackets = 0;
    var friendlyInfoPackets = 0;
    var friendlyBattlePackets = 0;
    var friendlyKoukuPackets = 0;
    var combinedBattles = 0;
    var nightToDayPackets = 0;
    var supportPackets = 0;
    var damageControlBattles = 0;
    var sevenShipBattles = 0;

    for (final file in files) {
      final battle = _map(jsonDecode(file.readAsStringSync()));
      final fleet = _map(battle['fleet']);
      var friendMain = _friendFleet(fleet['main'], BattleFleetRole.main);
      var friendEscort = _friendFleet(fleet['escort'], BattleFleetRole.escort);
      var enemyMain = <BattleShipSnapshot>[];
      var enemyEscort = <BattleShipSnapshot>[];
      Map<String, Object?>? resultPacket;
      PoiBattlePredictionEngine? engine;
      YahagiBattlePredictionEngine? yahagiEngine;
      BattlePrediction? yahagiPrediction;
      BattleRank predictedRank = BattleRank.unknown;
      final relative = file.path
          .substring(root.path.length + 1)
          .replaceAll('\\', '/');
      final oracle = _map(upstream[relative]);
      final oracleSteps = _list(oracle['steps']);
      var oracleStep = 0;
      final fleetType = _int(fleet['type']);
      if (fleetType > 0) combinedBattles++;
      if (_list(fleet['main']).length == 7) sevenShipBattles++;
      if (<BattleShipSnapshot>[...friendMain, ...friendEscort].any(
        (ship) =>
            ship.equipmentMasterIds.any((item) => item == 42 || item == 43),
      )) {
        damageControlBattles++;
      }

      for (final rawPacket in _list(battle['packet'])) {
        final packet = _map(rawPacket);
        final path = packet['poi_path']?.toString() ?? '';
        if (path.endsWith('battleresult') || path.endsWith('battle_result')) {
          resultPacket = packet;
          continue;
        }
        if (!path.contains('battle') && !path.contains('ld_shooting')) continue;
        if (packet['api_friendly_info'] != null) friendlyInfoPackets++;
        if (packet['api_friendly_battle'] != null) friendlyBattlePackets++;
        if (packet['api_friendly_kouku'] != null) friendlyKoukuPackets++;
        if (path.contains('night_to_day')) nightToDayPackets++;
        if (_int(packet['api_support_flag']) > 0 ||
            _int(packet['api_n_support_flag']) > 0) {
          supportPackets++;
        }
        if (enemyMain.isEmpty) {
          enemyMain = _enemyFleet(
            packet,
            'api_ship_ke',
            'api_e_nowhps',
            'api_e_maxhps',
            BattleFleetRole.main,
          );
          enemyEscort = _enemyFleet(
            packet,
            'api_ship_ke_combined',
            'api_e_nowhps_combined',
            'api_e_maxhps_combined',
            BattleFleetRole.escort,
          );
        }
        engine ??= PoiBattlePredictionEngine(
          friendMain: friendMain,
          friendEscort: friendEscort,
          enemyMain: enemyMain,
          enemyEscort: enemyEscort,
          fleetType: fleetType,
        );
        yahagiEngine ??= YahagiBattlePredictionEngine(
          friendMain: friendMain,
          friendEscort: friendEscort,
          enemyMain: enemyMain,
          enemyEscort: enemyEscort,
        );
        final parsed = engine.append(path: path, data: packet);
        yahagiPrediction = yahagiEngine.append(path: path, data: packet);
        friendMain = parsed.friendMain;
        friendEscort = parsed.friendEscort;
        enemyMain = parsed.enemyMain;
        enemyEscort = parsed.enemyEscort;
        predictedRank = parsed.rank;
        final oraclePacket = _map(oracleSteps[oracleStep]);
        expect(oraclePacket['path'], path, reason: file.path);
        expect(
          <int>[
            ...parsed.friendMain.map((ship) => ship.currentHp),
            ...parsed.friendEscort.map((ship) => ship.currentHp),
          ],
          _list(oraclePacket['friend']).map(_int).toList(),
          reason: '${file.path} packet $oracleStep friend HP differs from POI',
        );
        expect(
          <int>[
            ...parsed.enemyMain.map((ship) => ship.currentHp),
            ...parsed.enemyEscort.map((ship) => ship.currentHp),
          ],
          _list(oraclePacket['enemy']).map(_int).toList(),
          reason: '${file.path} packet $oracleStep enemy HP differs from POI',
        );
        expect(
          parsed.rank.name.toUpperCase(),
          oraclePacket['rank'],
          reason: '${file.path} packet $oracleStep rank differs from POI',
        );
        expect(
          _reportedMvp(parsed),
          _list(oraclePacket['mvp']).map(_int).toList(),
          reason: '${file.path} packet $oracleStep MVP differs from POI',
        );
        oracleStep++;
        comparedPackets++;
      }
      expect(oracleStep, oracleSteps.length, reason: file.path);

      for (final ship in <BattleShipSnapshot>[
        ...friendMain,
        ...friendEscort,
        ...enemyMain,
        ...enemyEscort,
      ]) {
        expect(
          ship.currentHp,
          inInclusiveRange(0, ship.maxHp),
          reason: file.path,
        );
      }
      if (resultPacket case final result?) {
        final friendShips = <BattleShipSnapshot>[
          ...friendMain,
          ...friendEscort,
        ];
        final enemyShips = <BattleShipSnapshot>[...enemyMain, ...enemyEscort];
        var officialRank = BattleRank.parse(result['api_win_rank']);
        if (officialRank == BattleRank.s && friendShips.isNotEmpty) {
          final initialHp = friendShips.fold<int>(
            0,
            (sum, ship) => sum + ship.initialHp,
          );
          final currentHp = friendShips.fold<int>(
            0,
            (sum, ship) => sum + ship.currentHp,
          );
          if (currentHp >= initialHp) officialRank = BattleRank.ss;
        }
        expect(
          predictedRank,
          officialRank,
          reason:
              '${file.path} friend=${friendShips.map((ship) => '${ship.initialHp}/${ship.currentHp}').join(',')}',
        );
        final yahagi = yahagiPrediction!;
        expect(
          <int>[
            ...yahagi.friendMain.map((ship) => ship.currentHp),
            ...yahagi.friendEscort.map((ship) => ship.currentHp),
            ...yahagi.enemyMain.map((ship) => ship.currentHp),
            ...yahagi.enemyEscort.map((ship) => ship.currentHp),
          ],
          <int>[
            ...friendMain.map((ship) => ship.currentHp),
            ...friendEscort.map((ship) => ship.currentHp),
            ...enemyMain.map((ship) => ship.currentHp),
            ...enemyEscort.map((ship) => ship.currentHp),
          ],
          reason: '${file.path} final HP differs between engines',
        );
        expect(yahagi.rank, predictedRank, reason: '${file.path} rank differs');
        final allEnemyHpKnown =
            enemyShips.isNotEmpty &&
            enemyShips.every((ship) => !ship.hpUnknown && ship.maxHp > 0);
        final sunk = enemyShips.where((ship) => ship.isSunk).length;
        if (allEnemyHpKnown && result['api_dests'] is num) {
          expect(
            sunk,
            _int(result['api_dests']),
            reason:
                '${file.path} enemy=${enemyShips.map((ship) => '${ship.fleetRole.name}:${ship.position}:${ship.currentHp}').join(',')}',
          );
        }
        if (allEnemyHpKnown &&
            result['api_destsf'] is num &&
            enemyMain.isNotEmpty) {
          expect(
            enemyMain.first.isSunk ? 1 : 0,
            _int(result['api_destsf']),
            reason: file.path,
          );
        }
      }
    }
    expect(comparedPackets, greaterThan(304));
    // ignore: avoid_print
    print(
      'POI corpus coverage: files=${files.length}, packets=$comparedPackets, '
      'combined=$combinedBattles, friendlyInfo=$friendlyInfoPackets, '
      'friendlyBattle=$friendlyBattlePackets, friendlyKouku=$friendlyKoukuPackets, '
      'nightToDay=$nightToDayPackets, support=$supportPackets, '
      'damageControl=$damageControlBattles, sevenShip=$sevenShipBattles',
    );
  });
}
