import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/main.dart';
import 'package:yahagi_kancolle_browser/src/audio/game_audio_controller.dart';
import 'package:yahagi_kancolle_browser/src/audio/game_audio_store.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_controller.dart';
import 'package:yahagi_kancolle_browser/src/browser/gadget_bypass_controller.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_browser_controller.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_toolbar_controller.dart';
import 'package:yahagi_kancolle_browser/src/capture/capture_mode.dart';
import 'package:yahagi_kancolle_browser/src/capture/capture_mode_controller.dart';
import 'package:yahagi_kancolle_browser/src/capture/capture_mode_store.dart';
import 'package:yahagi_kancolle_browser/src/capture/game_capture_controller.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_controller.dart';
import 'package:yahagi_kancolle_browser/src/prototype_status_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/display_mode_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/display_mode_store.dart';
import 'package:yahagi_kancolle_browser/src/settings/header_resource_settings.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_store.dart';
import 'package:yahagi_kancolle_browser/src/settings/network_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/safety_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/widgets/top_notice.dart';

Map<String, String> collectBusinessDartSources(Directory projectRoot) {
  final rootPath = projectRoot.absolute.path;
  final files = <File>[
    File(
      '$rootPath${Platform.pathSeparator}lib${Platform.pathSeparator}main.dart',
    ),
    ...Directory(
          '$rootPath${Platform.pathSeparator}lib${Platform.pathSeparator}src',
        )
        .listSync(recursive: true, followLinks: false)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart')),
  ]..sort((a, b) => a.path.compareTo(b.path));

  return <String, String>{
    for (final file in files)
      file.absolute.path.substring(rootPath.length + 1).replaceAll(r'\', '/'):
          file.readAsStringSync(),
  };
}

List<String> findForbiddenBottomNoticeUsages(Map<String, String> sources) {
  final violations = <String>[];
  final entries = sources.entries.toList()
    ..sort(
      (a, b) =>
          a.key.replaceAll(r'\', '/').compareTo(b.key.replaceAll(r'\', '/')),
    );
  final forbiddenIdentifier = RegExp(r'\b(?:SnackBar|ScaffoldMessenger)\b');

  for (final entry in entries) {
    final path = entry.key.replaceAll(r'\', '/');
    final lines = entry.value.split('\n');
    for (var index = 0; index < lines.length; index++) {
      final source = lines[index].replaceFirst(RegExp(r'\r$'), '');
      if (forbiddenIdentifier.hasMatch(source)) {
        violations.add('$path:${index + 1}:$source');
      }
    }
  }

  return violations;
}

void main() {
  test('business Dart sources use TopNotice instead of bottom notices', () {
    final violations = findForbiddenBottomNoticeUsages(
      collectBusinessDartSources(Directory.current),
    );

    expect(
      violations,
      isEmpty,
      reason:
          'Business source must use TopNotice.show instead of SnackBar or '
          'ScaffoldMessenger.\n${violations.join('\n')}',
    );
  });

  test(
    'bottom notice detector reports normalized locations in stable order',
    () {
      final violations = findForbiddenBottomNoticeUsages(<String, String>{
        r'lib\src\z.dart': 'void z() { ScaffoldMessenger.of(context); }',
        'lib/src/a.dart': '''
void a() {
  const notice = SnackBar(content: Text('message'));
  TopNotice.show('allowed');
}
''',
      });

      expect(violations, <String>[
        "lib/src/a.dart:2:  const notice = SnackBar(content: Text('message'));",
        'lib/src/z.dart:1:void z() { ScaffoldMessenger.of(context); }',
      ]);
    },
  );

  test('app mounts exactly one TopNoticeHost at MaterialApp home', () {
    final source = File('lib/main.dart').readAsStringSync();

    expect(RegExp(r'home:\s*TopNoticeHost\(').allMatches(source), hasLength(1));
    expect(RegExp(r'\bTopNoticeHost\s*\(').allMatches(source), hasLength(1));
  });

  testWidgets('YahagiApp exposes one TopNoticeHost directly as home', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 700);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    GameStateController.disableTimerForTest = true;
    addTearDown(() => GameStateController.disableTimerForTest = false);
    final layoutSettingsController = _LayoutSettingsControllerStub();
    final networkSettingsController = _NetworkSettingsControllerStub();
    final gadgetBypassController = _GadgetBypassControllerStub();
    final safetySettingsController = _SafetySettingsControllerStub();
    final displayModeController = _DisplayModeControllerStub();
    final controller = PrototypeStatusController();
    final browserController = GameBrowserController();
    final captureModeController = await CaptureModeController.load(
      _MemoryCaptureModeStore(),
    );
    final audioController = await GameAudioController.load(_MemoryAudioStore());
    final toolbarController = GameToolbarController();
    final gameCaptureController = GameCaptureController();
    final gameStateController = GameStateController();
    final battleController = BattleController(
      gameState: () => gameStateController.state,
    );
    addTearDown(layoutSettingsController.dispose);
    addTearDown(networkSettingsController.dispose);
    addTearDown(gadgetBypassController.dispose);
    addTearDown(safetySettingsController.dispose);
    addTearDown(displayModeController.dispose);
    addTearDown(controller.dispose);
    addTearDown(browserController.dispose);
    addTearDown(captureModeController.dispose);
    addTearDown(audioController.dispose);
    addTearDown(toolbarController.dispose);
    addTearDown(gameCaptureController.dispose);
    addTearDown(gameStateController.dispose);
    addTearDown(battleController.dispose);
    addTearDown(() async => tester.pumpWidget(const SizedBox()));

    await tester.pumpWidget(
      YahagiApp(
        layoutSettingsController: layoutSettingsController,
        networkSettingsController: networkSettingsController,
        gadgetBypassController: gadgetBypassController,
        safetySettingsController: safetySettingsController,
        displayModeController: displayModeController,
        controller: controller,
        browserController: browserController,
        captureModeController: captureModeController,
        audioController: audioController,
        toolbarController: toolbarController,
        gameCaptureController: gameCaptureController,
        gameStateController: gameStateController,
        battleController: battleController,
        gameSurface: const SizedBox(),
      ),
    );

    expect(find.byType(TopNoticeHost, skipOffstage: false), findsOneWidget);
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).home,
      isA<TopNoticeHost>(),
    );
  });
}

