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
}

final class _ControlledTransport implements KcwikiReportTransport {
  _ControlledTransport({this.block = false, this.failFirst = false});

  final bool block;
  final bool failFirst;
  int sent = 0;
  bool closed = false;

  @override
  Future<KcwikiTransportResult> send(KcwikiReportRequest request) async {
    sent += 1;
    if (block) await Completer<void>().future;
    if (failFirst && sent == 1) throw StateError('network failed');
    return const KcwikiTransportResult.accepted(statusCode: 204);
  }

  @override
  void close() => closed = true;
}
