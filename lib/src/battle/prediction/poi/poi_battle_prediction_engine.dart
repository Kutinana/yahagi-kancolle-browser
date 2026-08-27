import '../../battle_damage_parser.dart';
import '../../battle_models.dart';
import '../battle_prediction_engine.dart';

/// Native Dart port of poi-lib-battle's packet replay semantics.
final class PoiBattlePredictionEngine implements BattlePredictionEngine {
  PoiBattlePredictionEngine({
    required List<BattleShipSnapshot> friendMain,
    List<BattleShipSnapshot> friendEscort = const <BattleShipSnapshot>[],
    required List<BattleShipSnapshot> enemyMain,
    List<BattleShipSnapshot> enemyEscort = const <BattleShipSnapshot>[],
  }) : _friendMain = List.of(friendMain),
       _friendEscort = List.of(friendEscort),
       _enemyMain = List.of(enemyMain),
       _enemyEscort = List.of(enemyEscort);

  final List<BattleShipSnapshot> _friendMain;
  final List<BattleShipSnapshot> _friendEscort;
  final List<BattleShipSnapshot> _enemyMain;
  final List<BattleShipSnapshot> _enemyEscort;
  final List<BattleParseIssue> _issues = <BattleParseIssue>[];
  String _stage = 'unknown';
  bool _airRaid = false;
  bool _nightOnlyMvp = false;
  final List<int> _nightEscortDamage = List<int>.filled(6, 0);

  @override
  BattlePrediction append({
    required String path,
    required Map<String, Object?> data,
  }) {
    _airRaid =
        _airRaid ||
        path.contains('ld_airbattle') ||
        path.contains('ld_shooting');
    _nightOnlyMvp =
        _nightOnlyMvp ||
        (path == '/kcsapi/api_req_combined_battle/midnight_battle' &&
            _friendEscort.isNotEmpty);
    final active = _list(data['api_active_deck']);
    final friendEscort = _atInt(active, 0) == 2;
    final enemyEscort = _atInt(active, 1) == 2;
    final nightFirst = path.contains('night_to_day');
    if (nightFirst) {
      _night(data, friendEscort: friendEscort, enemyEscort: enemyEscort);
    }
    _day(data, friendEscort: friendEscort, enemyEscort: enemyEscort);
    if (!nightFirst) {
      _night(data, friendEscort: friendEscort, enemyEscort: enemyEscort);
    }
    return BattlePrediction(
      friendMain: List.unmodifiable(_friendMain),
      friendEscort: List.unmodifiable(_friendEscort),
      enemyMain: List.unmodifiable(_enemyMain),
      enemyEscort: List.unmodifiable(_enemyEscort),
      rank: _issues.isEmpty ? _rank() : BattleRank.unknown,
      mvpPositions: List<int>.unmodifiable(_mvpPositions()),
      issues: List.unmodifiable(_issues),
    );
  }

  void _day(
    Map<String, Object?> data, {
    required bool friendEscort,
    required bool enemyEscort,
  }) {
    for (final key in <String>[
      'api_air_base_injection',
      'api_injection_kouku',
    ]) {
      _aerial(
        data[key],
        key,
        friendEscort: friendEscort,
        enemyEscort: enemyEscort,
      );
    }
    final bases = _list(data['api_air_base_attack']);
    for (var i = 0; i < bases.length; i++) {
      _aerial(
        bases[i],
        'api_air_base_attack[$i]',
        friendEscort: false,
        enemyEscort: false,
      );
    }
    for (final key in <String>[
      'api_friendly_kouku',
      'api_kouku',
      'api_kouku2',
    ]) {
      _aerial(
        data[key],
        key,
        friendEscort: friendEscort,
        enemyEscort: enemyEscort,
      );
    }
    if (data['api_stage3'] is Map || data['api_stage3_combined'] is Map) {
      _aerial(
        data,
        'packet-stage3',
        friendEscort: friendEscort,
        enemyEscort: enemyEscort,
      );
    }
    _support(
      data['api_support_info'],
      _int(data['api_support_flag']),
      'api_support_info',
    );
    _shell(
      data['api_opening_taisen'],
      'api_opening_taisen',
      friendEscort: friendEscort,
      enemyEscort: enemyEscort,
    );
    _torpedo(
      data['api_opening_atack'],
      'api_opening_atack',
      friendEscort: friendEscort,
      enemyEscort: enemyEscort,
    );
    for (final key in <String>[
      'api_hougeki1',
      'api_hougeki2',
      'api_hougeki3',
    ]) {
      _shell(
        data[key],
        key,
        friendEscort: friendEscort,
        enemyEscort: enemyEscort,
      );
    }
    _torpedo(
      data['api_raigeki'],
      'api_raigeki',
      friendEscort: friendEscort,
      enemyEscort: enemyEscort,
    );
  }

