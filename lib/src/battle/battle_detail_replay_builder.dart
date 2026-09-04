import '../game_state/game_state.dart';
import 'battle_detail_models.dart';
import 'battle_models.dart';
import 'battle_session.dart';

/// Converts the packets retained for one battle into a stable, display-only
/// snapshot. Parsing is deliberately independent from the live predictor so a
/// detail failure can never change the battle result shown to the player.
final class BattleDetailReplayBuilder {
  const BattleDetailReplayBuilder();

  BattleDetailSnapshot build({
    required BattleSession session,
    required LiveBattle battle,
    required DateTime completedAt,
    required GameState gameState,
  }) {
    final state = _ReplayState(battle);
    final stages = <BattleDetailStage>[];
    for (final packet in session.packets) {
      if (_isResultPath(packet.path)) continue;
      stages.addAll(_parsePacket(packet.path, packet.data, state));
    }
    return BattleDetailSnapshot(
      completedAtMillis: completedAt.millisecondsSinceEpoch,
      mapLabel: battle.context.mapLabel,
      nodeLabel: battle.context.nodeLabel,
      rank: battle.rank.label,
      enemyFleetName: battleEnemyFleetDisplayName(battle.enemyFleetName),
      fleets: List<BattleDetailFleet>.unmodifiable(<BattleDetailFleet>[
        _fleet(battle.friendMain, gameState),
        _fleet(battle.friendEscort, gameState),
        _fleet(battle.enemyMain, gameState),
        _fleet(battle.enemyEscort, gameState),
      ]),
      stages: List<BattleDetailStage>.unmodifiable(stages),
    );
  }

  bool _isResultPath(String path) =>
      path.contains('battleresult') || path.contains('battle_result');

  BattleDetailFleet _fleet(
    List<BattleShipSnapshot> ships,
    GameState gameState,
  ) {
    final first = ships.firstOrNull;
    final side = first?.side == BattleSide.enemy
        ? BattleDetailSide.enemy
        : BattleDetailSide.friend;
    final role = first?.fleetRole == BattleFleetRole.escort
        ? BattleDetailFleetRole.escort
        : BattleDetailFleetRole.main;
    return BattleDetailFleet(
      side: side,
      role: role,
      ships: List<BattleDetailShip>.unmodifiable(
        ships.map((ship) => _ship(ship, gameState)),
      ),
    );
  }

  BattleDetailShip _ship(BattleShipSnapshot ship, GameState gameState) {
    final owned = ship.ownedShipId == null
        ? null
        : gameState.ships[ship.ownedShipId];
    final ownedEquipment = owned == null
        ? const <ShipEquipment>[]
        : gameState.equipmentForShip(owned);
    final equipment = ownedEquipment.isNotEmpty
        ? <BattleDetailEquipment>[
            for (final item in ownedEquipment)
              BattleDetailEquipment(
                masterId: item.owned.masterSlotItemId,
                name: item.master?.name ?? '装备 ${item.owned.masterSlotItemId}',
                improvement: item.owned.level,
                proficiency: item.owned.proficiency,
              ),
          ]
        : <BattleDetailEquipment>[
            for (final id in ship.equipmentMasterIds.where((id) => id > 0))
              BattleDetailEquipment(
                masterId: id,
                name: gameState.masterSlotItems[id]?.name ?? '装备 $id',
              ),
          ];
    return BattleDetailShip(
      masterId: ship.masterId,
      name: ship.name,
      side: _side(ship.side),
      role: _role(ship.fleetRole),
      position: ship.position,
      level: owned?.level,
      initialHp: ship.initialHp,
      maxHp: ship.maxHp,
      finalHp: ship.currentHp,
      damageDealt: ship.damageDealt,
      damageReceived: ship.damageReceived,
      equipment: List<BattleDetailEquipment>.unmodifiable(equipment),
      escaped: ship.isEscaped,
    );
  }

