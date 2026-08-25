import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:yahagi_kancolle_browser/src/kcwiki_report/kcwiki_report_request.dart';
import 'package:yahagi_kancolle_browser/src/kcwiki_report/kcwiki_report_transport.dart';

void main() {
  test('quest uses form encoding and battle uses JSON', () async {
    final client = _RecordingClient();
    final transport = HttpKcwikiReportTransport(
      client: client,
      baseUri: Uri.parse('http://example.test:17027'),
    );
    addTearDown(transport.close);

    await transport.send(
      KcwikiReportRequest.form(KcwikiReportModule.quest, <String, Object?>{
        'current': 101,
        'after': <int>[301],
      }),
    );
    await transport.send(
      KcwikiReportRequest.json(KcwikiReportModule.battle, <String, Object?>{
        'data': <String, Object?>{},
      }),
    );

    expect(client.requests[0].url.path, '/api/report/quest');
    expect(
      client.requests[0].headers['content-type'],
      contains('application/x-www-form-urlencoded'),
    );
    expect(client.requests[0].body, contains('after%5B0%5D=301'));
    expect(client.requests[1].url.path, '/api/report/battle');
    expect(
      client.requests[1].headers['content-type'],
      contains('application/json'),
    );
    expect(jsonDecode(client.requests[1].body), <String, Object?>{
      'data': <String, Object?>{},
    });
  });

  test('non-2xx response is reported as rejected', () async {
    final transport = HttpKcwikiReportTransport(
      client: _RecordingClient(statusCode: 503),
      baseUri: Uri.parse('http://example.test:17027'),
    );
    addTearDown(transport.close);

    final result = await transport.send(
      KcwikiReportRequest.form(
        KcwikiReportModule.quest,
        const <String, Object?>{},
      ),
    );

    expect(result.accepted, isFalse);
    expect(result.statusCode, 503);
  });

  test('oversized body is rejected before opening the network', () async {
    final client = _RecordingClient();
    final transport = HttpKcwikiReportTransport(
      client: client,
      baseUri: Uri.parse('http://example.test:17027'),
      maxBodyBytes: 10,
    );
    addTearDown(transport.close);

    final result = await transport.send(
      KcwikiReportRequest.json(KcwikiReportModule.battle, <String, Object?>{
        'data': 'long payload',
      }),
    );

    expect(result.accepted, isFalse);
    expect(result.failure, KcwikiTransportFailure.bodyTooLarge);
    expect(client.requests, isEmpty);
  });

  test('request timeout becomes an isolated failure', () async {
    final transport = HttpKcwikiReportTransport(
      client: _RecordingClient(block: true),
      baseUri: Uri.parse('http://example.test:17027'),
      timeout: const Duration(milliseconds: 1),
    );
    addTearDown(transport.close);

    final result = await transport.send(
      KcwikiReportRequest.form(
        KcwikiReportModule.quest,
        const <String, Object?>{},
      ),
    );

    expect(result.accepted, isFalse);
    expect(result.failure, KcwikiTransportFailure.timeout);
  });
}

final class _RecordingClient extends http.BaseClient {
  _RecordingClient({this.statusCode = 204, this.block = false});

  final int statusCode;
  final bool block;
  final List<http.Request> requests = <http.Request>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final materialized = request as http.Request;
    requests.add(materialized);
    if (block) await Completer<void>().future;
    return http.StreamedResponse(const Stream<List<int>>.empty(), statusCode);
  }
}
