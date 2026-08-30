import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/external_fleet_tool_launcher.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/fleet_export_page.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/toolbox_page.dart';
import 'package:yahagi_kancolle_browser/src/widgets/top_notice.dart';

void main() {
  testWidgets('ready port data shows an initial DeckBuilder export', (
    tester,
  ) async {
    const state = GameState(
      admiralLevel: 120,
      hasPortData: true,
      ships: <int, OwnedShip>{
        101: OwnedShip(id: 101, masterId: 187, level: 70),
      },
      fleets: <Fleet>[
        Fleet(id: 1, name: 'First', shipIds: <int>[101]),
      ],
    );

    await tester.pumpWidget(_testApp(const ToolboxPage(state: state)));

    expect(find.byType(FleetExportPage), findsOneWidget);
    expect(find.text('导出至 noro6'), findsOneWidget);
    expect(find.text('导出至 Jervis'), findsOneWidget);
    expect(find.text('仅导出活动海域陆航'), findsOneWidget);
    expect(find.textContaining('"version":4'), findsOneWidget);
    expect(find.text('4 支'), findsNothing);
    expect(find.text('18 艘'), findsNothing);
    expect(find.text('3 队'), findsNothing);
  });

  testWidgets('waiting for port data disables external export', (tester) async {
    await tester.pumpWidget(_testApp(const ToolboxPage(state: GameState())));

    expect(find.text('等待母港数据'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('fleet-export-noro6')))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('fleet-export-jervis')))
          .onPressed,
      isNull,
    );
  });

  testWidgets(
    'refresh uses the latest state without overwriting it beforehand',
    (tester) async {
      const oldState = GameState(admiralLevel: 10, hasPortData: true);
      const newState = GameState(admiralLevel: 99, hasPortData: true);

      await tester.pumpWidget(_testApp(const FleetExportPage(state: oldState)));
      expect(find.textContaining('"hqlv":10'), findsOneWidget);

      await tester.pumpWidget(_testApp(const FleetExportPage(state: newState)));
      expect(find.textContaining('"hqlv":10'), findsOneWidget);

      await tester.tap(find.byKey(const Key('refresh-fleet-export')));
      await tester.pump();
      expect(find.textContaining('"hqlv":99'), findsOneWidget);
    },
  );

  testWidgets('first port data replaces the waiting state automatically', (
    tester,
  ) async {
    await tester.pumpWidget(
      _testApp(const FleetExportPage(state: GameState())),
    );
    expect(find.text('等待母港数据'), findsOneWidget);

    await tester.pumpWidget(
      _testApp(
        const FleetExportPage(
          state: GameState(admiralLevel: 77, hasPortData: true),
        ),
      ),
    );

    expect(find.textContaining('"hqlv":77'), findsOneWidget);
  });

  testWidgets('copy writes the current text and reports success', (
    tester,
  ) async {
    String? copied;
    await tester.pumpWidget(
      _testApp(
        FleetExportPage(
          state: const GameState(admiralLevel: 80, hasPortData: true),
          copyText: (text) async => copied = text,
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('copy-fleet-export')));
    await tester.pump();

    expect(copied, contains('"hqlv":80'));
    expect(find.text('舰队导出文本已复制。'), findsOneWidget);
  });

  testWidgets('copy failure is reported without clearing the text', (
    tester,
  ) async {
    await tester.pumpWidget(
      _testApp(
        FleetExportPage(
          state: const GameState(admiralLevel: 81, hasPortData: true),
          copyText: (_) => Future<void>.error(StateError('clipboard failed')),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('copy-fleet-export')));
    await tester.pump();

    expect(find.text('复制失败，请稍后重试。'), findsOneWidget);
    expect(find.textContaining('"hqlv":81'), findsOneWidget);
  });

  testWidgets('external launch regenerates text and keeps it on failure', (
    tester,
  ) async {
    Uri? received;
    await tester.pumpWidget(
      _testApp(
        FleetExportPage(
          state: const GameState(admiralLevel: 88, hasPortData: true),
          launcher: ExternalFleetToolLauncher(
            launch: (uri) async {
              received = uri;
              return false;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('fleet-export-noro6')));
    await tester.pump();

    expect(received?.host, 'noro6.github.io');
    expect(received?.queryParameters['predeck'], contains('"hqlv":88'));
    expect(find.textContaining('"hqlv":88'), findsOneWidget);
    expect(find.text('无法打开外部舰队工具，请检查是否已安装浏览器。'), findsOneWidget);
  });

  testWidgets('other mode shows a development message', (tester) async {
    await tester.pumpWidget(
      _testApp(const ToolboxPage(state: GameState(), mode: ToolboxMode.other)),
    );

    expect(find.byType(FleetExportPage), findsNothing);
    expect(find.text('其他功能正在开发'), findsOneWidget);
  });

  testWidgets('uses two columns in landscape and one column when narrow', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    tester.view.physicalSize = const Size(844, 390);
    await tester.pumpWidget(
      _testApp(
        const FleetExportPage(
          state: GameState(admiralLevel: 120, hasPortData: true),
        ),
      ),
    );
    expect(find.byKey(const Key('fleet-export-two-column')), findsOneWidget);
    expect(tester.takeException(), isNull);

    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('fleet-export-one-column')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Widget _testApp(Widget child) => MaterialApp(
  locale: const Locale('zh'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: TopNoticeHost(child: Scaffold(body: child)),
);
