import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/sortie_map_query/sortie_map_catalog_manifest.dart';

void main() {
  test('parses a valid manifest and compares revisions', () {
    final manifest = SortieMapCatalogManifest.fromJsonString('''
{"schemaVersion":1,"dataVersion":"2026.09.20","revision":2026092001,
"publishedAt":"2026-09-20T00:00:00Z","minimumAppVersion":"1.0.8-beta.2",
"archive":{"tag":"sortie-data-2026.09.20","fileName":"sortie-data-2026.09.20.zip",
"bytes":123,"sha256":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"},
"counts":{"maps":37,"nodes":490,"formations":1446}}
''');

    expect(manifest.version.label, '2026.09.20');
    expect(manifest.version.revision, 2026092001);
    expect(manifest.archiveBytes, 123);
    expect(manifest.isCompatibleWith('1.0.8-beta.2'), isTrue);
    expect(manifest.isCompatibleWith('1.0.8-beta.1'), isFalse);
    expect(manifest.isCompatibleWith('1.0.8'), isTrue);
    expect(manifest.isCompatibleWith('1.0.8-beta.2+16'), isTrue);
    expect(manifest.isCompatibleWith('invalid'), isFalse);
    expect(
      manifest.version.compareTo(
        const SortieMapCatalogVersion(label: 'older', revision: 2026092000),
      ),
      greaterThan(0),
    );
  });

  test('rejects unsafe archive metadata', () {
    expect(
      () => SortieMapCatalogManifest.fromJsonString('''
{"schemaVersion":1,"dataVersion":"x","revision":1,
"publishedAt":"2026-09-20T00:00:00Z","minimumAppVersion":"1.0.0",
"archive":{"tag":"../bad","fileName":"../bad.zip","bytes":1,"sha256":"bad"},
"counts":{"maps":1,"nodes":1,"formations":1}}
'''),
      throwsFormatException,
    );
  });
}
