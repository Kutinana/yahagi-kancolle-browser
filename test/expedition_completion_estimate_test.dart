import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/expedition/expedition_completion_estimate.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';

void main() {
  final now = DateTime.utc(2026, 9, 24, 5, 30);
  const selected = MasterMission(
    id: 5,
    name: '海上護衛任務',
    duration: Duration(hours: 1, minutes: 30),
  );

  Fleet fleet({int state = 0, int missionId = 0, DateTime? completionTime}) =>
      Fleet(
        id: 2,
        name: '第二艦隊',
        mission: FleetMission(
          state: state,
          missionId: missionId,
          completionTime: completionTime,
        ),
      );

  test('空闲舰队按设备当前时刻加所选远征时长', () {
    final estimate = estimateExpeditionCompletion(
      fleet: fleet(),
      selectedMission: selected,
      now: now,
    );

    expect(estimate.basis, ExpeditionCompletionBasis.departingNow);
    expect(estimate.completionTime, DateTime.utc(2026, 9, 24, 7));
  });

  test('正在执行所选远征时使用接口完成时刻', () {
    final actualEnd = DateTime.utc(2026, 9, 24, 6, 10, 37);
    final estimate = estimateExpeditionCompletion(
      fleet: fleet(state: 1, missionId: 5, completionTime: actualEnd),
      selectedMission: selected,
      now: now,
    );

    expect(estimate.basis, ExpeditionCompletionBasis.currentMission);
    expect(estimate.completionTime, actualEnd);
  });

  test('37 远征进行中检查 38 时按设备当前时刻估算 38', () {
    final actualEnd = DateTime.utc(2026, 9, 24, 6, 10);
    const selected38 = MasterMission(
      id: 38,
      name: '東京急行（二）',
      duration: Duration(hours: 2),
    );
    final estimate = estimateExpeditionCompletion(
      fleet: fleet(state: 1, missionId: 37, completionTime: actualEnd),
      selectedMission: selected38,
      now: now,
    );

    expect(estimate.basis, ExpeditionCompletionBasis.otherMissionFromNow);
    expect(estimate.completionTime, DateTime.utc(2026, 9, 24, 7, 30));
  });

  test('其他远征已到时但状态未刷新时仍从设备当前时刻估算', () {
    final estimate = estimateExpeditionCompletion(
      fleet: fleet(
        state: 1,
        missionId: 3,
        completionTime: now.subtract(const Duration(minutes: 1)),
      ),
      selectedMission: selected,
      now: now,
    );

    expect(estimate.basis, ExpeditionCompletionBasis.otherMissionFromNow);
    expect(estimate.completionTime, DateTime.utc(2026, 9, 24, 7));
  });

  test('进行中但缺少完成时刻时不误判为空闲', () {
    final estimate = estimateExpeditionCompletion(
      fleet: fleet(state: 1, missionId: 5),
      selectedMission: selected,
      now: now,
    );

    expect(estimate.basis, ExpeditionCompletionBasis.unavailable);
    expect(estimate.completionTime, isNull);
  });

  test('执行其他远征且缺少其完成时刻时仍按当前时间估算', () {
    final estimate = estimateExpeditionCompletion(
      fleet: fleet(state: 1, missionId: 3),
      selectedMission: selected,
      now: now,
    );

    expect(estimate.basis, ExpeditionCompletionBasis.otherMissionFromNow);
    expect(estimate.completionTime, DateTime.utc(2026, 9, 24, 7));
  });

  test('格式化完成时刻按设备本地日历跨日展示', () {
    final localNow = DateTime(2026, 9, 24, 23, 50);
    final localEnd = DateTime(2026, 9, 25, 0, 20);

    expect(
      formatExpeditionCompletionTime(localEnd, now: localNow),
      '09/25 00:20',
    );
    expect(
      formatExpeditionCompletionTime(
        localNow.add(const Duration(minutes: 5)),
        now: localNow,
      ),
      '23:55',
    );
  });
}
