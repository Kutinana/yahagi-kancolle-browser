import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/development/development_dataset.dart';
import 'package:yahagi_kancolle_browser/src/development/development_recipe_calculator.dart';

void main() {
  late DevelopmentDataset dataset;
  late List<Object?> vectors;

  setUpAll(() async {
    dataset = DevelopmentDataset.fromJsonString(
      await File(
        'assets/data/development/development_snapshot.json',
      ).readAsString(),
    );
    final fixture =
        jsonDecode(
              await File(
                'test/development/development_reference_vectors.json',
              ).readAsString(),
            )
            as Map<String, Object?>;
    expect(fixture['source_commit'], 'd065120');
    vectors = fixture['vectors']! as List<Object?>;
  });

  const cases = <_ReferenceCase>[
    _ReferenceCase({1}, 64, 6, 40, 186, 5038),
    _ReferenceCase({2}, 59, 10, 50, 244, 3614),
    _ReferenceCase({3}, 59, 6, 60, 238, 3244),
    _ReferenceCase({4}, 84, 6, 50, 344, 4762),
    _ReferenceCase({5}, 58, 4, 90, 162, 2052),
    _ReferenceCase({6}, 42, 6, 90, 122, 1700),
    _ReferenceCase({7}, 41, 10, 321, 190, 1030),
    _ReferenceCase({8}, 14, 8, 421, 108, 368),
    _ReferenceCase({168}, 24, 8, 760, 192, 328),
    _ReferenceCase({168, 1}, 11, 10, 760, 110, 208),
    _ReferenceCase({168, 2}, 11, 10, 770, 110, 142),
    _ReferenceCase({168, 3}, 11, 14, 780, 150, 80),
  ];

  for (final reference in cases) {
    test('matches authorized vector summary for ${reference.targets}', () {
      final results = calculateDevelopmentRecipes(dataset, reference.targets);

      expect(results, hasLength(reference.count));
      expect(
        results.map((item) => item.targetRate).reduce(_max),
        reference.maxHit,
      );
      expect(
        results.map((item) => item.totalResources).reduce(_min),
        reference.minTotal,
      );
      expect(
        results.fold<double>(0, (sum, item) => sum + item.targetRate),
        reference.sumHit,
      );
      expect(
        results.fold<double>(0, (sum, item) => sum + item.failureRate),
        reference.sumFailure,
      );
      expect(results.every((item) => item.targetRate > 0), isTrue);

      final expected = vectors.cast<Map<String, Object?>>().singleWhere(
        (vector) =>
            (vector['targets']! as List<Object?>)
                .cast<int>()
                .toSet()
                .containsAll(reference.targets) &&
            reference.targets.containsAll(
              (vector['targets']! as List<Object?>).cast<int>(),
            ),
      );
      final normalized = [
        for (final result in results)
          <String, Object?>{
            'pool_key': result.poolKey,
            'pool_type': result.poolType.name,
            'resources': result.resources.values,
            'target_rate': result.targetRate,
            'failure_rate': result.failureRate,
          },
      ];
      expect(normalized, expected['results']);
    });
  }
}

double _max(double left, double right) => left > right ? left : right;
int _min(int left, int right) => left < right ? left : right;

class _ReferenceCase {
  const _ReferenceCase(
    this.targets,
    this.count,
    this.maxHit,
    this.minTotal,
    this.sumHit,
    this.sumFailure,
  );

  final Set<int> targets;
  final int count;
  final double maxHit;
  final int minTotal;
  final double sumHit;
  final double sumFailure;
}