  void _night(
    Map<String, Object?> data, {
    required bool friendEscort,
    required bool enemyEscort,
  }) {
    _support(
      data['api_n_support_info'],
      _int(data['api_n_support_flag']),
      'api_n_support_info',
    );
    for (final key in <String>['api_n_hougeki1', 'api_n_hougeki2']) {
      _shell(
        data[key],
        key,
        friendEscort: friendEscort,
        enemyEscort: enemyEscort,
        isNight: true,
      );
    }
    final friendly = _map(data['api_friendly_battle']);
    _shell(
      friendly?['api_hougeki'],
      'api_friendly_battle.api_hougeki',
      friendEscort: friendEscort,
      enemyEscort: enemyEscort,
      attributeFriendDamage: false,
      isNight: true,
    );
    _shell(
      data['api_hougeki'],
      'api_hougeki',
      friendEscort: friendEscort,
      enemyEscort: enemyEscort,
      isNight: true,
    );
  }

  void _aerial(
    Object? value,
    String stage, {
    required bool friendEscort,
    required bool enemyEscort,
  }) {
    final map = _map(value);
    if (map == null) return;
    _stage = stage;
    _arrayDamage(
      _map(map['api_stage3']),
      escort: false,
      friendEscort: friendEscort,
      enemyEscort: enemyEscort,
    );
    _arrayDamage(
      _map(map['api_stage3_combined']),
      escort: true,
      friendEscort: friendEscort,
      enemyEscort: enemyEscort,
    );
  }

  void _torpedo(
    Object? value,
    String stage, {
    required bool friendEscort,
    required bool enemyEscort,
  }) {
    final map = _map(value);
    if (map == null) return;
    _stage = stage;
    _attributeTorpedoDamage(map);
    _arrayDamage(
      map,
      escort: false,
      friendEscort: friendEscort,
      enemyEscort: enemyEscort,
    );
  }

  void _attributeTorpedoDamage(Map<String, Object?> map) {
    final rows = _list(map['api_fydam_list_items']);
    if (rows.isNotEmpty) {
      for (var position = 0; position < rows.length; position++) {
        final amount = _list(
          rows[position],
        ).fold<int>(0, (sum, value) => sum + _damage(value));
        _addAbsoluteFriendDamage(position, amount);
      }
      return;
    }
    if (map['api_frai'] == null) return;
    final values = _list(map['api_fydam']).isNotEmpty
        ? _list(map['api_fydam'])
        : _list(map['api_fdam']);
    for (var position = 0; position < values.length; position++) {
      _addAbsoluteFriendDamage(position, _damage(values[position]));
    }
  }

  void _addAbsoluteFriendDamage(int position, int amount) {
    if (amount <= 0) return;
    if (_friendEscort.isNotEmpty && position >= _friendMain.length) {
      _addDealt(_friendEscort, position - _friendMain.length, amount);
    } else {
      _addDealt(_friendMain, position, amount);
    }
  }

  void _arrayDamage(
    Map<String, Object?>? map, {
    required bool escort,
    required bool friendEscort,
    required bool enemyEscort,
  }) {
    if (map == null) return;
    _damageArray(
      escort || friendEscort ? _friendEscort : _friendMain,
      _list(map['api_fdam']),
      main: _friendMain,
      escortFleet: _friendEscort,
    );
    _damageArray(
      escort || enemyEscort ? _enemyEscort : _enemyMain,
      _list(map['api_edam']),
      main: _enemyMain,
      escortFleet: _enemyEscort,
    );
  }

