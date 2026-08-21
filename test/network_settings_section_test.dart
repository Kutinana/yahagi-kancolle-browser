import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/settings/network_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/network_settings_section.dart';
import 'package:yahagi_kancolle_browser/src/settings/network_settings_store.dart';

void main() {
  testWidgets('network settings omit VPN status row', (tester) async {
    final controller = NetworkSettingsController(store: _MemoryStore());

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NetworkSettingsSection(
            controller: controller,
            onApplySuccess: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('VPN 状态'), findsNothing);
    expect(find.textContaining('已检测到活动 VPN'), findsNothing);
    expect(find.textContaining('未检测到活动 VPN'), findsNothing);
  });

  testWidgets('代理地址和端口在同一独立弹窗中编辑', (tester) async {
    const channel = MethodChannel('app.yahagi.kancollebrowser/network_proxy');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (call) async => switch (call.method) {
        'isProxyOverrideSupported' => true,
        'getNetworkStatus' => <String, dynamic>{
          'hasVpn': false,
          'hasActiveNetwork': true,
        },
        _ => null,
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    final controller = NetworkSettingsController(
      store: _MemoryStore(
        settings: const NetworkSettings(
          mode: NetworkMode.httpProxy,
          host: '127.0.0.1',
          port: 8080,
        ),
      ),
    );
    await controller.initialize();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          resizeToAvoidBottomInset: false,
          body: NetworkSettingsSection(
            controller: controller,
            onApplySuccess: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.byKey(const Key('network-proxy-input')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('network-proxy-input-dialog')), findsOneWidget);
    expect(find.byKey(const Key('network-proxy-host-field')), findsOneWidget);
    expect(find.byKey(const Key('network-proxy-port-field')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('network-proxy-host-field')),
      '192.168.1.8',
    );
    await tester.enterText(
      find.byKey(const Key('network-proxy-port-field')),
      '1080',
    );
    await tester.tap(find.byKey(const Key('network-proxy-input-confirm')));
    await tester.pumpAndSettle();

    expect(find.text('192.168.1.8'), findsOneWidget);
    expect(find.text('1080'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('横屏键盘弹出后代理输入弹窗可滚动且不溢出', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(844, 390);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetViewInsets);
    const channel = MethodChannel('app.yahagi.kancollebrowser/network_proxy');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (call) async => switch (call.method) {
        'isProxyOverrideSupported' => true,
        'getNetworkStatus' => <String, dynamic>{
          'hasVpn': false,
          'hasActiveNetwork': true,
        },
        _ => null,
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    final controller = NetworkSettingsController(
      store: _MemoryStore(
        settings: const NetworkSettings(
          mode: NetworkMode.httpProxy,
          host: '127.0.0.1',
          port: 8080,
        ),
      ),
    );
    await controller.initialize();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          resizeToAvoidBottomInset: false,
          body: SingleChildScrollView(
            child: NetworkSettingsSection(
              controller: controller,
              onApplySuccess: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('network-proxy-input')));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 230);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final confirm = find.byKey(const Key('network-proxy-input-confirm'));
    expect(confirm, findsOneWidget);
    expect(tester.getRect(confirm).bottom, lessThanOrEqualTo(160));
  });
}

final class _MemoryStore implements NetworkSettingsStore {
  _MemoryStore({this.settings = const NetworkSettings()});

  final NetworkSettings settings;

  @override
  Future<NetworkSettings> loadSettings() async => settings;

  @override
  Future<void> saveSettings(NetworkSettings settings) async {}
}
