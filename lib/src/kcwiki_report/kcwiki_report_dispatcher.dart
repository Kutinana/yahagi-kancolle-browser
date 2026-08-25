import 'dart:async';
import 'dart:collection';

import 'kcwiki_report_request.dart';
import 'kcwiki_report_transport.dart';

final class KcwikiDispatchResult {
  const KcwikiDispatchResult({
    required this.module,
    required this.accepted,
    this.statusCode,
  });

  final KcwikiReportModule module;
  final bool accepted;
  final int? statusCode;
}

final class KcwikiReportDispatcher {
  KcwikiReportDispatcher({
    required KcwikiReportTransport Function() transportFactory,
    this.onResult,
    this.onDropped,
    this.maxPendingCount = 16,
    this.maxPendingBytes = 4 * 1024 * 1024,
  }) : assert(maxPendingCount > 0),
       assert(maxPendingBytes > 0),
       _transportFactory = transportFactory;

  final KcwikiReportTransport Function() _transportFactory;
  final void Function(KcwikiDispatchResult result)? onResult;
  final void Function()? onDropped;
  final int maxPendingCount;
  final int maxPendingBytes;
  final Queue<KcwikiReportRequest> _waiting = Queue<KcwikiReportRequest>();

  KcwikiReportTransport? _transport;
  Future<void> _drain = Future<void>.value();
  bool _enabled = false;
  bool _draining = false;
  int _epoch = 0;
  int _inFlightCount = 0;
  int _pendingBytes = 0;

  bool get enabled => _enabled;
  int get pendingCount => _inFlightCount + _waiting.length;
  int get pendingBytes => _pendingBytes;
  Future<void> get idle => _drain;

  void start() {
    if (_enabled) return;
    _epoch += 1;
    _enabled = true;
    _transport = _transportFactory();
  }

  void stop() {
    if (!_enabled && _transport == null) return;
    _epoch += 1;
    _enabled = false;
    _waiting.clear();
    _pendingBytes = 0;
    _inFlightCount = 0;
    _draining = false;
    _drain = Future<void>.value();
    _transport?.close();
    _transport = null;
  }

  bool submit(KcwikiReportRequest request) {
    if (!_enabled ||
        pendingCount >= maxPendingCount ||
        _pendingBytes + request.byteLength > maxPendingBytes) {
      onDropped?.call();
      return false;
    }
    _waiting.add(request);
    _pendingBytes += request.byteLength;
    _ensureDrain();
    return true;
  }

  void _ensureDrain() {
    if (_draining) return;
    final epoch = _epoch;
    _draining = true;
    final operation = _drainQueue(epoch);
    _drain = operation.catchError((Object _) {}).whenComplete(() {
      if (epoch != _epoch) return;
      _draining = false;
      if (_enabled && _waiting.isNotEmpty) _ensureDrain();
    });
  }

  Future<void> _drainQueue(int epoch) async {
    while (_enabled && epoch == _epoch && _waiting.isNotEmpty) {
      final request = _waiting.removeFirst();
      _inFlightCount += 1;
      final transport = _transport;
      KcwikiTransportResult result;
      try {
        result = transport == null
            ? const KcwikiTransportResult.failed(
                failure: KcwikiTransportFailure.network,
              )
            : await transport.send(request);
      } catch (_) {
        result = const KcwikiTransportResult.failed(
          failure: KcwikiTransportFailure.network,
        );
      }
      if (epoch != _epoch) return;
      _inFlightCount -= 1;
      _pendingBytes -= request.byteLength;
      onResult?.call(
        KcwikiDispatchResult(
          module: request.module,
          accepted: result.accepted,
          statusCode: result.statusCode,
        ),
      );
    }
  }

  void dispose() => stop();
}