  List<BattleDetailStage> _parsePacket(
    String path,
    Map<String, Object?> data,
    _ReplayState state,
  ) {
    final stages = <BattleDetailStage>[];

    void aerial(Object? raw, String key, String title) {
      _appendStage(stages, key, title, _parseAerial(raw, title, state));
    }

    void shell(String key, String title, {bool night = false}) {
      _appendStage(
        stages,
        key,
        title,
        _parseShell(data[key], title, state, night: night),
      );
    }

    void torpedo(String key, String title) {
      _appendStage(
        stages,
        key,
        title,
        _parseDamageArrays(data[key], title, state),
      );
    }

    final nightOnly = _nightPath(path);
    final nightToDay = path.contains('night_to_day');
    if (nightOnly || nightToDay) {
      _appendStage(
        stages,
        'api_n_support_info',
        '夜战支援',
        _parseSupport(data['api_n_support_info'], '夜战支援', state),
      );
      shell('api_n_hougeki1', '夜战第一轮', night: true);
      shell('api_n_hougeki2', '夜战第二轮', night: true);
      final friendly = _map(data['api_friendly_battle']);
      _appendStage(
        stages,
        'api_friendly_battle.api_hougeki',
        '友军舰队',
        _parseShell(
          friendly?['api_hougeki'],
          '友军舰队',
          state,
          night: true,
          attackerOverride: BattleDetailSide.friend,
        ),
      );
      shell('api_hougeki', '夜战', night: true);
      if (!nightToDay) return stages;
    }

    aerial(data['api_air_base_injection'], 'api_air_base_injection', '喷气强袭');
    aerial(data['api_injection_kouku'], 'api_injection_kouku', '喷气强袭');
    final bases = _list(data['api_air_base_attack']);
    for (var index = 0; index < bases.length; index++) {
      aerial(bases[index], 'api_air_base_attack[$index]', '基地航空队 ${index + 1}');
    }
    aerial(data['api_friendly_kouku'], 'api_friendly_kouku', '友军航空战');
    aerial(data['api_kouku'], 'api_kouku', '航空战');
    aerial(data['api_kouku2'], 'api_kouku2', '第二次航空战');
    if (data['api_stage3'] is Map || data['api_stage3_combined'] is Map) {
      aerial(data, 'packet-stage3', '航空战');
    }
    _appendStage(
      stages,
      'api_support_info',
      '支援攻击',
      _parseSupport(data['api_support_info'], '支援攻击', state),
    );
    _appendStage(
      stages,
      'api_opening_taisen',
      '开幕反潜',
      _parseShell(data['api_opening_taisen'], '开幕反潜', state),
    );
    torpedo('api_opening_atack', '开幕雷击');

    final enemyCombined = path.contains('/ec_') || path.contains('/each_');
    final water = path.contains('battle_water');
    if (!enemyCombined && !water) {
      shell('api_hougeki1', '第一炮击战');
      shell('api_hougeki2', '第二炮击战');
      torpedo('api_raigeki', '雷击战');
    } else if (water) {
      shell('api_hougeki1', '第一炮击战');
      shell('api_hougeki2', '第二炮击战');
      shell('api_hougeki3', '第三炮击战');
      torpedo('api_raigeki', '雷击战');
    } else {
      shell('api_hougeki1', '第一炮击战');
      torpedo('api_raigeki', '雷击战');
      shell('api_hougeki2', '第二炮击战');
      shell('api_hougeki3', '第三炮击战');
    }
    return stages;
  }

  bool _nightPath(String path) =>
      path.contains('midnight') || path.contains('sp_midnight');

  void _appendStage(
    List<BattleDetailStage> stages,
    String key,
    String title,
    List<BattleDetailAttack> attacks,
  ) {
    if (attacks.isEmpty) return;
    stages.add(
      BattleDetailStage(
        keyName: key,
        title: title,
        attacks: List<BattleDetailAttack>.unmodifiable(attacks),
      ),
    );
  }

