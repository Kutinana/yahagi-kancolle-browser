import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/expedition/expedition_mission_picker.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';

void main() {
  test('远征按 Poi 海域顺序分组并支持编号兜底', () {
    final groups = groupExpeditionMissions(
      const <int, MasterMission>{},
      const <int>[1, 9, 17, 41, 25, 33, 100, 110, 131, 141],
    );

    expect(groups.map((group) => group.areaId), <int>[1, 2, 3, 7, 4, 5]);
    expect(groups[0].missionIds, <int>[1, 100]);
    expect(groups[1].missionIds, <int>[9, 110]);
    expect(groups[4].missionIds, <int>[25, 131]);
    expect(groups[5].missionIds, <int>[33, 141]);
  });

  testWidgets('二级选择器左侧切换海域后从右侧选择远征', (tester) async {
    var selected = 1;
    const missions = <int, MasterMission>{
      1: MasterMission(
        id: 1,
        name: '练习航海',
        duration: Duration(minutes: 15),
        displayNumber: '01',
        mapAreaId: 1,
      ),
      9: MasterMission(
        id: 9,
        name: 'タンカー護衛任務',
        duration: Duration(hours: 4),
        displayNumber: '09',
        mapAreaId: 2,
      ),
    };

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: ExpeditionMissionPicker(
              missions: missions,
              missionIds: const <int>[1, 9, 17, 41, 25, 33],
              selectedMissionId: selected,
              onSelected: (value) => setState(() => selected = value),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('expedition-mission-picker')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('expedition-mission-picker-dialog')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('expedition-area-1')), findsOneWidget);
    expect(find.byKey(const Key('expedition-area-2')), findsOneWidget);
    final areaNames = <String>[
      '镇守府海域',
      '南西群岛海域',
      '北方海域',
      '南西海域',
      '西方海域',
      '南方海域',
    ];
    for (final name in areaNames) {
      expect(find.text(name), findsOneWidget);
    }
    for (var index = 1; index < areaNames.length; index++) {
      expect(
        tester.getTopLeft(find.text(areaNames[index])).dy,
        greaterThan(tester.getTopLeft(find.text(areaNames[index - 1])).dy),
      );
    }
    for (final world in <String>['W1', 'W2', 'W3', 'W7', 'W4', 'W5']) {
      expect(find.text(world), findsNothing);
    }

    await tester.tap(find.byKey(const Key('expedition-area-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('expedition-mission-option-9')));
    await tester.pumpAndSettle();

    expect(selected, 9);
    expect(find.textContaining('09 · タンカー護衛任務'), findsOneWidget);
  });
}
