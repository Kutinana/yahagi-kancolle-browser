import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/sortie_map_query/sortie_map_catalog_controller.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/sortie_map_query/sortie_map_catalog_store.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/sortie_map_query/sortie_map_catalog_update_service.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/sortie_map_query/sortie_map_models.dart';

void main() {
  test(
    'coalesces concurrent checks and activates an updated catalog',
    () async {
      final updater = _Updater();
      final controller = SortieMapCatalogController(
        data: _catalog(1),
        updater: updater,
      );
      addTearDown(controller.dispose);

      final first = controller.checkForUpdates();
      final second = controller.checkForUpdates();
      expect(identical(first, second), isTrue);
      await first;

      expect(controller.data.revision, 2);
      expect(controller.isChecking, isFalse);
      expect(updater.calls, 1);
    },
  );
}

SortieMapCatalogData _catalog(int revision) => SortieMapCatalogData(
  version: 1,
  dataVersion: 'v$revision',
  revision: revision,
  source: 'test',
  maps: const <SortieMapInfo>[],
);

final class _Updater implements SortieMapCatalogUpdateClient {
  int calls = 0;

  @override
  Future<SortieMapCatalogUpdateResult> checkAndUpdate({
    required SortieMapCatalogData current,
  }) async {
    calls++;
    await Future<void>.delayed(Duration.zero);
    return SortieMapCatalogUpdated(
      InstalledSortieMapCatalog(data: _catalog(2), root: Directory.systemTemp),
      sourceHost: 'test',
    );
  }
}