  List<BattleDetailAttack> _parseShell(
    Object? raw,
    String title,
    _ReplayState state, {
    bool night = false,
    BattleDetailSide? attackerOverride,
  }) {
    final map = _map(raw);
    if (map == null) return const <BattleDetailAttack>[];
    final flags = _list(map['api_at_eflag']);
    final attackers = _list(map['api_at_list']);
    final defenders = _list(map['api_df_list']);
    final damages = _list(map['api_damage']);
    final criticals = _list(map['api_cl_list']);
    final types = _list(map[night ? 'api_sp_list' : 'api_at_type']);
    final result = <BattleDetailAttack>[];
    final rowCount = defenders.length < damages.length
        ? defenders.length
        : damages.length;
    for (var row = 0; row < rowCount; row++) {
      final attackerSide =
          attackerOverride ??
          (_atInt(flags, row) == 1
              ? BattleDetailSide.enemy
              : BattleDetailSide.friend);
      final defenderSide = attackerSide == BattleDetailSide.friend
          ? BattleDetailSide.enemy
          : BattleDetailSide.friend;
      final attacker = state.resolve(attackerSide, _atInt(attackers, row));
      final targets = _list(defenders[row]);
      final hits = _list(damages[row]);
      final cls = row < criticals.length
          ? _list(criticals[row])
          : const <Object?>[];
      final attackType = _attackTypeLabel(_atInt(types, row), night: night);
      final grouped = <int, List<int>>{};
      for (var hit = 0; hit < hits.length; hit++) {
        if (targets.isEmpty) continue;
        final target = _int(targets[hit < targets.length ? hit : 0]);
        grouped.putIfAbsent(target, () => <int>[]).add(hit);
      }
      for (final entry in grouped.entries) {
        final defender = state.resolve(defenderSide, entry.key);
        if (defender == null) continue;
        final before = defender.hp;
        String? damageControl;
        final detailHits = <BattleDetailHit>[];
        for (final hitIndex in entry.value) {
          final damage = _damage(hits[hitIndex]);
          final kind = _hitKind(_atInt(cls, hitIndex), damage);
          final control = state.damage(defender, damage);
          damageControl ??= control;
          detailHits.add(
            BattleDetailHit(damage: damage, kind: kind, hpAfter: defender.hp),
          );
        }
        result.add(
          _attack(
            attacker: attacker,
            attackerSide: attackerSide,
            attackerFallback: title,
            defender: defender,
            type: attackType,
            before: before,
            hits: detailHits,
            damageControl: damageControl,
          ),
        );
      }
    }
    return result;
  }

  List<BattleDetailAttack> _parseAerial(
    Object? raw,
    String title,
    _ReplayState state,
  ) {
    final map = _map(raw);
    if (map == null) return const <BattleDetailAttack>[];
    final result = <BattleDetailAttack>[];
    void parseStage3(Object? value, BattleDetailFleetRole role) {
      final stage3 = _map(value);
      if (stage3 == null) return;
      result.addAll(
        _parseIndexedDamage(
          stage3['api_edam'],
          stage3['api_ebak_flag'],
          stage3['api_erai_flag'],
          BattleDetailSide.enemy,
          role,
          title,
          state,
        ),
      );
      result.addAll(
        _parseIndexedDamage(
          stage3['api_fdam'],
          stage3['api_fbak_flag'],
          stage3['api_frai_flag'],
          BattleDetailSide.friend,
          role,
          '敌$title',
          state,
        ),
      );
    }

    parseStage3(map['api_stage3'], BattleDetailFleetRole.main);
    parseStage3(map['api_stage3_combined'], BattleDetailFleetRole.escort);
    return result;
  }

  List<BattleDetailAttack> _parseIndexedDamage(
    Object? rawDamage,
    Object? rawBombing,
    Object? rawTorpedo,
    BattleDetailSide defenderSide,
    BattleDetailFleetRole role,
    String source,
    _ReplayState state,
  ) {
    final damages = _withoutSentinel(_list(rawDamage));
    final bombing = _withoutSentinel(_list(rawBombing));
    final torpedo = _withoutSentinel(_list(rawTorpedo));
    final result = <BattleDetailAttack>[];
    for (var position = 0; position < damages.length; position++) {
      if (_atInt(bombing, position) <= 0 && _atInt(torpedo, position) <= 0) {
        continue;
      }
      final defender = state.resolveRole(defenderSide, role, position);
      if (defender == null) continue;
      result.add(
        _sourceAttack(source, defender, _damage(damages[position]), state),
      );
    }
    return result;
  }

  List<BattleDetailAttack> _parseDamageArrays(
    Object? raw,
    String title,
    _ReplayState state,
  ) {
    final map = _map(raw);
    if (map == null) return const <BattleDetailAttack>[];
    final result = <BattleDetailAttack>[];
    void add(Object? values, BattleDetailSide defenderSide) {
      final damage = _withoutSentinel(_list(values));
      for (var absolute = 0; absolute < damage.length; absolute++) {
        final amount = _damage(damage[absolute]);
        if (amount <= 0) continue;
        final defender = state.resolve(defenderSide, absolute);
        if (defender == null) continue;
        final source = defenderSide == BattleDetailSide.enemy
            ? title
            : '敌$title';
        result.add(_sourceAttack(source, defender, amount, state));
      }
    }

    add(map['api_edam'], BattleDetailSide.enemy);
    add(map['api_fdam'], BattleDetailSide.friend);
    return result;
  }