class _LayoutSettingsControllerStub extends ChangeNotifier
    implements LayoutSettingsController {
  @override
  bool get autoZoom => false;

  @override
  List<String> get dashboardCardCollapsed => const <String>[];

  @override
  List<String> get dashboardCardHidden => const <String>[];

  @override
  List<String> get dashboardCardOrder => const <String>[];

  @override
  bool get enhancedDamagePulse => false;

  @override
  String get fontFamily => 'sans-serif';

  @override
  List<String> get fontFamilyFallback => const <String>[];

  @override
  double get gameAreaRatio => 0.65;

  @override
  List<String> get headerResourceOrder => allHeaderResourceIds;

  @override
  String? get localeCode => null;

  @override
  List<String> get visibleHeaderResourceIds => defaultVisibleHeaderResourceIds;

  @override
  List<String> get workspaceMenuOrder =>
      LayoutSettingsStore.defaultWorkspaceMenuOrder;

  @override
  bool get workspaceMenuOnRight => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => _unexpected(invocation);
}

class _NetworkSettingsControllerStub extends ChangeNotifier
    implements NetworkSettingsController {
  @override
  dynamic noSuchMethod(Invocation invocation) => _unexpected(invocation);
}

class _GadgetBypassControllerStub extends ChangeNotifier
    implements GadgetBypassController {
  @override
  dynamic noSuchMethod(Invocation invocation) => _unexpected(invocation);
}

class _SafetySettingsControllerStub extends ChangeNotifier
    implements SafetySettingsController {
  @override
  bool get battleDamageVibrationEnabled => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => _unexpected(invocation);
}

class _DisplayModeControllerStub extends ChangeNotifier
    implements DisplayModeController {
  @override
  DisplayMode get displayMode => DisplayMode.auto;

  @override
  dynamic noSuchMethod(Invocation invocation) => _unexpected(invocation);
}

Never _unexpected(Invocation invocation) {
  throw UnsupportedError('Unexpected invocation: ${invocation.memberName}');
}

class _MemoryCaptureModeStore implements CaptureModeStore {
  @override
  Future<CaptureMode?> read() async => null;

  @override
  Future<void> write(CaptureMode mode) async {}
}

class _MemoryAudioStore implements GameAudioStore {
  @override
  Future<bool?> readBackgroundPlaybackEnabled() async => null;

  @override
  Future<bool?> readMuted() async => null;

  @override
  Future<void> writeBackgroundPlaybackEnabled(bool enabled) async {}

  @override
  Future<void> writeMuted(bool muted) async {}
}
