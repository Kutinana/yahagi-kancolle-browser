import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/main.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_application_restart_port.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_environment_host.dart';
import 'package:yahagi_kancolle_browser/src/settings/game_rendering_mode.dart';
import 'package:yahagi_kancolle_browser/src/settings/game_rendering_mode_controller.dart';

void main() {
  testWidgets('selects the native surface only for the activity mode', (
    tester,
  ) async {
    for (final mode in GameRenderingMode.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: buildGameSurfaceForRenderingMode(
            mode: mode,
            key: ValueKey<String>(mode.storageName),
            buildNativeActivityGameSurface: (key) => SizedBox(
              key: const Key('native-surface'),
              child: Text('native-${key.toString()}'),
            ),
            buildGameWebView: (key, renderingMode) => SizedBox(
              key: const Key('flutter-webview'),
              child: Text('webview-${renderingMode.storageName}'),
            ),
            withBattleWarning: (child) => _BattleWarningProbe(child: child),
          ),
        ),
      );

      expect(find.byType(_BattleWarningProbe), findsOneWidget);
      if (mode == GameRenderingMode.nativeActivityExperimental) {
        expect(find.byKey(const Key('native-surface')), findsOneWidget);
        expect(find.byKey(const Key('flutter-webview')), findsNothing);
      } else {
        expect(find.byKey(const Key('native-surface')), findsNothing);
        expect(find.byKey(const Key('flutter-webview')), findsOneWidget);
      }
    }
  });

  testWidgets('restart removes the game before requesting an app restart', (
    tester,
  ) async {
    final controller = await GameRenderingModeController.load(
      MemoryGameRenderingModeStore(),
    );
    addTearDown(controller.dispose);
    var beforeRestartCalls = 0;
    final applicationRestartPort = _RecordingApplicationRestartPort();

    await tester.pumpWidget(
      MaterialApp(
        home: GameEnvironmentHost(
          controller: controller,
          beforeRestart: () async => beforeRestartCalls += 1,
          applicationRestartPort: applicationRestartPort,
          gameBuilder: (context, mode, key) => ColoredBox(
            key: key,
            color: Colors.black,
            child: Text('game-${mode.storageName}'),
          ),
        ),
      ),
    );

    expect(find.text('game-compatibility'), findsOneWidget);

    final changing = controller.changeMode(GameRenderingMode.standard);
    await tester.pump();

    expect(find.text('game-standard'), findsNothing);
    expect(find.text('game-compatibility'), findsNothing);
    expect(
      find.byKey(const Key('game-environment-restarting')),
      findsOneWidget,
    );

    await tester.pump();
    expect((await changing).status, GameRenderingModeChangeStatus.applied);
    expect(beforeRestartCalls, 1);
    expect(applicationRestartPort.calls, 1);
    expect(find.textContaining('game-'), findsNothing);
  });

  testWidgets('host keeps exactly one game after repeated sequential changes', (
    tester,
  ) async {
    final controller = await GameRenderingModeController.load(
      MemoryGameRenderingModeStore(),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: GameEnvironmentHost(
          controller: controller,
          gameBuilder: (context, mode, key) =>
              SizedBox(key: key, child: Text('game-${mode.storageName}')),
        ),
      ),
    );

    for (final mode in <GameRenderingMode>[
      GameRenderingMode.standard,
      GameRenderingMode.canvasCompatibility,
      GameRenderingMode.nativeActivityExperimental,
      GameRenderingMode.compatibility,
    ]) {
      final changing = controller.changeMode(mode);
      await tester.pump();
      expect(find.textContaining('game-'), findsNothing);
      await tester.pump();
      await changing;
      expect(find.text('game-${mode.storageName}'), findsOneWidget);
    }
  });

  testWidgets('disposing the host detaches its restart port', (tester) async {
    final controller = await GameRenderingModeController.load(
      MemoryGameRenderingModeStore(),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: GameEnvironmentHost(
          controller: controller,
          gameBuilder: (context, mode, key) => SizedBox(key: key),
        ),
      ),
    );
    await tester.pumpWidget(const SizedBox());

    final result = await controller.changeMode(GameRenderingMode.standard);
    expect(result.status, GameRenderingModeChangeStatus.unavailable);
  });
}

final class _BattleWarningProbe extends StatelessWidget {
  const _BattleWarningProbe({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

final class _RecordingApplicationRestartPort
    implements GameApplicationRestartPort {
  int calls = 0;

  @override
  Future<void> restartApplication() async => calls += 1;
}
