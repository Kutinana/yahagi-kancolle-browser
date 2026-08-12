import '../battle_damage_parser.dart';
import '../battle_models.dart';
import '../battle_rank.dart';
import 'battle_prediction_engine.dart';

final class YahagiBattlePredictionEngine implements BattlePredictionEngine {
  YahagiBattlePredictionEngine({
    required List<BattleShipSnapshot> friendMain,
    List<BattleShipSnapshot> friendEscort = const <BattleShipSnapshot>[],
    required List<BattleShipSnapshot> enemyMain,
    List<BattleShipSnapshot> enemyEscort = const <BattleShipSnapshot>[],
    BattleDamageParser? damageParser,
  }) : _friendMain = List<BattleShipSnapshot>.from(friendMain),
       _friendEscort = List<BattleShipSnapshot>.from(friendEscort),
       _enemyMain = List<BattleShipSnapshot>.from(enemyMain),
       _enemyEscort = List<BattleShipSnapshot>.from(enemyEscort),
       _damageParser = damageParser ?? BattleDamageParser();

  static const Set<String> _airRaidPaths = <String>{
    '/kcsapi/api_req_sortie/ld_airbattle',
    '/kcsapi/api_req_sortie/ld_shooting',
    '/kcsapi/api_req_combined_battle/ld_airbattle',
    '/kcsapi/api_req_combined_battle/ld_shooting',
  };

  final BattleDamageParser _damageParser;
  List<BattleShipSnapshot> _friendMain;
  List<BattleShipSnapshot> _friendEscort;
  List<BattleShipSnapshot> _enemyMain;
  List<BattleShipSnapshot> _enemyEscort;
  final List<BattleParseIssue> _issues = <BattleParseIssue>[];
  final List<int> _nightEscortDamage = List<int>.filled(6, 0);
  bool _airRaid = false;
  bool _nightOnlyMvp = false;

  @override
  BattlePrediction append({
    required String path,
    required Map<String, Object?> data,
  }) {
    _airRaid = _airRaid || _airRaidPaths.contains(path);
    _nightOnlyMvp =
        _nightOnlyMvp ||
        (path == '/kcsapi/api_req_combined_battle/midnight_battle' &&
            _friendEscort.isNotEmpty);
    final escortDamageBefore = <int>[
      for (final ship in _friendEscort) ship.damageDealt,
    ];
    final parsed = _damageParser.apply(
      data: data,
      friendMain: _friendMain,
      friendEscort: _friendEscort,
      enemyMain: _enemyMain,
      enemyEscort: _enemyEscort,
      path: path,
    );
    _friendMain = parsed.friendMain;
    _friendEscort = parsed.friendEscort;
    _enemyMain = parsed.enemyMain;
    _enemyEscort = parsed.enemyEscort;
    if (_nightOnlyMvp) {
      for (
        var index = 0;
        index < _friendEscort.length && index < _nightEscortDamage.length;
        index++
      ) {
        final before = index < escortDamageBefore.length
            ? escortDamageBefore[index]
            : 0;
        final delta = _friendEscort[index].damageDealt - before;
        if (delta > 0) _nightEscortDamage[index] += delta;
      }
    }
    _issues.addAll(parsed.issues);
    final rank = _issues.isEmpty
        ? estimateBattleRank(
            friendShips: <BattleShipSnapshot>[..._friendMain, ..._friendEscort],
            enemyShips: <BattleShipSnapshot>[..._enemyMain, ..._enemyEscort],
            airRaid: _airRaid,
          )
        : BattleRank.unknown;
    return BattlePrediction(
      friendMain: List<BattleShipSnapshot>.unmodifiable(_friendMain),
      friendEscort: List<BattleShipSnapshot>.unmodifiable(_friendEscort),
      enemyMain: List<BattleShipSnapshot>.unmodifiable(_enemyMain),
      enemyEscort: List<BattleShipSnapshot>.unmodifiable(_enemyEscort),
      rank: rank,
      mvpPositions: List<int>.unmodifiable(_mvpPositions()),
      issues: List<BattleParseIssue>.unmodifiable(_issues),
    );
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
}
