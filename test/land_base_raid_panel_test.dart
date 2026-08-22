import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_models.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_pills.dart';
import 'package:yahagi_kancolle_browser/src/battle/land_base_raid_panel.dart';
import 'package:yahagi_kancolle_browser/src/fleet/ship_status_style.dart';

void main() {
  testWidgets('keeps the full base name and hp visible in a narrow panel', (
    tester,
  ) async {
    const result = LandBaseRaidResult(
      areaId: 47,
      airSuperiority: '丧失',
      bases: <LandBaseRaidSnapshot>[
        LandBaseRaidSnapshot(
          baseId: 1,
          name: '第一基地航空队',
          currentHp: 200,
          maxHp: 200,
          damage: 0,
        ),
      ],
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(width: 260, child: LandBaseRaidPanel(result: result)),
        ),
      ),
    );

    expect(find.text('第一基地航空隊'), findsOneWidget);
    expect(find.text('200/200（-0）'), findsOneWidget);
    final hpBar = find.descendant(
      of: find.byKey(const Key('land-base-raid-1')),
      matching: find.byType(LinearProgressIndicator),
    );
    expect(tester.getRect(hpBar).width, lessThan(142));
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact raid keeps detailed hp font size', (tester) async {
    const result = LandBaseRaidResult(
      areaId: 47,
      airSuperiority: '丧失',
      bases: <LandBaseRaidSnapshot>[
        LandBaseRaidSnapshot(
          baseId: 1,
          name: '第一基地航空队',
          currentHp: 200,
          maxHp: 200,
          damage: 0,
        ),
      ],
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: LandBaseRaidPanel(result: result, compact: true),
        ),
      ),
    );

    final hp = tester.widget<Text>(find.text('200/200（-0）'));
    expect(hp.style?.fontSize, 11);
  });

  testWidgets('shows every base hp and raid loss without narrow overflow', (
    tester,
  ) async {
    const result = LandBaseRaidResult(
      areaId: 47,
      airSuperiority: '确保',
      bases: <LandBaseRaidSnapshot>[
        LandBaseRaidSnapshot(
          baseId: 1,
          name: '第一基地航空队',
          currentHp: 200,
          maxHp: 200,
          damage: 0,
        ),
        LandBaseRaidSnapshot(
          baseId: 2,
          name: '名称特别长的第二基地航空队',
          currentHp: 140,
          maxHp: 200,
          damage: 60,
        ),
        LandBaseRaidSnapshot(
          baseId: 3,
          name: '第三基地航空队',
          currentHp: 100,
          maxHp: 200,
          damage: 100,
        ),
        LandBaseRaidSnapshot(
          baseId: 4,
          name: '第四基地航空队',
          currentHp: 50,
          maxHp: 200,
          damage: 150,
        ),
        LandBaseRaidSnapshot(
          baseId: 5,
          name: '第五基地航空队',
          currentHp: 0,
          maxHp: 200,
          damage: 200,
        ),
      ],
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(width: 360, child: LandBaseRaidPanel(result: result)),
        ),
      ),
    );

    expect(find.text('基地空袭'), findsOneWidget);
    expect(find.text('第一基地航空隊'), findsOneWidget);
    expect(find.text('第二基地航空隊'), findsOneWidget);
    expect(find.text('第三基地航空隊'), findsOneWidget);
    expect(find.text('第四基地航空隊'), findsOneWidget);
    expect(find.text('第五基地航空隊'), findsOneWidget);
    expect(find.text('第一基地航空队'), findsNothing);
    expect(find.text('名称特别长的第二基地航空队'), findsNothing);
    expect(find.text('①'), findsNothing);
    expect(find.text('②'), findsNothing);
    expect(find.text('③'), findsNothing);
    expect(find.text('④'), findsNothing);
    expect(find.text('⑤'), findsNothing);
    expect(find.byType(AirSuperiorityPill), findsOneWidget);
    expect(find.text('制空：确保'), findsOneWidget);
    expect(find.text('200/200（-0）'), findsOneWidget);
    expect(find.text('140/200（-60）'), findsOneWidget);
    expect(find.text('100/200（-100）'), findsOneWidget);
    expect(find.text('50/200（-150）'), findsOneWidget);
    expect(find.text('0/200（-200）'), findsOneWidget);
    expect(find.textContaining('损失'), findsNothing);

    final raidTitle = find.text('基地空袭');
    final airState = find.byType(AirSuperiorityPill);
    expect(
      tester.getCenter(airState).dy,
      closeTo(tester.getCenter(raidTitle).dy, 2),
    );
    expect(
      tester.getCenter(airState).dx,
      greaterThan(tester.getCenter(raidTitle).dx),
    );

    final firstTile = find.byKey(const Key('land-base-raid-1'));
    expect(
      find.descendant(of: firstTile, matching: find.byType(AirSuperiorityPill)),
      findsNothing,
    );
    expect(find.byKey(const Key('land-base-index-pill-1')), findsNothing);
    expect(find.byKey(const Key('land-base-hp-pill-1')), findsNothing);
    final firstName = find.descendant(
      of: firstTile,
      matching: find.text('第一基地航空隊'),
    );
    final firstNameText = tester.widget<Text>(firstName);
    expect(firstNameText.style?.fontSize, 11);
    final firstHpText = find.descendant(
      of: firstTile,
      matching: find.text('200/200（-0）'),
    );
    final firstHpBar = find.descendant(
      of: firstTile,
      matching: find.byType(LinearProgressIndicator),
    );
    expect(
      tester.getCenter(firstName).dy,
      closeTo(
        (tester.getCenter(firstHpText).dy + tester.getCenter(firstHpBar).dy) /
            2,
        4,
      ),
    );
    expect(
      tester.getCenter(firstHpText).dy,
      lessThan(tester.getCenter(firstHpBar).dy),
    );
    expect(
      tester.getRect(firstHpText).left,
      closeTo(tester.getRect(firstHpBar).left, 1),
    );
    final expectedShipStyleHpWidth =
        (tester.getRect(firstTile).width - 18 - 5) * 2 / 5;
    expect(
      tester.getRect(firstHpBar).width,
      closeTo(expectedShipStyleHpWidth, 1),
    );

    for (final state in <(int, String, Color, Color)>[
      (1, '200/200（-0）', Colors.white, yahagiStatusGreen),
      (2, '140/200（-60）', yahagiStatusYellow, yahagiStatusYellow),
      (3, '100/200（-100）', yahagiStatusOrange, yahagiStatusOrange),
      (4, '50/200（-150）', yahagiStatusRed, yahagiStatusRed),
      (5, '0/200（-200）', yahagiStatusZeroHp, yahagiStatusZeroHp),
    ]) {
      final tile = find.byKey(Key('land-base-raid-${state.$1}'));
      final hpText = tester.widget<Text>(
        find.descendant(of: tile, matching: find.text(state.$2)),
      );
      final hpBar = tester.widget<LinearProgressIndicator>(
        find.descendant(
          of: tile,
          matching: find.byType(LinearProgressIndicator),
        ),
      );
      expect(hpText.style?.color, state.$3);
      expect(hpBar.color, state.$4);
    }
    expect(tester.takeException(), isNull);
  });
}
