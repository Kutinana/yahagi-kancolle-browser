// Synthetic inputs use the same model as captured production battles.
// ignore: implementation_imports
import 'package:yahagi_kancolle_browser/src/battle/battle_detail_models.dart';

// Synthetic UI examples only. Never written to Yahagi's logbook.
BattleDetailSnapshot sampleBattle(bool combined) {
  final ships = <String, _Ship>{};
  void ship(
    String id,
    String name,
    int hp, {
    int maxHp = 0,
    int level = 98,
    List<String> equipment = const [],
  }) {
    final side = id.startsWith('e')
        ? BattleDetailSide.enemy
        : id.startsWith('n')
        ? BattleDetailSide.npc
        : BattleDetailSide.friend;
    ships[id] = _Ship(
      name,
      hp,
      maxHp == 0 ? hp : maxHp,
      side,
      id.contains('s')
          ? BattleDetailFleetRole.escort
          : BattleDetailFleetRole.main,
      int.parse(id.substring(2)),
      level,
      equipment,
    );
  }

  final stages = <BattleDetailStage>[];
  BattleDetailAttack attack(
    String from,
    String to,
    List<int> damage, {
    String type = '炮击',
    bool critical = false,
    bool repair = false,
  }) {
    final source = ships[from]!;
    final target = ships[to]!;
    final before = target.hp;
    final hits = <BattleDetailHit>[];
    for (var i = 0; i < damage.length; i++) {
      target.hp = (target.hp - damage[i]).clamp(0, target.maxHp);
      if (repair && i == damage.length - 1 && target.hp == 0) {
        target.hp = target.maxHp;
      }
      hits.add(
        BattleDetailHit(
          damage: damage[i],
          hpAfter: target.hp,
          kind: damage[i] == 0
              ? BattleDetailHitKind.miss
              : critical
              ? BattleDetailHitKind.critical
              : BattleDetailHitKind.hit,
        ),
      );
      source.dealt += damage[i];
      target.received += damage[i];
    }
    return BattleDetailAttack(
      attackerSide: source.side,
      attackerName: source.name,
      attackerRole: source.role,
      attackerPosition: source.position,
      defenderSide: target.side,
      defenderName: target.name,
      defenderRole: target.role,
      defenderPosition: target.position,
      attackType: type,
      defenderHpBefore: before,
      defenderHpAfter: target.hp,
      hits: hits,
      damageControlName: repair ? '应急修理女神' : null,
    );
  }

  void stage(String key, String name, List<BattleDetailAttack> attacks) =>
      stages.add(
        BattleDetailStage(keyName: key, title: name, attacks: attacks),
      );

  if (!combined) {
    ship(
      'fm0',
      '北上改二',
      49,
      level: 104,
      equipment: ['15.5cm三连装副炮', '15.5cm三连装副炮', '甲标的 丙型 ★4'],
    );
    ship('em0', '轻巡ホ级', 33);
    ship('em1', '驱逐イ级', 20);
    ship('em2', '驱逐イ级', 20);
    stage('opening', '开幕雷击', [
      attack('fm0', 'em0', [67], type: '开幕雷击', critical: true),
    ]);
    stage('shelling', '第一炮击战', [
      attack('fm0', 'em1', [152], critical: true),
      attack('em2', 'fm0', [0]),
    ]);
    stage('torpedo', '闭幕雷击', [
      attack('fm0', 'em2', [152], type: '雷击', critical: true),
    ]);
  } else {
    ship(
      'fm0',
      '大和改二重',
      98,
      level: 135,
      equipment: ['51cm连装炮 ★6', '15m二重测距仪', '零式水上侦察机'],
    );
    ship('fm1', '武藏改二', 99, level: 128, equipment: ['46cm三连装炮', '一式彻甲弹']);
    ship('fm2', '赤城改二', 81, level: 117, equipment: ['流星改', '烈风']);
    ship('fm3', '加贺改二', 84, level: 115, equipment: ['彗星', '烈风']);
    ship('fs0', '矢矧改二乙', 53, level: 112, equipment: ['15.2cm连装炮改二', '甲标的']);
    ship('fs1', '北上改二', 49, level: 104, equipment: ['15.5cm三连装副炮', '甲标的']);
    ship('fs2', '雪风改二', 32, level: 108, equipment: ['五连装酸素鱼雷', '应急修理女神']);
    ship('fs3', '时雨改三', 31, level: 110, equipment: ['四式水中听音机', '三式爆雷']);
    ship('em0', '战舰ル级旗舰', 160);
    ship('em1', '空母ヲ级旗舰', 120);
    ship('em2', '重巡リ级旗舰', 88);
    ship('em3', '驱逐ハ级后期型', 38);
    ship('es0', '轻巡ヘ级旗舰', 66);
    ship('es1', '驱逐イ级后期型', 40);
    ship('es2', '驱逐ロ级后期型', 40);
    ship('es3', '潜水カ级精英', 27);
    ship('nm0', '友军·夕立改二', 30);
    stage('air', '航空战', [
      attack('fm2', 'em1', [24], type: '航空攻击'),
      attack('fm3', 'em3', [42], type: '航空攻击', critical: true),
      attack('em1', 'fm3', [22], type: '航空攻击'),
    ]);
    stage('asw', '先制反潜', [
      attack('fs3', 'es3', [35], type: '反潜攻击'),
    ]);
    stage('opening', '开幕雷击', [
      attack('fs1', 'em2', [35], type: '开幕雷击'),
      attack('fs0', 'es0', [18], type: '开幕雷击'),
      attack('es0', 'fs1', [12], type: '开幕雷击'),
    ]);
    stage('shelling', '第一炮击战', [
      attack('fm0', 'em0', [60, 60], type: '主炮连击', critical: true),
      attack('em0', 'fm1', [55]),
      attack('fm1', 'em0', [68]),
      attack('fm2', 'em1', [40], type: '航空炮击'),
      attack('em1', 'fm2', [64], type: '航空炮击'),
      attack('fm3', 'em2', [62], type: '航空炮击'),
      attack('es2', 'fs3', [0]),
    ]);
    stage('torpedo', '闭幕雷击', [
      attack('es1', 'fs2', [40], type: '雷击', critical: true, repair: true),
      attack('fs2', 'es1', [44], type: '雷击'),
      attack('fs3', 'es2', [0], type: '雷击'),
    ]);
    stage('npc', '友军支援', [
      attack('nm0', 'es0', [20], type: '友军炮击'),
      attack('es0', 'nm0', [10], type: '敌方反击'),
    ]);
    stage('night', '夜战', [
      attack('fs0', 'es0', [18, 25], type: '主炮连击'),
      attack('fs1', 'em1', [42, 32], type: '鱼雷截击', critical: true),
      attack('es2', 'fs3', [8], type: '夜战炮击'),
      attack('fs2', 'es2', [23, 26], type: '鱼雷截击', critical: true),
    ]);
  }
  return BattleDetailSnapshot(
    completedAtMillis: DateTime(2026, 9, 5, 6, 11).millisecondsSinceEpoch,
    mapLabel: combined ? '6-5' : '1-1',
    nodeLabel: combined ? 'M点' : 'C点',
    rank: combined ? 'S' : 'SS',
    enemyFleetName: combined ? '敌联合舰队' : '敌主力舰队',
    fleets: [
      for (final side in [BattleDetailSide.friend, BattleDetailSide.enemy])
        for (final role in BattleDetailFleetRole.values)
          BattleDetailFleet(
            side: side,
            role: role,
            ships: [
              for (final s in ships.values)
                if (s.side == side && s.role == role) s.snapshot(),
            ],
          ),
    ],
    stages: stages,
  );
}

class _Ship {
  _Ship(
    this.name,
    this.hp,
    this.maxHp,
    this.side,
    this.role,
    this.position,
    this.level,
    this.equipment,
  ) : initial = hp;
  final String name;
  int hp;
  final int initial;
  final int maxHp;
  final BattleDetailSide side;
  final BattleDetailFleetRole role;
  final int position;
  final int level;
  final List<String> equipment;
  int dealt = 0;
  int received = 0;
  BattleDetailShip snapshot() => BattleDetailShip(
    name: name,
    side: side,
    role: role,
    position: position,
    initialHp: initial,
    maxHp: maxHp,
    finalHp: hp,
    damageDealt: dealt,
    damageReceived: received,
    level: side == BattleDetailSide.friend ? level : null,
    equipment: [
      for (final name in equipment)
        BattleDetailEquipment(masterId: 0, name: name),
    ],
  );
}