  void _shell(
    Object? value,
    String stage, {
    required bool friendEscort,
    required bool enemyEscort,
    bool attributeFriendDamage = true,
    bool isNight = false,
  }) {
    final map = _map(value);
    if (map == null) return;
    _stage = stage;
    final flags = _list(map['api_at_eflag']);
    final attackers = _list(map['api_at_list']);
    final defenders = _list(map['api_df_list']);
    final damages = _list(map['api_damage']);
    final attackTypes = _list(map[isNight ? 'api_sp_list' : 'api_at_type']);
    final mainFleetRange = _friendMain.length;
    for (var row = 0; row < defenders.length && row < damages.length; row++) {
      final targets = _list(defenders[row]);
      final hits = _list(damages[row]);
      final enemyAttack = row < flags.length
          ? _int(flags[row]) != 0
          : (targets.isNotEmpty && _int(targets.first) < mainFleetRange);
      final attackOrder = row < attackTypes.length
          ? _multiTargetAttackOrder(_int(attackTypes[row]), isNight: isNight)
          : null;
      var dealt = 0;
      if (attackOrder == null) {
        final amount = hits.fold<int>(0, (sum, hit) => sum + _damage(hit));
        if (amount > 0 && targets.isNotEmpty) {
          if (attributeFriendDamage && !enemyAttack) dealt = amount;
          var position = _int(targets.first);
          var escort = enemyAttack ? friendEscort : enemyEscort;
          if (row >= flags.length) {
            if (!enemyAttack && position >= mainFleetRange) {
              position -= mainFleetRange;
            }
            escort = false;
          }
          _damagePosition(enemyAttack, escort, position, amount);
        }
      } else {
        for (var hit = 0; hit < targets.length && hit < hits.length; hit++) {
          final amount = _damage(hits[hit]);
          if (amount == 0) continue;
          if (attributeFriendDamage && !enemyAttack) {
            var attacker = row < attackers.length ? _int(attackers[row]) : -1;
            if (attacker >= 0) {
              attacker += hit < attackOrder.length ? attackOrder[hit] : 0;
              // poi-lib-battle mirrors this server-side combined-night index fix.
              if (isNight &&
                  _friendEscort.isNotEmpty &&
                  attacker < _friendMain.length) {
                attacker += _friendMain.length;
              }
              _addAbsoluteFriendDamage(attacker, amount);
              if (isNight) _addNightDamage(attacker, amount);
            }
          }
          var position = _int(targets[hit]);
          var escort = enemyAttack ? friendEscort : enemyEscort;
          if (row >= flags.length) {
            if (!enemyAttack && position >= mainFleetRange) {
              position -= mainFleetRange;
            }
            escort = false;
          }
          _damagePosition(enemyAttack, escort, position, amount);
        }
      }
      if (attributeFriendDamage &&
          !enemyAttack &&
          attackOrder == null &&
          row < attackers.length &&
          dealt > 0) {
        var position = _int(attackers[row]);
        final escort = friendEscort || position >= mainFleetRange;
        if (position >= mainFleetRange) position -= mainFleetRange;
        _addDealt(escort ? _friendEscort : _friendMain, position, dealt);
        if (isNight && escort && position < _nightEscortDamage.length) {
          _nightEscortDamage[position] += dealt;
        }
      }
    }
  }

  static List<int>? _multiTargetAttackOrder(
    int attackType, {
    required bool isNight,
  }) {
    if (!isNight && attackType == 1) return const <int>[0, 0, 0];
    return switch (attackType) {
      100 => const <int>[0, 2, 4],
      101 || 102 || 105 || 106 => const <int>[0, 0, 1],
      103 => const <int>[0, 1, 2],
      104 when isNight => const <int>[0, 1],
      200 when isNight => const <int>[0, 0],
      300 => const <int>[1, 1, 2, 2],
      301 => const <int>[2, 2, 3, 3],
      302 => const <int>[1, 1, 3, 3],
      400 => const <int>[0, 1, 2],
      401 => const <int>[0, 0, 1],
      1000 => const <int>[0, 0, 0, 0, 0, 0],
      _ => null,
    };
  }