  List<BattleDetailAttack> _parseSupport(
    Object? raw,
    String title,
    _ReplayState state,
  ) {
    final map = _map(raw);
    if (map == null) return const <BattleDetailAttack>[];
    final air = _map(map['api_support_airatack']);
    if (air != null) return _parseAerial(air, title, state);
    final hourai = _map(map['api_support_hourai']);
    if (hourai == null) return const <BattleDetailAttack>[];
    final damage = _withoutSentinel(_list(hourai['api_damage']));
    final criticals = _withoutSentinel(_list(hourai['api_cl_list']));
    final result = <BattleDetailAttack>[];
    for (var position = 0; position < damage.length; position++) {
      final amount = _damage(damage[position]);
      if (amount <= 0 && _atInt(criticals, position) <= 0) continue;
      final defender = state.resolveRole(
        BattleDetailSide.enemy,
        BattleDetailFleetRole.main,
        position,
      );
      if (defender == null) continue;
      result.add(_sourceAttack(title, defender, amount, state));
    }
    return result;
  }

  BattleDetailAttack _sourceAttack(
    String source,
    _ReplayShip defender,
    int damage,
    _ReplayState state,
  ) {
    final before = defender.hp;
    final control = state.damage(defender, damage);
    final attackerSide = defender.side == BattleDetailSide.friend
        ? BattleDetailSide.enemy
        : BattleDetailSide.friend;
    return BattleDetailAttack(
      attackerSide: attackerSide,
      attackerName: source,
      defenderSide: defender.side,
      defenderRole: defender.role,
      defenderPosition: defender.position,
      defenderName: defender.name,
      attackType: source,
      defenderHpBefore: before,
      defenderHpAfter: defender.hp,
      hits: <BattleDetailHit>[
        BattleDetailHit(
          damage: damage,
          kind: damage <= 0
              ? BattleDetailHitKind.miss
              : BattleDetailHitKind.hit,
          hpAfter: defender.hp,
        ),
      ],
      damageControlName: control,
    );
  }

  BattleDetailAttack _attack({
    required _ReplayShip? attacker,
    required BattleDetailSide attackerSide,
    required String attackerFallback,
    required _ReplayShip defender,
    required String type,
    required int before,
    required List<BattleDetailHit> hits,
    required String? damageControl,
  }) => BattleDetailAttack(
    attackerSide: attackerSide,
    attackerRole: attacker?.role,
    attackerPosition: attacker?.position,
    attackerName: attacker?.name ?? attackerFallback,
    defenderSide: defender.side,
    defenderRole: defender.role,
    defenderPosition: defender.position,
    defenderName: defender.name,
    attackType: type,
    defenderHpBefore: before,
    defenderHpAfter: defender.hp,
    hits: List<BattleDetailHit>.unmodifiable(hits),
    damageControlName: damageControl,
  );

  BattleDetailHitKind _hitKind(int raw, int damage) {
    if (raw <= 0 || damage <= 0) return BattleDetailHitKind.miss;
    return raw >= 2 ? BattleDetailHitKind.critical : BattleDetailHitKind.hit;
  }

  String _attackTypeLabel(int type, {required bool night}) {
    if (night) {
      return const <int, String>{
            1: '连击',
            2: '主炮·鱼雷 Cut-in',
            3: '鱼雷 Cut-in',
            4: '主炮 Cut-in',
            5: '主炮副炮 Cut-in',
            6: '空母夜袭',
            7: '驱逐舰专用 Cut-in',
            100: '僚舰夜战突击',
            101: '僚舰夜战突击',
          }[type] ??
          '夜战攻击';
    }
    return const <int, String>{
          1: 'レーザー攻击',
          2: '主炮连击',
          3: '主炮副炮攻击',
          4: '主炮电探攻击',
          5: '主炮彻甲弹攻击',
          6: '空母 Cut-in',
          7: '战爆联合',
          100: 'Nelson Touch',
          101: '长门特殊攻击',
          102: '陆奥特殊攻击',
          103: 'Colorado 特殊攻击',
          200: '瑞凤特殊攻击',
          300: '大和特殊攻击',
          301: '大和特殊攻击',
          302: '大和特殊攻击',
          400: '潜水舰特殊攻击',
          401: '潜水舰特殊攻击',
        }[type] ??
        '炮击';
  }

