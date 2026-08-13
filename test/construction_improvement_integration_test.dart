import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/improvement/improvement_planner_controller.dart';
import 'package:yahagi_kancolle_browser/src/layout/workspace_context_header.dart';

void main() {
  testWidgets(
    'construction header defaults to construction and switches mode',
    (tester) async {
      var mode = ConstructionCenterMode.construction;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: StatefulBuilder(
            builder: (context, setState) => Scaffold(
              body: WorkspaceContextHeader(
                workspaceIndex: 4,
                state: const GameState(),
                selectedFleetId: 1,
                constructionMode: mode,
                onConstructionModeChanged: (value) =>
                    setState(() => mode = value),
              ),
            ),
          ),
        ),
      );

      final tabs = find.byKey(const Key('construction-mode-tabs'));
      expect(tester.getSize(tabs), const Size(260, 38));
      expect(
        find.byKey(const Key('construction-mode-construction')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('construction-mode-improvement')),
        findsOneWidget,
      );
      expect(mode, ConstructionCenterMode.construction);

      await tester.tap(find.byKey(const Key('construction-mode-improvement')));
      await tester.pump();
      expect(mode, ConstructionCenterMode.improvement);
    },
  );
}
