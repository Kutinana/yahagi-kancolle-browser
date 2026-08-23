import '../game_state/game_state.dart';

String fleetMoraleRecoveryDisplay({
  required GameState state,
  required int fleetId,
  required DateTime? targetAt,
  required DateTime now,
  required String recoveredLabel,
  required String noValueLabel,
}) {
  final fleet = state.fleets.where((item) => item.id == fleetId).firstOrNull;
  if (fleet == null || fleet.shipIds.isEmpty) return noValueLabel;

  final conditions = fleet.shipIds
      .map((shipId) => state.ships[shipId]?.condition)
      .whereType<int>()
      .toList(growable: false);
  if (conditions.length != fleet.shipIds.length) return noValueLabel;
  final minimumCondition = conditions.reduce(
    (left, right) => left < right ? left : right,
  );
  if (minimumCondition >= 49) return recoveredLabel;
  if (targetAt == null || !targetAt.isAfter(now)) return recoveredLabel;

  final remainingMilliseconds = targetAt
      .toUtc()
      .difference(now.toUtc())
      .inMilliseconds;
  final totalSeconds = (remainingMilliseconds + 999) ~/ 1000;
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;
  final minuteText = minutes.toString().padLeft(2, '0');
  final secondText = seconds.toString().padLeft(2, '0');
  return hours > 0
      ? '$hours:$minuteText:$secondText'
      : '$minuteText:$secondText';
}
