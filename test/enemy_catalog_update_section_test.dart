import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/settings/enemy_catalog_update_section.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/sortie_map_query/enemy_catalog.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/sortie_map_query/enemy_catalog_controller.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/sortie_map_query/enemy_catalog_update_service.dart';

import 'enemy_catalog_test.dart' show enemyCatalogFixture;

void main() {
  testWidgets('shows version and exposes manual enemy data update', (
    tester,
  ) async {
    final data = EnemyCatalogData.fromJsonString(enemyCatalogFixture);
    final controller = EnemyCatalogController(
      data: data,
      updater: _UpToDateUpdater(),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        home: Scaffold(body: EnemyCatalogUpdateSection(controller: controller)),
      ),
    );

    expect(find.text('敌舰资料'), findsOneWidget);
    expect(find.textContaining('2026.09.20'), findsOneWidget);
    expect(find.byKey(const Key('enemy-catalog-check-button')), findsOneWidget);

    await tester.tap(find.byKey(const Key('enemy-catalog-check-button')));
    await tester.pumpAndSettle();
    expect(find.textContaining('已是最新版本'), findsOneWidget);
  });
}

final class _UpToDateUpdater implements EnemyCatalogUpdateClient {
  @override
  Future<EnemyCatalogUpdateResult> checkAndUpdate({
    required EnemyCatalogData current,
  }) async => EnemyCatalogUpToDate(current, sourceHost: 'test');
}