  void _addNightDamage(int absolutePosition, int amount) {
    if (amount <= 0 || _friendEscort.isEmpty) return;
    final index = absolutePosition - _friendMain.length;
    if (index >= 0 && index < _nightEscortDamage.length) {
      _nightEscortDamage[index] += amount;
    }
  }

  List<int> _mvpPositions() {
    int bestDamagePosition(List<BattleShipSnapshot> fleet) {
      var best = -1;
      var damage = -1;
      for (var index = 0; index < fleet.length; index++) {
        if (fleet[index].damageDealt > damage) {
          best = index;
          damage = fleet[index].damageDealt;
        }
      }
      return best;
    }

    if (_nightOnlyMvp) {
      var best = 0;
      for (var index = 1; index < _nightEscortDamage.length; index++) {
        if (_nightEscortDamage[index] > _nightEscortDamage[best]) best = index;
      }
      return <int>[0, best + 6];
    }
    final main = bestDamagePosition(_friendMain);
    final escort = bestDamagePosition(_friendEscort);
    return <int>[if (main >= 0) main, if (escort >= 0) escort + 6];
  }

  void _support(Object? value, int flag, String stage) {
    final map = _map(value);
    if (map == null || flag <= 0) return;
    _stage = stage;
    if (flag == 1 || flag == 4) {
      final attack = _map(map['api_support_airatack']);
      _damageArray(
        _enemyMain,
        _list(_map(attack?['api_stage3'])?['api_edam']),
        main: _enemyMain,
        escortFleet: _enemyEscort,
      );
    } else {
      _damageArray(
        _enemyMain,
        _list(_map(map['api_support_hourai'])?['api_damage']),
        main: _enemyMain,
        escortFleet: _enemyEscort,
      );
    }
  }

  void _damageArray(
    List<BattleShipSnapshot> fleet,
    List<Object?> raw, {
    required List<BattleShipSnapshot> main,
    required List<BattleShipSnapshot> escortFleet,
  }) {
    final values = raw.isNotEmpty && _int(raw.first) < 0 ? raw.sublist(1) : raw;
    if (escortFleet.isNotEmpty && values.length > 6) {
      _damageArray(
        main,
        values.take(6).toList(),
        main: main,
        escortFleet: const [],
      );
      _damageArray(
        escortFleet,
        values.skip(6).take(6).toList(),
        main: escortFleet,
        escortFleet: const [],
      );
      return;
    }
    for (var i = 0; i < values.length; i++) {
      final amount = _damage(values[i]);
      if (amount > 0) _receive(fleet, i, amount);
    }
  }

  void _damagePosition(
    bool friendTarget,
    bool escort,
    int position,
    int amount,
  ) {
    final hasEscort = friendTarget
        ? _friendEscort.isNotEmpty
        : _enemyEscort.isNotEmpty;
    if (hasEscort && position >= 6) {
      escort = true;
      position -= 6;
    }
    final fleets = friendTarget
        ? (escort ? _friendEscort : _friendMain)
        : (escort ? _enemyEscort : _enemyMain);
    _receive(fleets, position, amount);
  }

  void _receive(List<BattleShipSnapshot> fleet, int position, int amount) {
    final index = fleet.indexWhere((ship) => ship.position == position);
    if (index < 0) {
      _issues.add(
        BattleParseIssue(
          stage: _stage,
          message: 'target $position is outside the captured fleets',
        ),
      );
      return;
    }
    final ship = fleet[index];
    var hp = (ship.currentHp - amount).clamp(0, ship.maxHp);
    final used = List<int>.from(ship.usedDamageControlItemIds);
    if (ship.side == BattleSide.friend && hp == 0) {
      final item = _nextDamageControl(ship, used);
      if (item == 42) hp = ship.maxHp ~/ 5;
      if (item == 43) hp = ship.maxHp;
      if (item != null) used.add(item);
    }
    fleet[index] = ship.copyWith(
      currentHp: hp,
      damageReceived: ship.damageReceived + amount,
      usedDamageControlItemIds: used,
    );
  }

