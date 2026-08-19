import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/settings/game_rendering_mode.dart';
import 'package:yahagi_kancolle_browser/src/settings/game_rendering_mode_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/game_rendering_mode_section.dart';

void main() {
  Future<({GameRenderingModeController controller, _RestartPort port})>
  createController() async {
    final controller = await GameRenderingModeController.load(
      MemoryGameRenderingModeStore(),
    );
    final port = _RestartPort();
    controller.attachRestartPort(port);
    return (controller: controller, port: port);
  }

  Widget app(
    GameRenderingModeController controller, {
    bool isBattleActive = false,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: GameRenderingModeSection(
          controller: controller,
          isBattleActive: isBattleActive,
        ),
      ),
    );
  }

  testWidgets('shows all four rendering modes with native activity first', (
    tester,
  ) async {
    final state = await createController();
    addTearDown(state.controller.dispose);

    await tester.pumpWidget(app(state.controller));

    expect(
      find.byKey(const Key('rendering-mode-native-activity')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('rendering-mode-compatibility')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('rendering-mode-standard')), findsOneWidget);
    expect(find.byKey(const Key('rendering-mode-canvas')), findsOneWidget);

    final nativeActivityTop = tester
        .getTopLeft(find.byKey(const Key('rendering-mode-native-activity')))
        .dy;
    final compatibilityTop = tester
        .getTopLeft(find.byKey(const Key('rendering-mode-compatibility')))
        .dy;
    final standardTop = tester
        .getTopLeft(find.byKey(const Key('rendering-mode-standard')))
        .dy;
    final canvasTop = tester
        .getTopLeft(find.byKey(const Key('rendering-mode-canvas')))
        .dy;
    expect(nativeActivityTop, lessThan(compatibilityTop));
    expect(compatibilityTop, lessThan(standardTop));
    expect(standardTop, lessThan(canvasTop));

    for (final key in const <Key>[
      Key('rendering-mode-native-activity'),
      Key('rendering-mode-compatibility'),
      Key('rendering-mode-standard'),
      Key('rendering-mode-canvas'),
    ]) {
      expect(find.byKey(key), findsOneWidget);
    }

    final titleLefts = <double>[
      for (final key in const <Key>[
        Key('rendering-mode-compatibility'),
        Key('rendering-mode-standard'),
        Key('rendering-mode-canvas'),
        Key('rendering-mode-native-activity'),
      ])
        tester
            .getTopLeft(
              find
                  .descendant(of: find.byKey(key), matching: find.byType(Text))
                  .first,
            )
            .dx,
    ];
    expect(titleLefts[1], titleLefts[0]);
    expect(titleLefts[2], titleLefts[0]);
    expect(titleLefts[3], titleLefts[0]);

    expect(find.text('均衡模式（推荐）'), findsOneWidget);
    expect(find.text('轻量模式'), findsOneWidget);
    expect(find.text('兼容模式'), findsOneWidget);
    expect(find.text('原生直连（推荐）'), findsOneWidget);
    expect(find.textContaining('兼顾游戏性能与设备兼容性'), findsOneWidget);
    expect(find.textContaining('减少部分合成开销'), findsOneWidget);
    expect(find.textContaining('更低的合成开销'), findsOneWidget);
    expect(find.textContaining('华为'), findsNothing);
    expect(find.textContaining('荣耀'), findsNothing);
  });

  testWidgets('native activity mode is hidden on non-Android platforms', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      final state = await createController();
      addTearDown(state.controller.dispose);

      await tester.pumpWidget(app(state.controller));

      expect(
        find.byKey(const Key('rendering-mode-native-activity')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('rendering-mode-compatibility')),
        findsOneWidget,
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('cancel keeps the current mode', (tester) async {
    final state = await createController();
    addTearDown(state.controller.dispose);
    await tester.pumpWidget(app(state.controller));

    await tester.tap(find.byKey(const Key('rendering-mode-standard')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('rendering-mode-confirm-dialog')),
      findsOneWidget,
    );
    expect(find.textContaining('自动重启应用'), findsOneWidget);
    await tester.tap(find.byKey(const Key('rendering-mode-cancel')));
    await tester.pumpAndSettle();

    expect(state.controller.mode, GameRenderingMode.compatibility);
    expect(state.port.modes, isEmpty);
  });

  testWidgets('confirm rebuilds using the selected mode', (tester) async {
    final state = await createController();
    addTearDown(state.controller.dispose);
    await tester.pumpWidget(app(state.controller));

    await tester.tap(find.byKey(const Key('rendering-mode-standard')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('rendering-mode-confirm')));
    await tester.pumpAndSettle();

    expect(state.controller.mode, GameRenderingMode.standard);
    expect(state.port.modes, [GameRenderingMode.standard]);
  });

  testWidgets('battle state adds a stronger warning', (tester) async {
    final state = await createController();
    addTearDown(state.controller.dispose);
    await tester.pumpWidget(app(state.controller, isBattleActive: true));

    await tester.tap(find.byKey(const Key('rendering-mode-canvas')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('rendering-mode-battle-warning')),
      findsOneWidget,
    );
  });

  testWidgets('busy state disables additional changes', (tester) async {
    final state = await createController();
    addTearDown(state.controller.dispose);
    state.port.blockNextRestart = true;
    await tester.pumpWidget(app(state.controller));

    await tester.tap(find.byKey(const Key('rendering-mode-standard')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('rendering-mode-confirm')));
    await tester.pump();

    expect(find.byKey(const Key('rendering-mode-progress')), findsOneWidget);
    final canvasTile = tester.widget<InkWell>(
      find.byKey(const Key('rendering-mode-canvas')),
    );
    expect(canvasTile.onTap, isNull);

    state.port.completeRestart();
    await tester.pumpAndSettle();
  });
}

final class _RestartPort implements GameEnvironmentRestartPort {
  final modes = <GameRenderingMode>[];
  bool blockNextRestart = false;
  Completer<void>? _restartCompleter;

  @override
  Future<void> restart(GameRenderingMode mode) async {
    modes.add(mode);
    if (!blockNextRestart) return;
    blockNextRestart = false;
    _restartCompleter = Completer<void>();
    await _restartCompleter!.future;
  }

  void completeRestart() => _restartCompleter?.complete();
}
