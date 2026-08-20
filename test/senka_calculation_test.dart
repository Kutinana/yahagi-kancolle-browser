import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/senka/senka_calculation.dart';
import 'package:yahagi_kancolle_browser/src/senka/senka_state.dart';

void main() {
  test('剩余天数只按年月日计算而不依赖本地时区时长', () {
    expect(senkaRemainingDaysInMonth(2026, 3, 8), 24);
    expect(senkaRemainingDaysInMonth(2026, 11, 1), 30);
    expect(senkaRemainingDaysInMonth(2028, 2, 28), 2);
  });

  test('按计划奖励与当月进度计算目标差额和含当天日均', () {
    final state = SenkaState.forMonth('2026-08').copyWith(
      targetSenka: 3000,
      calculatorCurrentSenka: 1000,
      eoStatuses: const {
        15: SenkaRewardStatus.planned,
        25: SenkaRewardStatus.completed,
      },
      questStatuses: const {
        854: SenkaRewardStatus.planned,
        947: SenkaRewardStatus.planned,
        949: SenkaRewardStatus.deferred,
      },
      days: const {
        '2026-08-10': SenkaDayRecord(experience: 3.85, eo: 75, quest: 0),
        '2026-08-09': SenkaDayRecord(experience: 7),
      },
    );

    final result = SenkaCalculationResult.fromState(
      state,
      now: DateTime.utc(2026, 8, 10, 3),
    );

    expect(result.plannedEo, 75);
    expect(result.plannedQuest, 830);
    expect(result.projected, 1905);
    expect(result.gap, 1095);
    expect(result.over, 0);
    expect(result.percentage, closeTo(63.5, 0.0001));
    expect(result.remainingDays, 22);
    expect(result.baseSenka, closeTo(10.85, 0.0001));
    expect(result.dailyRequired, closeTo(1095 / 22, 0.0001));
    expect(result.todayRemaining, 0);
  });

  test('超过目标时差额与每日需求归零并报告超额', () {
    final state = SenkaState.forMonth(
      '2026-08',
    ).copyWith(targetSenka: 1000, calculatorCurrentSenka: 1200);

    final result = SenkaCalculationResult.fromState(
      state,
      now: DateTime.utc(2026, 8, 31, 3),
    );

    expect(result.projected, 1200);
    expect(result.gap, 0);
    expect(result.over, 200);
    expect(result.percentage, 120);
    expect(result.remainingDays, 1);
    expect(result.dailyRequired, 0);
    expect(result.todayRemaining, 0);
  });

  test('当天进度仅抵扣当天剩余需求', () {
    final state = SenkaState.forMonth('2026-02').copyWith(
      targetSenka: 280,
      days: const {'2026-02-01': SenkaDayRecord(experience: 4)},
    );

    final result = SenkaCalculationResult.fromState(
      state,
      now: DateTime.utc(2026, 2, 1, 3),
    );

    expect(result.remainingDays, 28);
    expect(result.dailyRequired, 10);
    expect(result.todayRemaining, 6);
  });

  test('UTC 17:30 跨过 JST 战果日边界时不偏日', () {
    final state = SenkaState.forMonth('2026-08').copyWith(
      targetSenka: 31,
      days: const {'2026-08-31': SenkaDayRecord(experience: 5)},
    );

    final result = SenkaCalculationResult.fromState(
      state,
      now: DateTime.utc(2026, 8, 30, 17, 30),
    );

    expect(result.remainingDays, 1);
    expect(result.dailyRequired, 31);
    expect(result.todayRemaining, 26);
  });
}
