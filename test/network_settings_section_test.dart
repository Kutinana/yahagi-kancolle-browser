import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/settings/network_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/network_settings_section.dart';
import 'package:yahagi_kancolle_browser/src/settings/network_settings_store.dart';
import 'package:yahagi_kancolle_browser/src/widgets/top_notice.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('app.yahagi.kancollebrowser/network_proxy');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  Widget app(NetworkSettingsController controller, {VoidCallback? onSuccess}) {
    return MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: TopNoticeHost(
        child: Scaffold(
          body: NetworkSettingsSection(
            controller: controller,
            onApplySuccess: onSuccess ?? () {},
          ),
        ),
      ),
    );
  }

  Future<NetworkSettingsController> createController({
    NetworkSettings settings = const NetworkSettings(),
    Future<dynamic> Function(MethodCall call)? handler,
  }) async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'isProxyOverrideSupported') return true;
      if (call.method == 'getNetworkStatus') {
        return <String, dynamic>{'hasVpn': false, 'hasActiveNetwork': true};
      }
      return handler?.call(call);
    });
    final controller = NetworkSettingsController(store: _MemoryStore(settings));
    await controller.initialize();
    addTearDown(controller.dispose);
    return controller;
  }

  Finder noticeMatching(Finder matching) =>
      find.descendant(of: find.byKey(topNoticeKey), matching: matching);

  testWidgets('network settings omit VPN status row', (tester) async {
    final controller = await createController();

    await tester.pumpWidget(app(controller));
    await tester.pumpAndSettle();

    expect(find.textContaining('VPN 状态'), findsNothing);
    expect(find.textContaining('已检测到活动 VPN'), findsNothing);
    expect(find.textContaining('未检测到活动 VPN'), findsNothing);
  });

  testWidgets('validation failure shows an error notice', (tester) async {
    final controller = await createController(
      settings: const NetworkSettings(mode: NetworkMode.httpProxy, host: ''),
    );
    await tester.pumpWidget(app(controller));

    await tester.tap(find.textContaining('应用设置'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(noticeMatching(find.text('地址不能为空')), findsOneWidget);
    expect(
      noticeMatching(find.byIcon(Icons.error_outline_rounded)),
      findsOneWidget,
    );
  });

  testWidgets('apply shows a one-second neutral notice then success', (
    tester,
  ) async {
    final result = Completer<dynamic>();
    final controller = await createController(handler: (call) => result.future);
    var successCalls = 0;
    await tester.pumpWidget(app(controller, onSuccess: () => successCalls++));

    await tester.tap(find.textContaining('应用设置'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(noticeMatching(find.text('正在应用网络设置…')), findsOneWidget);
    expect(
      noticeMatching(find.byIcon(Icons.info_outline_rounded)),
      findsOneWidget,
    );

    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pump(const Duration(milliseconds: 160));
    expect(find.byKey(topNoticeKey), findsNothing);

    result.complete(<String, dynamic>{
      'success': true,
      'code': 'ok',
      'message': 'done',
      'elapsedMs': 12,
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(noticeMatching(find.text('网络设置应用成功：done')), findsOneWidget);
    expect(
      noticeMatching(find.byIcon(Icons.check_circle_outline_rounded)),
      findsOneWidget,
    );
    expect(successCalls, 1);
  });

  testWidgets('apply failure shows an error notice', (tester) async {
    final controller = await createController(
      handler: (call) async => <String, dynamic>{
        'success': false,
        'code': 'denied',
        'message': 'blocked',
        'elapsedMs': 4,
      },
    );
    await tester.pumpWidget(app(controller));

    await tester.tap(find.textContaining('应用设置'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(noticeMatching(find.text('设置失败 [denied]：blocked')), findsOneWidget);
    expect(
      noticeMatching(find.byIcon(Icons.error_outline_rounded)),
      findsOneWidget,
    );
  });
}

final class _MemoryStore implements NetworkSettingsStore {
  _MemoryStore([this.settings = const NetworkSettings()]);

  NetworkSettings settings;

  @override
  Future<NetworkSettings> loadSettings() async => settings;

  @override
  Future<void> saveSettings(NetworkSettings settings) async {
    this.settings = settings;
  }
}
