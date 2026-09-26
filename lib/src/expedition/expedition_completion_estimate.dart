import '../game_state/game_state.dart';

enum ExpeditionCompletionBasis {
  departingNow,
  currentMission,
  otherMissionFromNow,
  unavailable,
}

class ExpeditionCompletionEstimate {
  const ExpeditionCompletionEstimate(this.basis, this.completionTime);

  final ExpeditionCompletionBasis basis;
  final DateTime? completionTime;
}

ExpeditionCompletionEstimate estimateExpeditionCompletion({
  required Fleet fleet,
  required MasterMission? selectedMission,
  required DateTime now,
}) {
  if (selectedMission == null) {
    return const ExpeditionCompletionEstimate(
      ExpeditionCompletionBasis.unavailable,
      null,
    );
  }

  final activeMission = fleet.mission;
  if (activeMission.state <= 0) {
    return ExpeditionCompletionEstimate(
      ExpeditionCompletionBasis.departingNow,
      now.add(selectedMission.duration),
    );
  }

  if (activeMission.missionId != selectedMission.id) {
    return ExpeditionCompletionEstimate(
      ExpeditionCompletionBasis.otherMissionFromNow,
      now.add(selectedMission.duration),
    );
  }

  final currentEnd = activeMission.completionTime;
  if (currentEnd == null) {
    return const ExpeditionCompletionEstimate(
      ExpeditionCompletionBasis.unavailable,
      null,
    );
  }
  return ExpeditionCompletionEstimate(
    ExpeditionCompletionBasis.currentMission,
    currentEnd,
  );
}

String formatExpeditionCompletionTime(
  DateTime completionTime, {
  required DateTime now,
}) {
  final localEnd = completionTime.toLocal();
  final localNow = now.toLocal();
  final hour = localEnd.hour.toString().padLeft(2, '0');
  final minute = localEnd.minute.toString().padLeft(2, '0');
  final clock = '$hour:$minute';
  if (localEnd.year == localNow.year &&
      localEnd.month == localNow.month &&
      localEnd.day == localNow.day) {
    return clock;
  }
  final month = localEnd.month.toString().padLeft(2, '0');
  final day = localEnd.day.toString().padLeft(2, '0');
  final date = localEnd.year == localNow.year
      ? '$month/$day'
      : '${localEnd.year}/$month/$day';
  return '$date $clock';
}
