import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/settings/sortie_map_catalog_update_section.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/sortie_map_query/sortie_map_catalog_controller.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/sortie_map_query/sortie_map_catalog_update_service.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/sortie_map_query/sortie_map_models.dart';

void main() {
  testWidgets('shows active version and a manual update action', (
    tester,
  ) async {
    final controller = SortieMapCatalogController(
      data: const SortieMapCatalogData(
        version: 1,
        dataVersion: '2026.09.20',
        revision: 2026092001,
        source: 'test',
        maps: <SortieMapInfo>[],
      ),
      updater: const _NoopUpdater(),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        home: Scaffold(
          body: SortieMapCatalogUpdateSection(controller: controller),
        ),
      ),
    );

    expect(find.text('海域资料'), findsOneWidget);
    expect(find.text('数据版本：2026-09-20'), findsOneWidget);
    expect(find.text('上次检查：尚未检查'), findsOneWidget);
    expect(
      find.byKey(const Key('sortie-map-catalog-check-button')),
      findsOneWidget,
    );
  });
}

final class _NoopUpdater implements SortieMapCatalogUpdateClient {
  const _NoopUpdater();

  @override
  Future<SortieMapCatalogUpdateResult> checkAndUpdate({
    required SortieMapCatalogData current,
  }) async => SortieMapCatalogUpToDate(current.versionInfo, sourceHost: 'test');
}
