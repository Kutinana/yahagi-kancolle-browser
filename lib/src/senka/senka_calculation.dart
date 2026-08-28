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
    required this.unsettledSenka,
    required this.dailyRequired,
    required this.todayRemaining,
  });

  factory SenkaCalculationResult.fromState(SenkaState state, {DateTime? now}) {
    final instant = now ?? DateTime.now().toUtc();
    final currentDate = senkaBusinessDate(instant);
    final plannedEo = _plannedSenka(state.eoStatuses, senkaEoCatalog);
    final plannedQuest = _plannedSenka(state.questStatuses, senkaQuestCatalog);
    final baseSenka = state.unsettledSenka;
    final projected = senkaProjected(state);
    final difference = state.targetSenka - projected;
    final gap = math.max(difference, 0).toDouble();
    final over = math.max(-difference, 0).toDouble();
    final remainingDays = senkaAvailableDays(instant);
    final today = state.day(currentDate);
    final currentDateKey = dateKey(currentDate);
    final projectedAtDayStart = state.dailyTargetDateKey == currentDateKey
        ? state.dailyProjectedSenkaAtStart
        : math.max(projected - today.total, 0).toDouble();
    final gapAtDayStart = math
        .max(state.targetSenka - projectedAtDayStart, 0)
        .toDouble();
    final dailyRequired = remainingDays > 0
        ? gapAtDayStart / remainingDays
        : 0.0;
    final todayProgress = math
        .max(projected - projectedAtDayStart, 0)
        .toDouble();

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
      unsettledSenka: baseSenka,
      dailyRequired: dailyRequired,
      todayRemaining: math.max(dailyRequired - todayProgress, 0).toDouble(),
    );
  }

  final double plannedEo;
  final double plannedQuest;
  final double projected;
  final double gap;
  final double over;
  final double percentage;
  final int remainingDays;
  final double unsettledSenka;
  @Deprecated('Use unsettledSenka')
  double get baseSenka => unsettledSenka;
  final double dailyRequired;
  final double todayRemaining;
}

double senkaProjected(SenkaState state) =>
    state.calculatorCurrentSenka +
    state.unsettledSenka +
    _plannedSenka(state.eoStatuses, senkaEoCatalog) +
    _plannedSenka(state.questStatuses, senkaQuestCatalog);

SenkaState ensureSenkaDailyTarget(SenkaState state, DateTime instant) {
  final businessDate = senkaBusinessDate(instant);
  final key = dateKey(businessDate);
  if (state.dailyTargetDateKey == key) return state;
  final projected = senkaProjected(state);
  final inferredStart = math
      .max(projected - state.day(businessDate).total, 0)
      .toDouble();
  return state.copyWith(
    dailyTargetDateKey: key,
    dailyProjectedSenkaAtStart: inferredStart,
  );
}

SenkaState rebaseSenkaDailyTarget(
  SenkaState previous,
  SenkaState next,
  DateTime instant,
) {
  final initialized = ensureSenkaDailyTarget(previous, instant);
  final key = dateKey(senkaBusinessDate(instant));
  if (initialized.monthKey != next.monthKey) {
    return ensureSenkaDailyTarget(next, instant);
  }
  final projectionChange = senkaProjected(next) - senkaProjected(previous);
  return next.copyWith(
    dailyTargetDateKey: key,
    dailyProjectedSenkaAtStart: math
        .max(initialized.dailyProjectedSenkaAtStart + projectionChange, 0)
        .toDouble(),
  );
}

int senkaRemainingDaysInMonth(int year, int month, int day) =>
    DateTime.utc(year, month + 1, 0).day - day + 1;

int senkaAvailableDays(DateTime instant) {
  final jst = toJst(instant);
  final businessDate = senkaBusinessDate(instant);
  if (jst.year != businessDate.year || jst.month != businessDate.month) {
    return 0;
  }
  final lastDay = DateTime.utc(
    businessDate.year,
    businessDate.month + 1,
    0,
  ).day;
  if (businessDate.day == lastDay && jst.hour >= 22) return 0;
  return senkaRemainingDaysInMonth(
    businessDate.year,
    businessDate.month,
    businessDate.day,
  );
}

DateTime senkaNextRefreshInstant(DateTime instant) {
  final now = instant.toUtc();
  final jst = toJst(now);
  final today = DateTime.utc(jst.year, jst.month, jst.day);
  final tomorrow = today.add(const Duration(days: 1));
  final lastDay = DateTime.utc(jst.year, jst.month + 1, 0).day;
  final candidates = <DateTime>[
    _jstBoundary(today, 2),
    _jstBoundary(today, 5),
    if (jst.day == lastDay) _jstBoundary(today, 22),
    _jstBoundary(tomorrow, 2),
    _jstBoundary(tomorrow, 5),
  ]..removeWhere((candidate) => !candidate.isAfter(now));
  candidates.sort();
  return candidates.first;
}

DateTime _jstBoundary(DateTime jstDate, int hour) => DateTime.utc(
  jstDate.year,
  jstDate.month,
  jstDate.day,
  hour,
).subtract(const Duration(hours: 9));

double _plannedSenka(
  Map<int, SenkaRewardStatus> statuses,
  List<SenkaCatalogItem> catalog,
) => catalog.fold(
  0,
  (sum, item) =>
      statuses[item.id] == SenkaRewardStatus.planned ? sum + item.senka : sum,
);
