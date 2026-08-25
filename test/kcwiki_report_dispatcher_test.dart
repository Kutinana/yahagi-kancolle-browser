import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/kcwiki_report/kcwiki_report_dispatcher.dart';
import 'package:yahagi_kancolle_browser/src/kcwiki_report/kcwiki_report_request.dart';
import 'package:yahagi_kancolle_browser/src/kcwiki_report/kcwiki_report_transport.dart';

void main() {
  final request = KcwikiReportRequest.form(
    KcwikiReportModule.quest,
    const <String, Object?>{'current': 101},
  );

  test('disabled dispatcher accepts no work', () {
    final dispatcher = KcwikiReportDispatcher(
      transportFactory: () => _ControlledTransport(),
    );
    addTearDown(dispatcher.dispose);

    expect(dispatcher.submit(request), isFalse);
    expect(dispatcher.pendingCount, 0);
  });

  test('stop clears waiting work and rejects new work', () async {
    final transport = _ControlledTransport(block: true);
    final dispatcher = KcwikiReportDispatcher(
      transportFactory: () => transport,
    );
    addTearDown(dispatcher.dispose);
    dispatcher.start();
    expect(dispatcher.submit(request), isTrue);
    expect(dispatcher.submit(request), isTrue);

    dispatcher.stop();

    expect(dispatcher.submit(request), isFalse);
    expect(dispatcher.pendingCount, 0);
    expect(transport.closed, isTrue);
  });

  test('queue enforces item limit without throwing', () async {
    final transport = _ControlledTransport(block: true);
    final dispatcher = KcwikiReportDispatcher(
      transportFactory: () => transport,
      maxPendingCount: 2,
    );
    addTearDown(dispatcher.dispose);
    dispatcher.start();

    expect(dispatcher.submit(request), isTrue);
    expect(dispatcher.submit(request), isTrue);
    expect(dispatcher.submit(request), isFalse);
  });

  test('transport exception does not prevent the next report', () async {
    final transport = _ControlledTransport(failFirst: true);
    final results = <KcwikiDispatchResult>[];
    final dispatcher = KcwikiReportDispatcher(
      transportFactory: () => transport,
      onResult: results.add,
    );
    addTearDown(dispatcher.dispose);
    dispatcher.start();

    dispatcher.submit(request);
    dispatcher.submit(request);
    await dispatcher.idle;

    expect(transport.sent, 2);
    expect(results.map((result) => result.accepted), <bool>[false, true]);
  });

  test('restart is independent from an uncooperative old transport', () async {
    final oldTransport = _ControlledTransport(block: true);
    final newTransport = _ControlledTransport();
    var factoryCalls = 0;
    final dispatcher = KcwikiReportDispatcher(
      transportFactory: () => factoryCalls++ == 0 ? oldTransport : newTransport,
    );
    addTearDown(dispatcher.dispose);
    dispatcher.start();
    dispatcher.submit(request);
    dispatcher.stop();

    dispatcher.start();
    expect(dispatcher.submit(request), isTrue);
    await dispatcher.idle;

    expect(newTransport.sent, 1);
  });

  test('accepted submit announces processing before its result', () async {
    final events = <String>[];
    final dispatcher = KcwikiReportDispatcher(
      transportFactory: () => _ControlledTransport(),
      onQueued: (module) => events.add('queued:${module.wireName}'),
      onResult: (result) => events.add('result:${result.module.wireName}'),
    );
    addTearDown(dispatcher.dispose);
    dispatcher.start();

    dispatcher.submit(request);
    await dispatcher.idle;

    expect(events, <String>['queued:quest', 'result:quest']);
  });

  test('transport failure is preserved in dispatch result', () async {
    KcwikiDispatchResult? observed;
    final dispatcher = KcwikiReportDispatcher(
      transportFactory: () => _ControlledTransport(
        result: const KcwikiTransportResult.failed(
          failure: KcwikiTransportFailure.timeout,
        ),
      ),
      onResult: (result) => observed = result,
    );
    addTearDown(dispatcher.dispose);
    dispatcher.start();

    dispatcher.submit(request);
    await dispatcher.idle;

    expect(observed?.failure, KcwikiTransportFailure.timeout);
  });
}

final class _ControlledTransport implements KcwikiReportTransport {
  _ControlledTransport({
    this.block = false,
    this.failFirst = false,
    this.result = const KcwikiTransportResult.accepted(statusCode: 204),
  });

  final bool block;
  final bool failFirst;
  final KcwikiTransportResult result;
  int sent = 0;
  bool closed = false;

  @override
  Future<KcwikiTransportResult> send(KcwikiReportRequest request) async {
    sent += 1;
    if (block) await Completer<void>().future;
    if (failFirst && sent == 1) throw StateError('network failed');
    return result;
  }

  @override
  void close() => closed = true;
}
