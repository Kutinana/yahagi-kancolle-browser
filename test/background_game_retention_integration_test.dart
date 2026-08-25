import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('main wires background game retention through the app lifecycle', () {
    final source = File('lib/main.dart').readAsStringSync();

    expect(source, contains('SharedPreferencesBackgroundGameRetentionStore()'));
    expect(source, contains('BackgroundGameRetentionCoordinator('));
    expect(
      source,
      contains(
        '_backgroundGameRetentionCoordinator?.handleLifecycleState(state)',
      ),
    );
    expect(
      RegExp(
        r'backgroundGameRetentionController:\s*backgroundGameRetentionController',
      ).allMatches(source).length,
      greaterThanOrEqualTo(2),
    );
  });
}