  BattleDetailSide _side(BattleSide side) => side == BattleSide.friend
      ? BattleDetailSide.friend
      : BattleDetailSide.enemy;

  BattleDetailFleetRole _role(BattleFleetRole role) =>
      role == BattleFleetRole.main
      ? BattleDetailFleetRole.main
      : BattleDetailFleetRole.escort;

  Map<String, Object?>? _map(Object? value) => value is Map
      ? value.map((key, child) => MapEntry(key.toString(), child))
      : null;

  List<Object?> _list(Object? value) =>
      value is List ? List<Object?>.from(value) : const <Object?>[];

  List<Object?> _withoutSentinel(List<Object?> values) =>
      values.isNotEmpty && _int(values.first) < 0 ? values.sublist(1) : values;

  int _int(Object? value) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? 0;

  int _atInt(List<Object?> values, int index) =>
      index >= 0 && index < values.length ? _int(values[index]) : 0;

  int _damage(Object? value) {
    final amount = value is num ? value.floor() : _int(value);
    return amount.clamp(0, 1 << 30);
  }
}

final class _ReplayState {
  _ReplayState(LiveBattle battle) {
    add(battle.friendMain);
    add(battle.friendEscort);
    add(battle.enemyMain);
    add(battle.enemyEscort);
  }

  final Map<String, _ReplayShip> _ships = <String, _ReplayShip>{};

  void add(List<BattleShipSnapshot> ships) {
    for (final ship in ships) {
      final side = ship.side == BattleSide.friend
          ? BattleDetailSide.friend
          : BattleDetailSide.enemy;
      final role = ship.fleetRole == BattleFleetRole.main
          ? BattleDetailFleetRole.main
          : BattleDetailFleetRole.escort;
      _ships[_key(side, role, ship.position)] = _ReplayShip(
        side: side,
        role: role,
        position: ship.position,
        name: ship.name,
        maxHp: ship.maxHp,
        hp: ship.initialHp,
        damageControl: <int>[
          for (final id in ship.equipmentMasterIds)
            if (id == 42 || id == 43) id,
        ],
      );
    }
  }

  _ReplayShip? resolve(BattleDetailSide side, int absolutePosition) {
    final role = absolutePosition >= 6
        ? BattleDetailFleetRole.escort
        : BattleDetailFleetRole.main;
    final position = absolutePosition >= 6
        ? absolutePosition - 6
        : absolutePosition;
    final direct = resolveRole(side, role, position);
    if (direct != null) return direct;
    return resolveRole(side, BattleDetailFleetRole.main, absolutePosition);
  }

  _ReplayShip? resolveRole(
    BattleDetailSide side,
    BattleDetailFleetRole role,
    int position,
  ) => _ships[_key(side, role, position)];

  String? damage(_ReplayShip ship, int amount) {
    ship.hp = (ship.hp - amount).clamp(0, ship.maxHp);
    if (ship.side != BattleDetailSide.friend || ship.hp > 0) return null;
    if (ship.damageControl.isEmpty) return null;
    final item = ship.damageControl.removeAt(0);
    if (item == 42) {
      ship.hp = (ship.maxHp ~/ 5).clamp(1, ship.maxHp);
      return '应急修理要员';
    }
    if (item == 43) {
      ship.hp = ship.maxHp;
      return '应急修理女神';
    }
    return null;
  }

  String _key(
    BattleDetailSide side,
    BattleDetailFleetRole role,
    int position,
  ) => '${side.name}:${role.name}:$position';
}

final class _ReplayShip {
  _ReplayShip({
    required this.side,
    required this.role,
    required this.position,
    required this.name,
    required this.maxHp,
    required this.hp,
    required this.damageControl,
  });

  final BattleDetailSide side;
  final BattleDetailFleetRole role;
  final int position;
  final String name;
  final int maxHp;
  int hp;
  final List<int> damageControl;
}
