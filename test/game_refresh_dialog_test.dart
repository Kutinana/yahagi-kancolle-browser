import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_browser_controller.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_refresh_dialog.dart';

void main() {
  testWidgets('offers POI-aligned full page and game-only reload actions', (
    tester,
  ) async {
    var pageRefreshes = 0;
    var gameReloads = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => showGameRefreshDialog(
                context: context,
                onRefreshPage: () async => pageRefreshes++,
                onReloadGame: () async {
                  gameReloads++;
                  return GameFrameReloadResult.reloaded;
                },
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('确认刷新游戏？'), findsOneWidget);
    expect(find.textContaining('只重新载入游戏框架部分'), findsOneWidget);
    expect(find.byKey(const Key('refresh-full-page')), findsOneWidget);
    expect(find.byKey(const Key('reload-game-frame')), findsOneWidget);

    await tester.tap(find.byKey(const Key('reload-game-frame')));
    await tester.pumpAndSettle();
    expect((pageRefreshes, gameReloads), (0, 1));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('refresh-full-page')));
    await tester.pumpAndSettle();
    expect((pageRefreshes, gameReloads), (1, 1));
  });

  testWidgets('reports when the POI game frame is unavailable', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => showGameRefreshDialog(
                context: context,
                onRefreshPage: () async {},
                onReloadGame: () async =>
                    GameFrameReloadResult.gameFrameNotFound,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('reload-game-frame')));
    await tester.pumpAndSettle();

    expect(find.text('尚未找到游戏框架，请进入游戏后重试。'), findsOneWidget);
  });

  testWidgets('reports a blocked reload when the native command fails', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => showGameRefreshDialog(
                context: context,
                onRefreshPage: () async {},
                onReloadGame: () => Future<GameFrameReloadResult>.error(
                  StateError('native failure'),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('reload-game-frame')));
    await tester.pumpAndSettle();

    expect(find.text('游戏框架未能重新载入，请稍后重试。'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reports when Android WebView cannot inject child frames', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => showGameRefreshDialog(
                context: context,
                onRefreshPage: () async {},
                onReloadGame: () async => GameFrameReloadResult.unsupported,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('reload-game-frame')));
    await tester.pumpAndSettle();

    expect(find.text('当前设备的 Android WebView 太旧，不支持对子框架注入。'), findsOneWidget);
  });
}
