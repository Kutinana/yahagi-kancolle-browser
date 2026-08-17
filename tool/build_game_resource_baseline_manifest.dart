import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

const int baselineManifestSchemaVersion = 1;

const List<String> _allowedPrefixes = <String>[
  '/gadget_html5/',
  '/html/',
  '/kcs/',
  '/kcs2/',
  '/kcscontents/',
];

final class BaselineManifestEntry {
  const BaselineManifestEntry({
    required this.path,
    required this.version,
    required this.length,
  });

  final String path;
  final String version;
  final int length;

  List<Object> toCompactJson() => <Object>[path, version, length];
}

final class ConvertedBaselineManifest {
  const ConvertedBaselineManifest(this.entries);

  final List<BaselineManifestEntry> entries;

  int get entryCount => entries.length;
  int get targetBytes =>
      entries.fold<int>(0, (sum, entry) => sum + entry.length);

  Map<String, Object> toJson() {
    final compactEntries = entries
        .map((entry) => entry.toCompactJson())
        .toList(growable: false);
    final encodedEntries = utf8.encode(jsonEncode(compactEntries));
    return <String, Object>{
      'schemaVersion': baselineManifestSchemaVersion,
      'entryCount': entryCount,
      'targetBytes': targetBytes,
      'entriesSha256': sha256.convert(encodedEntries).toString(),
      'entries': compactEntries,
    };
  }
}

ConvertedBaselineManifest convertBaselineIndex(Map<String, Object?> source) {
  final entries = <BaselineManifestEntry>[];
  for (final item in source.entries) {
    final path = item.key;
    if (!_isSafeResourcePath(path)) continue;
    final metadata = item.value;
    if (metadata is! Map) continue;

    final rawLength = metadata['length'];
    final length = switch (rawLength) {
      int value => value,
      num value when value.isFinite && value == value.roundToDouble() =>
        value.toInt(),
      String value => int.tryParse(value),
      _ => null,
    };
    if (length == null || length < 0) continue;

    final rawVersion = metadata['version']?.toString().trim() ?? '';
    final version = rawVersion.isEmpty || rawVersion.startsWith('?')
        ? rawVersion
        : '?$rawVersion';
    entries.add(
      BaselineManifestEntry(path: path, version: version, length: length),
    );
  }

  entries.sort((left, right) {
    final pathOrder = left.path.compareTo(right.path);
    return pathOrder != 0 ? pathOrder : left.version.compareTo(right.version);
  });
  return ConvertedBaselineManifest(
    List<BaselineManifestEntry>.unmodifiable(entries),
  );
}

bool _isSafeResourcePath(String path) {
  if (path.contains('..') || path.contains(r'\')) return false;
  return _allowedPrefixes.any(path.startsWith);
}

Future<void> main(List<String> arguments) async {
  if (arguments.length != 2) {
    stderr.writeln(
      'Usage: dart run tool/build_game_resource_baseline_manifest.dart '
      '<cached.json> <manifest.json.gz>',
    );
    exitCode = 64;
    return;
  }

  final input = File(arguments[0]);
  final output = File(arguments[1]);
  final decoded = jsonDecode(await input.readAsString());
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('Baseline cache index must be a JSON object.');
  }

  final converted = convertBaselineIndex(decoded.cast<String, Object?>());
  final encoded = utf8.encode(jsonEncode(converted.toJson()));
  await output.parent.create(recursive: true);
  await output.writeAsBytes(gzip.encode(encoded), flush: true);
  stdout.writeln(
    'Wrote ${converted.entryCount} entries, ${converted.targetBytes} bytes '
    'to ${output.path} (${await output.length()} compressed bytes).',
  );
}
