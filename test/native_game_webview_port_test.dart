import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/browser/native_game_webview_contract.dart';
import 'package:yahagi_kancolle_browser/src/browser/native_game_webview_port.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('test/native_game_webview');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('uses the fixed platform channel names', () {
    expect(
      nativeGameWebViewMethodChannelName,
      'app.yahagi.kancollebrowser/native_game_webview',
    );
    expect(
      nativeGameWebViewEventChannelName,
      'app.yahagi.kancollebrowser/native_game_webview_events',
    );
  });

  test(
    'creates a webgl host and sends every generation-scoped command',
    () async {
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        if (call.method == 'create') return 7;
        if (call.method == 'canGoBack') return true;
        return null;
      });
      final events = StreamController<Object?>.broadcast();
      final port = MethodChannelNativeGameWebViewPort(
        channel: channel,
        eventStream: events.stream,
      );
      addTearDown(events.close);
      addTearDown(port.dispose);

      expect(await port.create(), 7);
      await port.setBounds(
        NativeGameWebViewBounds(
          left: 1,
          top: 2,
          width: 3,
          height: 4,
          devicePixelRatio: 2,
        ),
      );
      await port.setVisible(true);
      await port.loadUri(Uri.parse('https://www.dmm.com/game'));
      await port.showLocalHome();
      await port.reload();
      expect(await port.canGoBack(), isTrue);
      await port.goBack();
      await port.runJavaScript('window.test()');
      await port.fitGameScreen();
      await port.clearCache();
      await port.clearSession();

      expect(calls.map((call) => call.method), <String>[
        'create',
        'setBounds',
        'setVisible',
        'loadUri',
        'showLocalHome',
        'reload',
        'canGoBack',
        'goBack',
        'runJavaScript',
        'fitGameScreen',
        'clearCache',
        'clearSession',
      ]);
      expect(calls[0].arguments, <String, Object?>{'renderer': 'webgl'});
      expect(calls[1].arguments, <String, Object?>{
        'generationId': 7,
        'bounds': <String, double>{
          'left': 1,
          'top': 2,
          'width': 3,
          'height': 4,
          'devicePixelRatio': 2,
        },
      });
      expect(calls[2].arguments, <String, Object?>{
        'generationId': 7,
        'visible': true,
      });
      expect(calls[3].arguments, <String, Object?>{
        'generationId': 7,
        'uri': 'https://www.dmm.com/game',
      });
      expect(calls[4].arguments, <String, Object?>{'generationId': 7});
      expect(calls[8].arguments, <String, Object?>{
        'generationId': 7,
        'javascript': 'window.test()',
      });
      for (final index in <int>[4, 5, 6, 7, 9, 10, 11]) {
        expect(calls[index].arguments, <String, Object?>{'generationId': 7});
      }
    },
  );

  test(
    'rejects unsafe loads, missing generation, and invalid create result',
    () async {
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        if (call.method == 'create') return -1;
        return null;
      });
      final port = MethodChannelNativeGameWebViewPort(channel: channel);
      addTearDown(port.dispose);

      await expectLater(port.reload(), throwsStateError);
      await expectLater(
        port.create(),
        throwsA(isA<NativeGameWebViewSchemaException>()),
      );
      expect(calls, hasLength(1));

      final safeCalls = <MethodCall>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        safeCalls.add(call);
        return 2;
      });
      final safePort = MethodChannelNativeGameWebViewPort(
        channel: channel,
        eventStream: Stream<Object?>.empty(),
      );
      addTearDown(safePort.dispose);
      await safePort.create();
      await expectLater(
        safePort.loadUri(Uri.parse('intent://private')),
        throwsArgumentError,
      );
      expect(safeCalls.map((call) => call.method), <String>['create']);
    },
  );

  test(
    'filters stale events, forwards current events, and reports schema errors',
    () async {
      messenger.setMockMethodCallHandler(channel, (call) async => 3);
      final source = StreamController<Object?>.broadcast();
      final port = MethodChannelNativeGameWebViewPort(
        channel: channel,
        eventStream: source.stream,
      );
      addTearDown(source.close);
      addTearDown(port.dispose);
      await port.create();
      final received = <NativeGameWebViewEvent>[];
      final errors = <Object>[];
      final subscription = port.events.listen(
        received.add,
        onError: errors.add,
      );
      addTearDown(subscription.cancel);

      source.add(<String, Object?>{'type': 'created', 'generationId': 2});
      source.add(<String, Object?>{
        'type': 'pageFinished',
        'generationId': 3,
        'url': 'https://www.dmm.com/game?secret=1',
      });
      source.add(<String, Object?>{'type': 'created', 'generationId': -1});
      await Future<void>.delayed(Duration.zero);

      expect(received, hasLength(1));
      expect(received.single.url, 'https://www.dmm.com/game');
      expect(errors.single, isA<NativeGameWebViewSchemaException>());
    },
  );

  test('cancels events before destroying and dispose is idempotent', () async {
    final order = <String>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      order.add(call.method);
      return call.method == 'create' ? 5 : null;
    });
    final source = StreamController<Object?>.broadcast(
      onCancel: () => order.add('cancel'),
    );
    final port = MethodChannelNativeGameWebViewPort(
      channel: channel,
      eventStream: source.stream,
    );
    await port.create();

    await port.dispose();
    await port.dispose();

    expect(order, <String>['create', 'cancel', 'destroy']);
    await expectLater(port.reload(), throwsStateError);
  });

  test('rejects a non-boolean canGoBack result', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      return call.method == 'create' ? 1 : 'yes';
    });
    final port = MethodChannelNativeGameWebViewPort(channel: channel);
    addTearDown(port.dispose);
    await port.create();

    await expectLater(
      port.canGoBack(),
      throwsA(isA<NativeGameWebViewSchemaException>()),
    );
  });

  test('coalesces concurrent create calls into one native host', () async {
    final calls = <MethodCall>[];
    final createResult = Completer<int>();
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return createResult.future;
    });
    final port = MethodChannelNativeGameWebViewPort(
      channel: channel,
      eventStream: Stream<Object?>.empty(),
    );
    addTearDown(port.dispose);

    final first = port.create();
    final second = port.create();
    await Future<void>.delayed(Duration.zero);
    expect(calls.map((call) => call.method), <String>['create']);
    createResult.complete(4);

    expect(await first, 4);
    expect(await second, 4);
  });

  test('destroys a host created after disposal begins', () async {
    final calls = <MethodCall>[];
    final createResult = Completer<int>();
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'create') return createResult.future;
      return null;
    });
    final port = MethodChannelNativeGameWebViewPort(
      channel: channel,
      eventStream: Stream<Object?>.empty(),
    );

    final create = port.create();
    final dispose = port.dispose();
    createResult.complete(9);
    await dispose;

    await expectLater(create, throwsStateError);
    expect(calls.map((call) => call.method), <String>['create', 'destroy']);
    expect(calls.last.arguments, <String, Object?>{'generationId': 9});
  });

  test(
    'waits for asynchronous event cancellation before late create destroys',
    () async {
      final calls = <MethodCall>[];
      final createResult = Completer<int>();
      final cancellation = Completer<void>();
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        if (call.method == 'create') return createResult.future;
        return null;
      });
      final source = StreamController<Object?>(
        onCancel: () => cancellation.future,
      );
      final port = MethodChannelNativeGameWebViewPort(
        channel: channel,
        eventStream: source.stream,
      );
      addTearDown(source.close);

      final create = port.create();
      final dispose = port.dispose();
      createResult.complete(10);
      await Future<void>.delayed(Duration.zero);
      expect(calls.map((call) => call.method), <String>['create']);
      cancellation.complete();

      await dispose;
      await expectLater(create, throwsStateError);
      expect(calls.map((call) => call.method), <String>['create', 'destroy']);
    },
  );

  test(
    'buffers events emitted while create is awaiting its generation',
    () async {
      final source = StreamController<Object?>.broadcast(sync: true);
      messenger.setMockMethodCallHandler(channel, (call) async {
        source.add(<String, Object?>{'type': 'created', 'generationId': 6});
        return 6;
      });
      final port = MethodChannelNativeGameWebViewPort(
        channel: channel,
        eventStream: source.stream,
      );
      addTearDown(source.close);
      addTearDown(port.dispose);
      final received = <NativeGameWebViewEvent>[];
      final subscription = port.events.listen(received.add);
      addTearDown(subscription.cancel);

      await port.create();
      await Future<void>.delayed(Duration.zero);

      expect(received.map((event) => event.type), <NativeGameWebViewEventType>[
        NativeGameWebViewEventType.created,
      ]);
    },
  );

  test(
    'closes events when an in-flight create fails during disposal',
    () async {
      final createResult = Completer<Object?>();
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'create') return createResult.future;
        return null;
      });
      final source = StreamController<Object?>.broadcast();
      final port = MethodChannelNativeGameWebViewPort(
        channel: channel,
        eventStream: source.stream,
      );
      addTearDown(source.close);
      final done = Completer<void>();
      final subscription = port.events.listen(null, onDone: done.complete);
      addTearDown(subscription.cancel);

      final create = port.create();
      final dispose = port.dispose();
      createResult.completeError(PlatformException(code: 'create_failed'));

      await expectLater(
        create,
        throwsA(
          isA<PlatformException>().having(
            (error) => error.code,
            'code',
            'create_failed',
          ),
        ),
      );
      await expectLater(
        dispose,
        throwsA(
          isA<PlatformException>().having(
            (error) => error.code,
            'code',
            'create_failed',
          ),
        ),
      );
      await done.future;
    },
  );

  test('destroys and closes events when cancellation fails', () async {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return call.method == 'create' ? 13 : null;
    });
    final source = StreamController<Object?>(
      onCancel: () =>
          Future<void>.error(PlatformException(code: 'cancel_failed')),
    );
    final port = MethodChannelNativeGameWebViewPort(
      channel: channel,
      eventStream: source.stream,
    );
    final done = Completer<void>();
    final subscription = port.events.listen(null, onDone: done.complete);
    addTearDown(subscription.cancel);
    await port.create();

    final firstDispose = port.dispose();
    expect(identical(firstDispose, port.dispose()), isTrue);
    await expectLater(
      firstDispose,
      throwsA(
        isA<PlatformException>().having(
          (error) => error.code,
          'code',
          'cancel_failed',
        ),
      ),
    );
    expect(calls.map((call) => call.method), <String>['create', 'destroy']);
    await done.future;
  });

  test('closes events after a native destroy failure', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'create') return 14;
      throw PlatformException(code: 'destroy_failed');
    });
    final port = MethodChannelNativeGameWebViewPort(
      channel: channel,
      eventStream: Stream<Object?>.empty(),
    );
    final done = Completer<void>();
    final subscription = port.events.listen(null, onDone: done.complete);
    addTearDown(subscription.cancel);
    await port.create();

    await expectLater(
      port.dispose(),
      throwsA(
        isA<PlatformException>().having(
          (error) => error.code,
          'code',
          'destroy_failed',
        ),
      ),
    );
    await done.future;
  });

  test(
    'replays buffered create events to the first post-create listener',
    () async {
      final source = StreamController<Object?>.broadcast(sync: true);
      messenger.setMockMethodCallHandler(channel, (call) async {
        source
          ..add(<String, Object?>{'type': 'created', 'generationId': 15})
          ..add(<String, Object?>{
            'type': 'pageStarted',
            'generationId': 15,
            'url': 'https://www.dmm.com/game',
          })
          ..add(<String, Object?>{'type': 'created', 'generationId': 14});
        return 15;
      });
      final port = MethodChannelNativeGameWebViewPort(
        channel: channel,
        eventStream: source.stream,
      );
      addTearDown(source.close);
      addTearDown(port.dispose);

      await port.create();
      final first = <NativeGameWebViewEvent>[];
      final firstSubscription = port.events.listen(first.add);
      addTearDown(firstSubscription.cancel);
      await Future<void>.delayed(Duration.zero);
      final second = <NativeGameWebViewEvent>[];
      final secondSubscription = port.events.listen(second.add);
      addTearDown(secondSubscription.cancel);
      await Future<void>.delayed(Duration.zero);

      expect(first.map((event) => event.type), <NativeGameWebViewEventType>[
        NativeGameWebViewEventType.created,
        NativeGameWebViewEventType.pageStarted,
      ]);
      expect(second, isEmpty);
    },
  );
}
