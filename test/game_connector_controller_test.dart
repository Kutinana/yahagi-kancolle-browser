import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/src/settings/game_connector.dart';
import 'package:yahagi_kancolle_browser/src/settings/game_connector_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test('unknown stored values default to Yahagi', () {
    expect(GameConnectorCodec.decode(null), GameConnector.yahagi);
    expect(GameConnectorCodec.decode('future'), GameConnector.yahagi);
  });

  test('OOI owns only its exact HTTPS login origin', () {
    expect(GameConnector.ooi.entryUri, Uri.parse('https://ooi.moe/'));
    expect(
      GameConnector.ooi.ownsLoginPage(Uri.parse('https://ooi.moe/')),
      isTrue,
    );
    expect(
      GameConnector.ooi.ownsLoginPage(Uri.parse('https://evil.ooi.moe/')),
      isFalse,
    );
    expect(
      GameConnector.ooi.ownsLoginPage(Uri.parse('http://ooi.moe/')),
      isFalse,
    );
    expect(
      GameConnector.ooi.ownsLoginPage(Uri.parse('https://ooi.moe:444/')),
      isFalse,
    );
  });

  test('shared preferences store defaults and round-trips', () async {
    final store = SharedPreferencesGameConnectorStore();

    expect(await store.load(), GameConnector.yahagi);
    await store.save(GameConnector.ooi);
    expect(await store.load(), GameConnector.ooi);
  });

  test('change persists before publishing the new connector', () async {
    final store = MemoryGameConnectorStore();
    final controller = await GameConnectorController.load(store);
    addTearDown(controller.dispose);

    final result = await controller.change(GameConnector.ooi);

    expect(result, GameConnectorChangeResult.applied);
    expect(store.value, GameConnector.ooi);
    expect(controller.connector, GameConnector.ooi);
  });

  test('selecting the active connector does not save', () async {
    final store = _CountingStore(GameConnector.ooi);
    final controller = await GameConnectorController.load(store);
    addTearDown(controller.dispose);

    final result = await controller.change(GameConnector.ooi);

    expect(result, GameConnectorChangeResult.unchanged);
    expect(store.saveCount, 0);
  });

  test('a second request is rejected while saving', () async {
    final store = _BlockingStore();
    final controller = await GameConnectorController.load(store);
    addTearDown(controller.dispose);

    final first = controller.change(GameConnector.ooi);
    await store.started.future;
    final second = await controller.change(GameConnector.ooi);

    expect(second, GameConnectorChangeResult.busy);
    store.release.complete();
    expect(await first, GameConnectorChangeResult.applied);
  });

  test('save failure keeps the active connector', () async {
    final controller = await GameConnectorController.load(_FailingStore());
    addTearDown(controller.dispose);

    final result = await controller.change(GameConnector.ooi);

    expect(result, GameConnectorChangeResult.saveFailed);
    expect(controller.connector, GameConnector.yahagi);
  });
}

final class _CountingStore implements GameConnectorStore {
  _CountingStore(this.value);

  GameConnector value;
  int saveCount = 0;

  @override
  Future<GameConnector> load() async => value;

  @override
  Future<void> save(GameConnector connector) async {
    saveCount += 1;
    value = connector;
  }
}

final class _BlockingStore implements GameConnectorStore {
  final started = Completer<void>();
  final release = Completer<void>();

  @override
  Future<GameConnector> load() async => GameConnector.yahagi;

  @override
  Future<void> save(GameConnector connector) async {
    started.complete();
    await release.future;
  }
}

final class _FailingStore implements GameConnectorStore {
  @override
  Future<GameConnector> load() async => GameConnector.yahagi;

  @override
  Future<void> save(GameConnector connector) async {
    throw StateError('save failed');
  }
}
