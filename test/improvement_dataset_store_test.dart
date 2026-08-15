import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/improvement/improvement_dataset.dart';
import 'package:yahagi_kancolle_browser/src/improvement/improvement_dataset_store.dart';

void main() {
  String dataset({required String dataVersion, required int schemaVersion}) =>
      ImprovementDataset(
        schemaVersion: schemaVersion,
        version: ImprovementDatasetVersion(
          dataVersion: dataVersion,
          commitSha: '$schemaVersion' * 40,
        ),
        entries: const <ImprovementEntry>[],
      ).encode();

  test('prefers the newer bundled schema when data versions match', () async {
    final store = ImprovementDatasetStore(
      _MemoryStorage(
        bundled: dataset(dataVersion: '2026.07.10', schemaVersion: 2),
        cached: dataset(dataVersion: '2026.07.10', schemaVersion: 1),
      ),
    );

    final loaded = await store.loadBestAvailable();

    expect(loaded.schemaVersion, 2);
  });

  test('still prefers a newer cached data version', () async {
    final store = ImprovementDatasetStore(
      _MemoryStorage(
        bundled: dataset(dataVersion: '2026.07.10', schemaVersion: 2),
        cached: dataset(dataVersion: '2026.08.01', schemaVersion: 1),
      ),
    );

    final loaded = await store.loadBestAvailable();

    expect(loaded.version.dataVersion, '2026.08.01');
    expect(loaded.schemaVersion, 1);
  });
}

class _MemoryStorage implements ImprovementDatasetStorage {
  const _MemoryStorage({required this.bundled, required this.cached});

  final String bundled;
  final String? cached;

  @override
  Future<String> readBundled() async => bundled;

  @override
  Future<String?> readCached() async => cached;

  @override
  Future<void> writeCached(String source) async {}
}
