import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/src/fleet/resource_grid.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_store.dart';

void main() {
  test('formats anchorage repair elapsed time for the header capsule', () {
    final startedAt = DateTime.utc(2026, 8, 11, 1, 2, 3);

    expect(
      formatAnchorageRepairElapsed(
        startedAt,
        DateTime.utc(2026, 8, 11, 14, 7, 9),
      ),
      '13:05:06',
    );
    expect(
      formatAnchorageRepairElapsed(null, DateTime.utc(2026, 8, 11)),
      '--:--:--',
    );
    expect(
      formatAnchorageRepairElapsed(
        startedAt,
        DateTime.utc(2026, 8, 11, 1, 2, 2),
      ),
      '00:00:00',
    );
  });

  test('formats nosaki sparkle elapsed time for the header capsule', () {
    final startedAt = DateTime.utc(2026, 8, 11, 1, 2, 3);

    expect(
      formatNosakiSparkleElapsed(
        startedAt,
        DateTime.utc(2026, 8, 11, 14, 7, 9),
      ),
      '13:05:06',
    );
    expect(
      formatNosakiSparkleElapsed(null, DateTime.utc(2026, 8, 11)),
      '--:--:--',
    );
    expect(
      formatNosakiSparkleElapsed(startedAt, DateTime.utc(2026, 8, 11, 1, 2, 2)),
      '00:00:00',
    );
  });

  testWidgets('narrow header keeps the empty senka capsule visible', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 200,
              child: CompactResourceBar(state: GameState()),
            ),
          ),
        ),
      ),
    );

    expect(find.text('战果：--（#--）'), findsOneWidget);
    expect(find.text('泊地：--:--:--'), findsOneWidget);
    expect(
      find.byKey(const Key('header-anchorage-timer-summary')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('header renders nosaki capsule with empty timer', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 500,
              child: CompactResourceBar(state: GameState()),
            ),
          ),
        ),
      ),
    );

    expect(find.text('野埼：--:--:--'), findsOneWidget);
    expect(
      find.byKey(const Key('header-nosaki-timer-summary')),
      findsOneWidget,
    );
  });

  testWidgets('anchorage capsule invokes tap without breaking long press', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CompactResourceBar(
            state: const GameState(),
            onAnchorageTimerTap: () => taps++,
          ),
        ),
      ),
    );

    final timer = find.byKey(const Key('header-resource-anchorage-timer'));
    await tester.tap(timer);
    await tester.pump();
    expect(taps, 1);

    await tester.longPress(timer);
    await tester.pumpAndSettle();
    expect(taps, 1);
    expect(find.byKey(const Key('header-resource-edit-mode')), findsOneWidget);
  });

  testWidgets('nosaki capsule invokes tap without breaking long press', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CompactResourceBar(
            state: const GameState(),
            onNosakiTimerTap: () => taps++,
          ),
        ),
      ),
    );

    final timer = find.byKey(const Key('header-resource-nosaki-timer'));
    await tester.tap(timer);
    await tester.pump();
    expect(taps, 1);

    await tester.longPress(timer);
    await tester.pumpAndSettle();
    expect(taps, 1);
    expect(find.byKey(const Key('header-resource-edit-mode')), findsOneWidget);
  });

  testWidgets('starts at the leading edge and long press enters edit mode', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final controller = await LayoutSettingsController.load(
      SharedPreferencesLayoutSettingsStore(),
    );
    const state = GameState(
      resources: <GameResourceType, int>{GameResourceType.fuel: 12345},
    );
    var senkaTapCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(padding: EdgeInsets.only(left: 48)),
            child: Padding(
              padding: const EdgeInsets.only(top: 100),
              child: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 600,
                  child: CompactResourceBar(
                    state: state,
                    senka: 1120,
                    rank: 370,
                    settingsController: controller,
                    onSenkaTap: () => senkaTapCount += 1,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final senka = find.byKey(const Key('header-senka-summary'));
    expect(senka, findsOneWidget);
    expect(find.text('战果：1120（#370）'), findsOneWidget);
    expect(tester.getTopLeft(senka).dx, 0);
    final senkaDecoration =
        tester.widget<Container>(senka).decoration! as BoxDecoration;
    final senkaBorder = senkaDecoration.border! as Border;
    expect(senkaBorder.top.color, const Color(0xff315064));

    final first = find.byKey(const Key('header-resource-ship-capacity'));
    expect(first, findsOneWidget);
    expect(
      find.byKey(const Key('header-resource-anchorage-timer')),
      findsOneWidget,
    );
    expect(
      tester.getTopLeft(first).dx,
      greaterThan(tester.getRect(senka).right),
    );
    expect(find.byKey(const Key('header-resource-useitem-68')), findsNothing);

    await tester.tap(find.byKey(const Key('header-resource-senka')));
    await tester.pump();
    expect(senkaTapCount, 1);
    await tester.tap(first);
    await tester.pump();
    expect(senkaTapCount, 1);

    await tester.longPress(senka);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('header-resource-edit-mode')), findsOneWidget);
    expect(find.byKey(const Key('header-resource-filter')), findsOneWidget);
    final resetX = tester
        .getTopLeft(find.byKey(const Key('header-resource-reset')))
        .dx;
    final doneX = tester
        .getTopLeft(find.byKey(const Key('header-resource-edit-done')))
        .dx;
    final filterX = tester
        .getTopLeft(find.byKey(const Key('header-resource-filter')))
        .dx;
    expect(resetX, lessThan(doneX));
    expect(doneX, lessThan(filterX));
    expect(find.byType(Checkbox), findsNothing);
    expect(find.byIcon(Icons.drag_indicator_rounded), findsNothing);

    await tester.tap(find.byKey(const Key('header-resource-filter')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('header-resource-filter-list')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('header-resource-filter-row-senka')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('header-resource-visible-senka')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('header-resource-filter-row-anchorage-timer')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('header-resource-visible-anchorage-timer')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('header-resource-filter-row-ship-capacity')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('header-resource-visible-ship-capacity')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('header-resource-filter-row-equipment-capacity')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('header-resource-visible-equipment-capacity')),
      findsOneWidget,
    );
    final firstFilterRow = find.byKey(
      const Key('header-resource-filter-row-material-1'),
    );
    final secondFilterRow = find.byKey(
      const Key('header-resource-filter-row-material-2'),
    );
    expect(
      tester.getTopLeft(firstFilterRow).dx,
      tester.getTopLeft(secondFilterRow).dx,
    );
    expect(
      tester.getTopLeft(secondFilterRow).dy,
      greaterThan(tester.getTopLeft(firstFilterRow).dy),
    );
    expect(
      find.byKey(const Key('header-resource-visible-material-1')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('header-resource-visible-senka')));
    await tester.pump();
    await tester.tap(
      find.byKey(const Key('header-resource-visible-ship-capacity')),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('header-resource-filter-done')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('header-resource-edit-done')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('header-senka-summary')), findsNothing);
    expect(find.byKey(const Key('header-ship-capacity')), findsNothing);
    expect(find.byKey(const Key('header-resource-material-1')), findsOneWidget);
    expect(find.byKey(const Key('header-resource-material-2')), findsOneWidget);
  });

  testWidgets('header shows --:--:-- when Akashi or Nozaki are damaged or unsupplied', (tester) async {
    final startedAt = DateTime.utc(2026, 8, 20, 10);
    // Damaged Akashi (hp 10/45 <= 50%) and damaged Nozaki (hp 30/48 < max)
    const damagedState = GameState(
      fleets: <Fleet>[
        Fleet(id: 1, name: '第一舰队', shipIds: <int>[1, 2]),
      ],
      ships: <int, OwnedShip>{
        1: OwnedShip(id: 1, masterId: 187, level: 80, currentHp: 10, maxHp: 45), // Akashi heavy damage
        2: OwnedShip(id: 2, masterId: 602, level: 80, currentHp: 30, maxHp: 48, currentFuel: 100, currentAmmo: 100), // Nozaki damaged
      },
      masterShips: <int, MasterShip>{
        187: MasterShip(id: 187, name: '明石改', shipTypeId: 19),
        602: MasterShip(id: 602, name: '野埼改', shipTypeId: 19, maxFuel: 100, maxAmmo: 100),
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CompactResourceBar(
            state: damagedState,
            anchorageRepairStartedAt: startedAt,
            nosakiSparkleStartedAt: startedAt,
          ),
        ),
      ),
    );

    expect(find.text('泊地：--:--:--'), findsOneWidget);
    expect(find.text('野埼：--:--:--'), findsOneWidget);
  });

  testWidgets('header shows active elapsed time when Akashi and Nozaki are ready', (tester) async {
    final startedAt = DateTime.now().toUtc().subtract(const Duration(minutes: 10));
    const readyState = GameState(
      fleets: <Fleet>[
        Fleet(id: 1, name: '第一舰队', shipIds: <int>[1, 2]),
      ],
      ships: <int, OwnedShip>{
        1: OwnedShip(id: 1, masterId: 187, level: 80, currentHp: 45, maxHp: 45),
        2: OwnedShip(id: 2, masterId: 602, level: 80, currentHp: 48, maxHp: 48, currentFuel: 100, currentAmmo: 100, condition: 49),
      },
      masterShips: <int, MasterShip>{
        187: MasterShip(id: 187, name: '明石改', shipTypeId: 19),
        602: MasterShip(id: 602, name: '野埼改', shipTypeId: 19, maxFuel: 100, maxAmmo: 100),
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CompactResourceBar(
            state: readyState,
            anchorageRepairStartedAt: startedAt,
            nosakiSparkleStartedAt: startedAt,
          ),
        ),
      ),
    );

    expect(find.text('泊地：--:--:--'), findsNothing);
    expect(find.text('野埼：--:--:--'), findsNothing);
    expect(find.textContaining('泊地：00:10:'), findsOneWidget);
    expect(find.textContaining('野埼：00:10:'), findsOneWidget);
  });
}
