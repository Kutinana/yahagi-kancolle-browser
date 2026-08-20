import 'dart:math' as math;

import 'senka_catalog.dart';
import 'senka_state.dart';

class SenkaCalculationResult {
  const SenkaCalculationResult({
    required this.plannedEo,
    required this.plannedQuest,
    required this.projected,
    required this.gap,
    required this.over,
    required this.percentage,
    required this.remainingDays,
    required this.baseSenka,
    required this.dailyRequired,
    required this.todayRemaining,
  });

  factory SenkaCalculationResult.fromState(SenkaState state, {DateTime? now}) {
    final currentDate = senkaBusinessDate(now ?? DateTime.now().toUtc());
    final plannedEo = _plannedSenka(state.eoStatuses, senkaEoCatalog);
    final plannedQuest = _plannedSenka(state.questStatuses, senkaQuestCatalog);
    final projected = state.calculatorCurrentSenka + plannedEo + plannedQuest;
    final difference = state.targetSenka - projected;
    final gap = math.max(difference, 0).toDouble();
    final over = math.max(-difference, 0).toDouble();
    final lastDay = DateTime(currentDate.year, currentDate.month + 1, 0);
    final remainingDays =
        lastDay
            .difference(
              DateTime(currentDate.year, currentDate.month, currentDate.day),
            )
            .inDays +
        1;
    final safeRemainingDays = math.max(remainingDays, 1);
    final dailyRequired = gap / safeRemainingDays;
    final today = state.day(currentDate);

    return SenkaCalculationResult(
      plannedEo: plannedEo,
      plannedQuest: plannedQuest,
      projected: projected,
      gap: gap,
      over: over,
      percentage: state.targetSenka > 0
          ? projected / state.targetSenka * 100
          : 0,
      remainingDays: remainingDays,
      baseSenka: state.days.values.fold(
        0,
        (sum, record) => sum + record.experience,
      ),
      dailyRequired: dailyRequired,
      todayRemaining: math.max(dailyRequired - today.total, 0).toDouble(),
    );
  }

  final double plannedEo;
  final double plannedQuest;
  final double projected;
  final double gap;
  final double over;
  final double percentage;
  final int remainingDays;
  final double baseSenka;
  final double dailyRequired;
  final double todayRemaining;
}

double _plannedSenka(
  Map<int, SenkaRewardStatus> statuses,
  List<SenkaCatalogItem> catalog,
) => catalog.fold(
  0,
  (sum, item) =>
      statuses[item.id] == SenkaRewardStatus.planned ? sum + item.senka : sum,
);
