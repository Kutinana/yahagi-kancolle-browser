// Builds both maintained data releases and checks them with the app's runtime
// parsers and persistent stores. Run from the repository root with `dart run`.
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/sortie_map_query/enemy_catalog.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/sortie_map_query/enemy_catalog_store.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/sortie_map_query/sortie_map_catalog_manifest.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/sortie_map_query/sortie_map_catalog_store.dart';

Future<void> main(List<String> arguments) async {
  final options = _options(arguments);
  final temporary = await Directory.systemTemp.createTemp(
    'yahagi-data-contract-',
  );
  try {
    final appVersion = _appVersion();
    await _verifySortie(
      temporary,
      appVersion,
      File(options['--sortie-manifest'] ?? 'data/sortie/manifest.json'),
    );
    await _verifyEnemy(
      temporary,
      File(options['--enemy-manifest'] ?? 'data/enemy/manifest.json'),
    );
    stdout.writeln('Data release contract passed: sortie ZIP and enemy JSON.');
  } finally {
    await temporary.delete(recursive: true);
  }
}

Future<void> _verifySortie(
  Directory temporary,
  String appVersion,
  File trackedManifestFile,
) async {
  final manifestFile = File('${temporary.path}/sortie-manifest.json');
  final dist = Directory('${temporary.path}/dist');
  await _runPython(<String>[
    'tool/build_sortie_release.py',
    '--manifest',
    manifestFile.path,
    '--dist',
    dist.path,
  ]);
  final generatedRaw = await manifestFile.readAsString();
  final trackedRaw = await trackedManifestFile.readAsString();
  final manifest = SortieMapCatalogManifest.fromJsonString(generatedRaw);
  final trackedManifest = SortieMapCatalogManifest.fromJsonString(trackedRaw);
  if (!_sameJsonDocument(generatedRaw, trackedRaw)) {
    throw StateError('Generated sortie release differs from tracked manifest.');
  }
  final bytes = await File(
    '${dist.path}/${manifest.archiveFileName}',
  ).readAsBytes();
  if (bytes.length != manifest.archiveBytes ||
      sha256.convert(bytes).toString() != manifest.archiveSha256) {
    throw StateError('Generated sortie ZIP does not match its manifest.');
  }
  final store = FileSortieMapCatalogStore(
    root: Directory('${temporary.path}/sortie-store'),
    currentAppVersion: appVersion,
  );
  final installed = await store.installArchive(
    bytes,
    expected: SortieMapCatalogInstallExpectation(
      version: trackedManifest.version,
      mapCount: trackedManifest.mapCount,
      nodeCount: trackedManifest.nodeCount,
      formationCount: trackedManifest.formationCount,
      minimumAppVersion: trackedManifest.minimumAppVersion,
    ),
  );
  if (installed.data.revision != manifest.version.revision ||
      (await store.loadCached())?.data.maps.length != manifest.mapCount) {
    throw StateError('Generated sortie ZIP did not survive cache reload.');
  }
}

Future<void> _verifyEnemy(Directory temporary, File trackedManifestFile) async {
  final trackedRaw = await trackedManifestFile.readAsString();
  final tracked = jsonDecode(trackedRaw) as Map<String, dynamic>;
  final releaseUri = Uri.parse(tracked['dataUrl'] as String);
  final tag = releaseUri.pathSegments[releaseUri.pathSegments.length - 2];
  final manifestFile = File('${temporary.path}/enemy-manifest.json');
  await _runPython(<String>[
    'tool/build_enemy_release.py',
    'assets/data/enemy_catalog.json',
    manifestFile.path,
    '--tag',
    tag,
  ]);
  final generatedRaw = await manifestFile.readAsString();
  final generated = jsonDecode(generatedRaw) as Map<String, dynamic>;
  if (!_sameJsonDocument(generatedRaw, trackedRaw)) {
    throw StateError('Generated enemy release differs from tracked manifest.');
  }
  final bytes = await File('assets/data/enemy_catalog.json').readAsBytes();
  if (bytes.length != generated['dataBytes'] ||
      sha256.convert(bytes).toString() != generated['dataSha256']) {
    throw StateError('Generated enemy JSON does not match its manifest.');
  }
  final catalog = EnemyCatalogData.fromJsonString(utf8.decode(bytes));
  if (catalog.revision != generated['revision'] ||
      catalog.ships.length != generated['shipCount'] ||
      catalog.aliasCount != generated['aliasCount']) {
    throw StateError('Generated enemy JSON counts do not match its manifest.');
  }
  final oldBundled = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
  oldBundled['revision'] = 1;
  final cacheFile = File('${temporary.path}/enemy-cache.json');
  final store = FileEnemyCatalogStore(
    cacheFile: cacheFile,
    bundledReader: () async => jsonEncode(oldBundled),
  );
  await store.save(catalog);
  final reloaded = await store.loadBestAvailable();
  if (!await cacheFile.exists() ||
      reloaded.revision != catalog.revision ||
      reloaded.ships.length != catalog.ships.length ||
      sha256.convert(utf8.encode(reloaded.rawJson)).toString() !=
          generated['dataSha256']) {
    throw StateError('Generated enemy JSON did not survive cache reload.');
  }
}

Future<void> _runPython(List<String> arguments) async {
  final result = await Process.run('python', arguments);
  if (result.exitCode != 0) {
    throw ProcessException(
      'python',
      arguments,
      '${result.stderr}',
      result.exitCode,
    );
  }
}

Map<String, String> _options(List<String> arguments) {
  const known = <String>{'--sortie-manifest', '--enemy-manifest'};
  if (arguments.length.isOdd) {
    throw const FormatException('Each manifest option requires a path.');
  }
  final options = <String, String>{};
  for (var index = 0; index < arguments.length; index += 2) {
    final key = arguments[index];
    if (!known.contains(key) || options.containsKey(key)) {
      throw FormatException('Unknown or duplicate option: $key');
    }
    options[key] = arguments[index + 1];
  }
  return options;
}

bool _sameJsonDocument(String first, String second) =>
    jsonEncode(_canonicalJson(jsonDecode(first))) ==
    jsonEncode(_canonicalJson(jsonDecode(second)));

Object? _canonicalJson(Object? value) {
  if (value is Map<String, dynamic>) {
    final keys = value.keys.toList()..sort();
    return <String, Object?>{
      for (final key in keys) key: _canonicalJson(value[key]),
    };
  }
  if (value is List) return value.map(_canonicalJson).toList();
  return value;
}

String _appVersion() {
  final line = File(
    'pubspec.yaml',
  ).readAsLinesSync().firstWhere((value) => value.startsWith('version: '));
  return line.substring('version: '.length).trim().split('+').first;
}