  int? _nextDamageControl(BattleShipSnapshot ship, List<int> used) {
    final remaining = List<int>.from(ship.equipmentMasterIds);
    for (final id in used) {
      remaining.remove(id);
    }
    return remaining.where((id) => id == 42 || id == 43).firstOrNull;
  }

  void _addDealt(List<BattleShipSnapshot> fleet, int position, int amount) {
    final index = fleet.indexWhere((ship) => ship.position == position);
    if (index >= 0) {
      fleet[index] = fleet[index].copyWith(
        damageDealt: fleet[index].damageDealt + amount,
      );
    }
  }

  BattleRank _rank() {
    final ours = _status(<BattleShipSnapshot>[
      ..._friendMain,
      ..._friendEscort,
    ]);
    final enemy = _status(<BattleShipSnapshot>[..._enemyMain, ..._enemyEscort]);
    if (_airRaid) {
      final rate = ours.total == 0 ? 0 : ours.lost * 100 / ours.total;
      if (rate <= 0) return BattleRank.ss;
      if (rate < 10) return BattleRank.a;
      if (rate < 20) return BattleRank.b;
      if (rate < 50) return BattleRank.c;
      if (rate < 80) return BattleRank.d;
      return BattleRank.e;
    }
    if (ours.sunk == 0) {
      if (enemy.sunk == enemy.count) {
        return ours.lost == 0 ? BattleRank.ss : BattleRank.s;
      }
      if (enemy.sunk >= _halfSunk(enemy.count)) return BattleRank.a;
    }
    if (enemy.flagshipSunk && ours.sunk < enemy.sunk) return BattleRank.b;
    if (ours.count == 1 && ours.flagshipCritical) return BattleRank.d;
    if (2 * enemy.rate > 5 * ours.rate) return BattleRank.b;
    if (10 * enemy.rate > 9 * ours.rate) return BattleRank.c;
    if (ours.sunk > 0 && ours.count - ours.sunk == 1) return BattleRank.e;
    return BattleRank.d;
  }

  ({
    int count,
    int sunk,
    int lost,
    int total,
    int rate,
    bool flagshipSunk,
    bool flagshipCritical,
  })
  _status(List<BattleShipSnapshot> ships) {
    if (ships.isEmpty) {
      return (
        count: 0,
        sunk: 0,
        lost: 0,
        total: 0,
        rate: 0,
        flagshipSunk: false,
        flagshipCritical: false,
      );
    }
    final total = ships.fold<int>(0, (v, s) => v + s.initialHp);
    final lost = ships.fold<int>(0, (v, s) => v + s.initialHp - s.currentHp);
    return (
      count: ships.length,
      sunk: ships.where((s) => s.currentHp <= 0).length,
      lost: lost,
      total: total,
      rate: total == 0 ? 0 : lost * 100 ~/ total,
      flagshipSunk: ships.first.currentHp <= 0,
      flagshipCritical: ships.first.currentHp * 4 <= ships.first.maxHp,
    );
  }

  int _halfSunk(int count) =>
      const <int>[0, 1, 1, 2, 2, 3, 4, 4, 5, 5, 6, 6, 8][count.clamp(0, 12)];
  List<Object?> _list(Object? value) =>
      value is List ? List<Object?>.from(value) : const <Object?>[];
  Map<String, Object?>? _map(Object? value) =>
      value is Map ? value.map((k, v) => MapEntry(k.toString(), v)) : null;
  int _int(Object? value) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? 0;
  int _atInt(List<Object?> values, int index) =>
      index < values.length ? _int(values[index]) : 0;
  int _damage(Object? value) =>
      (_int(value is num ? value.floor() : value)).clamp(0, 1 << 30);
}
