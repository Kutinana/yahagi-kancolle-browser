import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:yahagi_kancolle_browser/src/improvement/improvement_dataset.dart';
import 'package:yahagi_kancolle_browser/src/improvement/improvement_dataset_store.dart';
import 'package:yahagi_kancolle_browser/src/improvement/improvement_dataset_update_service.dart';

void main() {
  late ImprovementDataset current;
  setUp(() async {
    current = ImprovementDataset.parse(
      await File(
        'assets/data/improvement/planner_snapshot.json',
      ).readAsString(),
    );
  });

  test('reports up to date from the immutable commit SHA', () async {
    final client = MockClient((request) async {
      expect(request.url, ImprovementDatasetUpdateService.commitUri);
      return http.Response(
        jsonEncode(<String, Object>{'sha': current.version.commitSha}),
        200,
      );
    });
    final result = await ImprovementDatasetUpdateService(
      client: client,
      store: ImprovementDatasetStore(
        const BundledOnlyImprovementDatasetStorage(),
      ),
    ).checkAndUpdate(current);
    expect(result, isA<ImprovementUpToDate>());
  });

  test(
    'rejects malformed commit metadata without touching local data',
    () async {
      final client = MockClient(
        (request) async => http.Response('{"sha":"main"}', 200),
      );
      final result = await ImprovementDatasetUpdateService(
        client: client,
        store: ImprovementDatasetStore(
          const BundledOnlyImprovementDatasetStorage(),
        ),
      ).checkAndUpdate(current);
      expect(
        result,
        isA<ImprovementUpdateFailed>().having(
          (value) => value.kind,
          'kind',
          ImprovementUpdateFailure.validation,
        ),
      );
      expect(current.version.commitSha, hasLength(40));
    },
  );
}
