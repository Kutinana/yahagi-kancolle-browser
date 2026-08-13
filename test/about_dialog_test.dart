import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/settings/about_dialog.dart';
import 'package:yahagi_kancolle_browser/src/settings/about_support_settings_page.dart';

void main() {
  testWidgets('GitHub button directly launches the repository URL', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 700);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    Uri? launchedUri;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AboutContentWidget(
            externalUrlLauncher: (uri) async {
              launchedUri = uri;
              return true;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.textContaining('GitHub'));
    await tester.pump();

    expect(launchedUri, Uri.parse(AboutContentWidget.githubUrl));
  });

  testWidgets('GitHub button reports an external launch failure', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 700);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AboutContentWidget(externalUrlLauncher: (_) async => false),
        ),
      ),
    );

    await tester.tap(find.textContaining('GitHub'));
    await tester.pump();

    expect(find.text('无法打开链接，请检查是否已安装浏览器。'), findsOneWidget);
  });

  testWidgets('about dialog fits a compact landscape viewport', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(820, 560);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AboutContentWidget())),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('about-disclaimer-scroll')), findsOneWidget);
    expect(find.textContaining('1.0.2'), findsOneWidget);
  });

  testWidgets('compact landscape keeps the full about content reachable', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(640, 280);
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: AboutSupportSettingsPage(currentVersion: '1.0.2')),
      ),
    );
    await tester.pumpAndSettle();

    final scroll = find.byType(SingleChildScrollView).first;
    expect(scroll, findsOneWidget);
    expect(tester.getSize(scroll).height, greaterThanOrEqualTo(140));
    await tester.drag(scroll, const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('about-disclaimer-end')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
