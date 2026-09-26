import 'package:yahagi_kancolle_browser/src/layout/hd_dashboard_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/fleet/pre_sortie_check_summary.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_controller.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_store.dart';

void main() {
  testWidgets('extra slot warning only includes unlocked empty slots', (
    tester,
  ) async {
    const state = GameState(
      masterShips: <int, MasterShip>{
        101: MasterShip(id: 101, name: '未开孔', shipTypeId: 2),
        102: MasterShip(id: 102, name: '已开孔为空', shipTypeId: 2),
        103: MasterShip(id: 103, name: '增设已装备', shipTypeId: 2),
      },
      ships: <int, OwnedShip>{
        1001: OwnedShip(id: 1001, masterId: 101, level: 1, extraSlotId: 0),
        1002: OwnedShip(id: 1002, masterId: 102, level: 1, extraSlotId: -1),
        1003: OwnedShip(id: 1003, masterId: 103, level: 1, extraSlotId: 7001),
      },
      fleets: <Fleet>[
        Fleet(id: 1, name: '第1舰队', shipIds: <int>[1001, 1002, 1003]),
      ],
      hasMasterData: true,
      hasPortData: true,
    );
    final controller = GameStateController(gameStateStore: _StaticStore(state));
    addTearDown(controller.dispose);
    await controller.idle;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: PreSortieCheckSummary(
            controller: controller,
            collapsed: false,
            onToggleCollapse: () {},
            onOpenFleet: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('第1舰队 装备缺失（增设槽）：已开孔为空'), findsOneWidget);
    expect(find.textContaining('未开孔'), findsNothing);
    expect(find.textContaining('增设已装备'), findsNothing);
  });

  testWidgets('five warning pills use agreed copy colors and fleet links', (
    tester,
  ) async {
    final state = GameState(
      masterShips: const <int, MasterShip>{
        101: MasterShip(
          id: 101,
          name: '瑞鹤改二甲',
          shipTypeId: 18,
          maxFuel: 100,
          maxAmmo: 100,
          slotCount: 2,
        ),
        102: MasterShip(
          id: 102,
          name: '雪风改',
          shipTypeId: 2,
          maxFuel: 20,
          maxAmmo: 20,
          slotCount: 3,
        ),
      },
      ships: const <int, OwnedShip>{
        1001: OwnedShip(
          id: 1001,
          masterId: 101,
          level: 99,
          currentHp: 2,
          maxHp: 10,
          currentFuel: 50,
          currentAmmo: 50,
          condition: 18,
          slotIds: <int>[7001],
          extraSlotId: 0,
        ),
        1002: OwnedShip(
          id: 1002,
          masterId: 102,
          level: 80,
          currentHp: 30,
          maxHp: 30,
          currentFuel: 20,
          currentAmmo: 20,
          condition: 49,
          slotIds: <int>[7002, 7003],
          extraSlotId: -1,
        ),
      },
      fleets: const <Fleet>[
        Fleet(id: 1, name: '第1舰队', shipIds: <int>[1001, 1002]),
      ],
      hasMasterData: true,
      hasPortData: true,
    );
    final controller = GameStateController(gameStateStore: _StaticStore(state));
    addTearDown(controller.dispose);
    await controller.idle;
    final openedFleetIds = <int>[];

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: PreSortieCheckSummary(
            controller: controller,
            collapsed: false,
            onToggleCollapse: () {},
            onOpenFleet: openedFleetIds.add,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('第1舰队 存在大破舰，停止出击！'), findsOneWidget);
    expect(find.text('第1舰队 舰娘未补给'), findsOneWidget);
    expect(find.text('第1舰队 舰娘疲劳未恢复'), findsOneWidget);
    expect(find.text('第1舰队 装备缺失（主装备槽）：瑞鹤改二甲、雪风改'), findsOneWidget);
    expect(find.text('第1舰队 装备缺失（增设槽）：雪风改'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('第1舰队 舰娘未补给')).style?.fontWeight,
      FontWeight.w700,
    );

    const kinds = <String>[
      'critical',
      'supply',
      'fatigue',
      'main-equipment',
      'extra-equipment',
    ];
    for (final kind in kinds) {
      final warning = find.byKey(Key('pre-sortie-warning-1-$kind'));
      final surface = tester.widget<Material>(
        find.byKey(Key('pre-sortie-warning-surface-1-$kind')),
      );
      final expected = kind == 'critical'
          ? const Color(0xfff44336)
          : const Color(0xffff9800);
      expect(surface.color, expected.withValues(alpha: 0.2));
      final shape = surface.shape! as RoundedRectangleBorder;
      expect(shape.side.color, expected);
      await tester.tap(warning);
    }
    expect(openedFleetIds, <int>[1, 1, 1, 1, 1]);
  });
  testWidgets(
    'HD short warnings share columns while long warnings fill and wrap',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1280, 800);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final state = GameState(
        hasMasterData: true,
        hasPortData: true,
        masterShips: {
          1: MasterShip(
            id: 1,
            name: List.filled(20, '非常长的舰娘名称').join(),
            shipTypeId: 2,
            maxFuel: 100,
            maxAmmo: 100,
            slotCount: 3,
          ),
        },
        ships: const {
          1: OwnedShip(
            id: 1,
            masterId: 1,
            level: 1,
            currentHp: 1,
            maxHp: 20,
            condition: 10,
          ),
        },
        fleets: const [
          Fleet(id: 1, name: '一队', shipIds: [1]),
        ],
      );
      final controller = GameStateController(
        gameStateStore: _StaticStore(state),
      );
      await controller.initialize();
      addTearDown(controller.dispose);
      var opened = 0;
      for (final columns in [2, 3]) {
        for (final scale in [1.0, 1.5]) {
          await tester.pumpWidget(
            MaterialApp(
              locale: const Locale('zh'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: MediaQuery(
                  data: MediaQueryData(
                    textScaler: TextScaler.linear(scale),
                    boldText: true,
                  ),
                  child: SizedBox(
                    width: 1050,
                    child: SingleChildScrollView(
                      child: HdModuleColumns(
                        columns: columns,
                        child: PreSortieCheckSummary(
                          controller: controller,
                          collapsed: false,
                          onToggleCollapse: () {},
                          onOpenFleet: (id) => opened = id,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final supply = tester.getRect(
            find.byKey(const Key('pre-sortie-warning-1-supply')),
          );
          final fatigue = tester.getRect(
            find.byKey(const Key('pre-sortie-warning-1-fatigue')),
          );
          final longItem = find.byKey(
            const Key('pre-sortie-warning-1-main-equipment'),
          );
          final longRect = tester.getRect(longItem);
          expect(
            longRect.width,
            closeTo(supply.width * columns + 8 * (columns - 1), .1),
          );
          expect(supply.width, closeTo(fatigue.width, .1));
          expect(longRect.top, greaterThan(fatigue.bottom));
          expect(longRect.height, greaterThan(supply.height));
          await tester.ensureVisible(longItem);
          await tester.pumpAndSettle();
          opened = 0;
          await tester.tap(longItem);
          expect(opened, 1);
          expect(tester.takeException(), isNull);
        }
      }
    },
  );

  testWidgets(
    'fatigue warning is triggered for both yellow face (30-39) and red face (< 30), but not for >= 40',
    (tester) async {
      Future<void> testCondition(int condition, bool shouldWarn) async {
        final state = GameState(
          hasMasterData: true,
          hasPortData: true,
          masterShips: const {
            1: MasterShip(
              id: 1,
              name: '吹雪',
              shipTypeId: 2,
              maxFuel: 20,
              maxAmmo: 20,
              slotCount: 1,
            ),
          },
          ships: {
            1: OwnedShip(
              id: 1,
              masterId: 1,
              level: 50,
              currentHp: 30,
              maxHp: 30,
              currentFuel: 20,
              currentAmmo: 20,
              condition: condition,
              slotIds: const [101],
              extraSlotId: 0,
            ),
          },
          fleets: const [
            Fleet(id: 1, name: '第1舰队', shipIds: [1]),
          ],
        );
        final controller = GameStateController(
          gameStateStore: _StaticStore(state),
        );
        await controller.initialize();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: PreSortieCheckSummary(
                controller: controller,
                collapsed: false,
                onToggleCollapse: () {},
                onOpenFleet: (_) {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final finder = find.text('第1舰队 舰娘疲劳未恢复');
        if (shouldWarn) {
          expect(
            finder,
            findsOneWidget,
            reason: 'Condition $condition should trigger fatigue warning',
          );
        } else {
          expect(
            finder,
            findsNothing,
            reason: 'Condition $condition should NOT trigger fatigue warning',
          );
        }
      }

      // Red face (< 30)
      await testCondition(20, true);
      await testCondition(29, true);

      // Yellow face (30 - 39)
      await testCondition(30, true);
      await testCondition(35, true);
      await testCondition(39, true);

      // Normal (>= 40)
      await testCondition(40, false);
      await testCondition(49, false);

      // Sparkle (>= 50)
      await testCondition(50, false);
      await testCondition(85, false);
    },
  );
}

class _StaticStore extends GameStateStore {
  _StaticStore(this.value);

  final GameState value;

  @override
  Future<GameState> load() async => value;
}
