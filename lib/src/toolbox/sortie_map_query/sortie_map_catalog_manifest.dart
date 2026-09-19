import 'dart:convert';

final class SortieMapCatalogVersion
    implements Comparable<SortieMapCatalogVersion> {
  const SortieMapCatalogVersion({
    required this.label,
    required this.revision,
    this.publishedAt,
  });

  final String label;
  final int revision;
  final DateTime? publishedAt;

  @override
  int compareTo(SortieMapCatalogVersion other) =>
      revision.compareTo(other.revision);
}

final class SortieMapCatalogManifest {
  const SortieMapCatalogManifest({
    required this.schemaVersion,
    required this.version,
    required this.minimumAppVersion,
    required this.archiveTag,
    required this.archiveFileName,
    required this.archiveBytes,
    required this.archiveSha256,
    required this.mapCount,
    required this.nodeCount,
    required this.formationCount,
  });

  factory SortieMapCatalogManifest.fromJsonString(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Sortie manifest root must be an object.');
    }
    return SortieMapCatalogManifest.fromJson(decoded);
  }

  factory SortieMapCatalogManifest.fromJson(Map<String, dynamic> json) {
    final archive = _object(json, 'archive');
    final counts = _object(json, 'counts');
    final publishedAt = DateTime.tryParse(
      _string(json, 'publishedAt'),
    )?.toUtc();
    final tag = _string(archive, 'tag');
    final fileName = _string(archive, 'fileName');
    final sha = _string(archive, 'sha256').toLowerCase();
    if (publishedAt == null ||
        !_safeToken.hasMatch(tag) ||
        !_safeFile.hasMatch(fileName) ||
        !_sha256.hasMatch(sha)) {
      throw const FormatException('Sortie manifest contains unsafe metadata.');
    }
    final schemaVersion = _positiveInt(json, 'schemaVersion');
    if (schemaVersion != 1) {
      throw FormatException(
        'Unsupported sortie manifest schema: $schemaVersion',
      );
    }
    return SortieMapCatalogManifest(
      schemaVersion: schemaVersion,
      version: SortieMapCatalogVersion(
        label: _string(json, 'dataVersion'),
        revision: _positiveInt(json, 'revision'),
        publishedAt: publishedAt,
      ),
      minimumAppVersion: _string(json, 'minimumAppVersion'),
      archiveTag: tag,
      archiveFileName: fileName,
      archiveBytes: _positiveInt(archive, 'bytes'),
      archiveSha256: sha,
      mapCount: _positiveInt(counts, 'maps'),
      nodeCount: _positiveInt(counts, 'nodes'),
      formationCount: _positiveInt(counts, 'formations'),
    );
  }

  final int schemaVersion;
  final SortieMapCatalogVersion version;
  final String minimumAppVersion;
  final String archiveTag;
  final String archiveFileName;
  final int archiveBytes;
  final String archiveSha256;
  final int mapCount;
  final int nodeCount;
  final int formationCount;

  bool isCompatibleWith(String appVersion) =>
      _compareSemanticVersions(appVersion, minimumAppVersion) >= 0;

  Uri get releaseUri => Uri.https(
    'github.com',
    '/yamatosaki/yahagi-kancolle-browser/releases/download/'
        '$archiveTag/$archiveFileName',
  );
}

final _safeToken = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$');
final _safeFile = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,127}\.zip$');
final _sha256 = RegExp(r'^[0-9a-f]{64}$');

Map<String, dynamic> _object(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! Map<String, dynamic>) {
    throw FormatException('$key must be an object.');
  }
  return value;
}

String _string(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('$key must be a non-empty string.');
  }
  return value;
}

int _positiveInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! int || value <= 0) {
    throw FormatException('$key must be a positive integer.');
  }
  return value;
}

int _compareSemanticVersions(String left, String right) {
  List<int>? parse(String value) {
    final match = RegExp(r'^(\d+)\.(\d+)\.(\d+)').firstMatch(value);
    return match == null
        ? null
        : <int>[
            int.parse(match.group(1)!),
            int.parse(match.group(2)!),
            int.parse(match.group(3)!),
          ];
  }

  final a = parse(left);
  final b = parse(right);
  if (a == null || b == null) return -1;
  for (var index = 0; index < 3; index++) {
    final result = a[index].compareTo(b[index]);
    if (result != 0) return result;
  }
  return 0;
}
