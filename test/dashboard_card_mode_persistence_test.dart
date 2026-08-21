import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_controller.dart';
import 'package:yahagi_kancolle_browser/src/battle/live_battle_card.dart';
import 'package:yahagi_kancolle_browser/src/fleet/pre_sortie_check_summary.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_controller.dart';

void main() {
  testWidgets('主页卡片重建后各自恢复显示模式', (tester) async {
    final bucket = PageStorageBucket();
    final gameStateController = GameStateController();
    final battleController = BattleController(
      gameState: () => gameStateController.state,
    );
    addTearDown(gameStateController.dispose);
    addTearDown(battleController.dispose);
    await gameStateController.idle;

    Future<void> pump(Widget child) => tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: PageStorage(
          bucket: bucket,
          child: Scaffold(body: child),
        ),
      ),
    );

    await pump(
      LiveBattleCard(
        key: const PageStorageKey('dashboard-live-battle'),
        controller: battleController,
        collapsed: false,
        onToggleCollapse: () {},
      ),
    );

    await tester.tap(find.byKey(const Key('battle-mode-compact')));
    await tester.pump();
    expect(_buttonColor(tester, 'battle-mode-compact'), _selectedColor);

    await pump(
      PreSortieCheckSummary(
        key: const PageStorageKey('dashboard-pre-sortie'),
        controller: gameStateController,
        collapsed: false,
        onToggleCollapse: () {},
        onOpenFleet: (_) {},
      ),
    );
    await tester.tap(find.byKey(const Key('sortie-check-mode-maps')));
    await tester.pump();
    expect(_buttonColor(tester, 'sortie-check-mode-maps'), _selectedColor);

    await pump(
      LiveBattleCard(
        key: const PageStorageKey('dashboard-live-battle'),
        controller: battleController,
        collapsed: false,
        onToggleCollapse: () {},
      ),
    );
    expect(_buttonColor(tester, 'battle-mode-compact'), _selectedColor);

    await pump(
      PreSortieCheckSummary(
        key: const PageStorageKey('dashboard-pre-sortie'),
        controller: gameStateController,
        collapsed: false,
        onToggleCollapse: () {},
        onOpenFleet: (_) {},
      ),
    );
    expect(_buttonColor(tester, 'sortie-check-mode-maps'), _selectedColor);
  });
}

const _selectedColor = Color(0xff5b4829);

Color? _buttonColor(WidgetTester tester, String key) {
  final material = find.descendant(
    of: find.byKey(Key(key)),
    matching: find.byType(Material),
  );
  return tester.widget<Material>(material.first).color;
}
