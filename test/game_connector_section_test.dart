import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_browser_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/game_connector.dart';
import 'package:yahagi_kancolle_browser/src/settings/game_connector_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/game_connector_section.dart';
import 'package:yahagi_kancolle_browser/src/widgets/top_notice.dart';

void main() {
  Future<
    ({
      GameConnectorController connector,
      _BrowserPort port,
      GameBrowserController browser,
    })
  >
  createState([GameConnector initial = GameConnector.yahagi]) async {
    final connector = await GameConnectorController.load(
      MemoryGameConnectorStore(initial),
    );
    final port = _BrowserPort();
    final browser = GameBrowserController(
      homeUri: initial.entryUri,
      port: port,
    );
    return (connector: connector, port: port, browser: browser);
  }

  Widget app(
    GameConnectorController connector,
    GameBrowserController browser,
  ) => MaterialApp(
    home: TopNoticeHost(
      child: Scaffold(
        body: GameConnectorSection(
          controller: connector,
          browserController: browser,
        ),
      ),
    ),
  );

  testWidgets('shows Yahagi and experimental OOI choices', (tester) async {
    final state = await createState();
    addTearDown(state.connector.dispose);
    addTearDown(state.browser.dispose);

    await tester.pumpWidget(app(state.connector, state.browser));

    expect(find.byKey(const Key('game-connector-yahagi')), findsOneWidget);
    expect(find.byKey(const Key('game-connector-ooi')), findsOneWidget);
    expect(find.textContaining('实验'), findsOneWidget);
  });

  testWidgets('OOI risk confirmation switches and navigates immediately', (
    tester,
  ) async {
    final state = await createState();
    addTearDown(state.connector.dispose);
    addTearDown(state.browser.dispose);
    await tester.pumpWidget(app(state.connector, state.browser));

    await tester.tap(find.byKey(const Key('game-connector-ooi')));
    await tester.pumpAndSettle();

    expect(find.textContaining('第三方'), findsOneWidget);
    expect(find.textContaining('不读取、不保存、不自动填写'), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirm-game-connector-change')));
    await tester.pumpAndSettle();

    expect(state.connector.connector, GameConnector.ooi);
    expect(state.port.loadedUris, <Uri>[GameConnector.ooi.entryUri]);
  });

  testWidgets('active game warning can cancel without changing page', (
    tester,
  ) async {
    final state = await createState(GameConnector.ooi);
    addTearDown(state.connector.dispose);
    addTearDown(state.browser.dispose);
    state.browser.onPageFinished(
      'https://w17k.kancolle-server.com/kcs2/index.html',
    );
    await tester.pumpWidget(app(state.connector, state.browser));

    await tester.tap(find.byKey(const Key('game-connector-yahagi')));
    await tester.pumpAndSettle();

    expect(find.textContaining('中断当前游戏页面'), findsOneWidget);
    await tester.tap(find.byKey(const Key('cancel-game-connector-change')));
    await tester.pumpAndSettle();

    expect(state.connector.connector, GameConnector.ooi);
    expect(state.port.loadedUris, isEmpty);
  });
}

final class _BrowserPort implements GameBrowserPort {
  final List<Uri> loadedUris = <Uri>[];

  @override
  Future<void> loadUri(Uri uri) async => loadedUris.add(uri);

  @override
  Future<bool> canGoBack() async => false;

  @override
  Future<void> clearCache() async {}

  @override
  Future<void> clearSession() async {}

  @override
  Future<void> fitGameScreen() async {}

  @override
  Future<void> goBack() async {}

  @override
  Future<void> reload() async {}

  @override
  Future<GameFrameReloadResult> reloadGameFrame() async =>
      GameFrameReloadResult.reloaded;

  @override
  Future<void> runJavaScript(String javascript) async {}

  @override
  Future<void> showLocalHome() async {}
}
