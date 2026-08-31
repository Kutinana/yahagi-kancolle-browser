import '../battle_models.dart';

class BattleParseIssue {
  const BattleParseIssue({required this.stage, required this.message});

  final String stage;
  final String message;
}

abstract interface class BattlePredictionEngine {
  BattlePrediction append({
    required String path,
    required Map<String, Object?> data,
  });
}

typedef BattlePredictionEngineFactory =
    BattlePredictionEngine Function({
      required List<BattleShipSnapshot> friendMain,
      required List<BattleShipSnapshot> friendEscort,
      required List<BattleShipSnapshot> enemyMain,
      required List<BattleShipSnapshot> enemyEscort,
    });

class BattlePrediction {
  const BattlePrediction({
    required this.friendMain,
    required this.friendEscort,
    required this.enemyMain,
    required this.enemyEscort,
    required this.rank,
    this.mvpPositions = const <int>[],
    this.issues = const <BattleParseIssue>[],
  });

  final List<BattleShipSnapshot> friendMain;
  final List<BattleShipSnapshot> friendEscort;
  final List<BattleShipSnapshot> enemyMain;
  final List<BattleShipSnapshot> enemyEscort;
  final BattleRank rank;
  final List<int> mvpPositions;
  final List<BattleParseIssue> issues;
}
