import 'dart:async';

import 'package:http/http.dart' as http;

import 'kcwiki_report_request.dart';

enum KcwikiTransportFailure { bodyTooLarge, timeout, network, rejected }

final class KcwikiTransportResult {
  const KcwikiTransportResult.accepted({required this.statusCode})
    : accepted = true,
      failure = null;

  const KcwikiTransportResult.failed({this.statusCode, required this.failure})
    : accepted = false;

  final bool accepted;
  final int? statusCode;
  final KcwikiTransportFailure? failure;
}

abstract interface class KcwikiReportTransport {
  Future<KcwikiTransportResult> send(KcwikiReportRequest request);

  void close();
}

final class HttpKcwikiReportTransport implements KcwikiReportTransport {
  HttpKcwikiReportTransport({
    required http.Client client,
    required this.baseUri,
    this.timeout = const Duration(seconds: 8),
    this.maxBodyBytes = 2 * 1024 * 1024,
  }) : assert(maxBodyBytes > 0) {
    _client = client;
  }

  late final http.Client _client;
  final Uri baseUri;
  final Duration timeout;
  final int maxBodyBytes;
  bool _closed = false;

  @override
  Future<KcwikiTransportResult> send(KcwikiReportRequest request) async {
    if (_closed) {
      return const KcwikiTransportResult.failed(
        failure: KcwikiTransportFailure.network,
      );
    }
    if (request.byteLength > maxBodyBytes) {
      return const KcwikiTransportResult.failed(
        failure: KcwikiTransportFailure.bodyTooLarge,
      );
    }
    final target = baseUri.resolve(request.module.path);
    final outbound = http.Request('POST', target)
      ..headers['content-type'] = request.contentType
      ..body = request.encodedBody;
    try {
      final response = await _client.send(outbound).timeout(timeout);
      await response.stream.drain<void>();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return KcwikiTransportResult.accepted(statusCode: response.statusCode);
      }
      return KcwikiTransportResult.failed(
        statusCode: response.statusCode,
        failure: KcwikiTransportFailure.rejected,
      );
    } on TimeoutException {
      return const KcwikiTransportResult.failed(
        failure: KcwikiTransportFailure.timeout,
      );
    } catch (_) {
      return const KcwikiTransportResult.failed(
        failure: KcwikiTransportFailure.network,
      );
    }
  }

  @override
  void close() {
    if (_closed) return;
    _closed = true;
    _client.close();
  }
}
