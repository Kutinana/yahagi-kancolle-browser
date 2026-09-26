// Builds both maintained data releases and checks them with the app's runtime
// parsers and persistent stores. Run from the repository root with `dart run`.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/sortie_map_query/enemy_catalog.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/sortie_map_query/enemy_catalog_store.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/sortie_map_query/sortie_map_catalog_manifest.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/sortie_map_query/sortie_map_catalog_store.dart';

Future<void> main(List<String> arguments) async {
  final localOnly = arguments.contains('--local-only');
  if (arguments.where((value) => value == '--local-only').length > 1) {
    throw const FormatException('Duplicate --local-only option.');
  }
  final options = _options(List<String>.of(arguments)..remove('--local-only'));
  final temporary = await Directory.systemTemp.createTemp(
    'yahagi-data-contract-',
  );
  try {
    final appVersion = _appVersion();
    final sortie = await _verifySortie(
      temporary,
      appVersion,
      File(options['--sortie-manifest'] ?? 'data/sortie/manifest.json'),
    );
    final enemy = await _verifyEnemy(
      temporary,
      File(options['--enemy-manifest'] ?? 'data/enemy/manifest.json'),
    );
    if (!localOnly) {
      await _verifyPublishedSortie(temporary, appVersion, sortie.$1, sortie.$2);
      await _verifyPublishedEnemy(enemy.$1, enemy.$2);
    }
    stdout.writeln(
      localOnly
          ? 'Local data release contract passed.'
          : 'Data release contract passed: published sortie ZIP and enemy JSON.',
    );
  } finally {
    await temporary.delete(recursive: true);
  }
}

Future<(SortieMapCatalogManifest, InstalledSortieMapCatalog)> _verifySortie(
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
  if (!_sameSortieManifest(generatedRaw, trackedRaw)) {
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
  return (trackedManifest, installed);
}

Future<(Map<String, dynamic>, List<int>)> _verifyEnemy(
  Directory temporary,
  File trackedManifestFile,
) async {
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
  return (tracked, bytes);
}

Future<void> _verifyPublishedSortie(
  Directory temporary,
  String appVersion,
  SortieMapCatalogManifest manifest,
  InstalledSortieMapCatalog generated,
) async {
  final publishedBytes = await _downloadPublished(
    manifest.releaseUri,
    maximumBytes: 64 * 1024 * 1024,
  );
  if (publishedBytes.length != manifest.archiveBytes ||
      sha256.convert(publishedBytes).toString() != manifest.archiveSha256) {
    throw StateError('Published sortie ZIP does not match tracked manifest.');
  }
  final publishedStore = FileSortieMapCatalogStore(
    root: Directory('${temporary.path}/sortie-published'),
    currentAppVersion: appVersion,
  );
  final published = await publishedStore.installArchive(
    publishedBytes,
    expected: SortieMapCatalogInstallExpectation(
      version: manifest.version,
      mapCount: manifest.mapCount,
      nodeCount: manifest.nodeCount,
      formationCount: manifest.formationCount,
      minimumAppVersion: manifest.minimumAppVersion,
    ),
  );
  // The runtime installer bounds and validates every ZIP member before writing
  // the exact decoded bytes to each version directory.
  final generatedFiles = await _installedFileNames(generated);
  final publishedFiles = await _installedFileNames(published);
  if (generatedFiles.length != publishedFiles.length ||
      !generatedFiles.containsAll(publishedFiles)) {
    throw StateError('Published sortie ZIP member names differ from source.');
  }
  for (final name in generatedFiles) {
    if (!_sameBytes(
      await generated.resolve(name).readAsBytes(),
      await published.resolve(name).readAsBytes(),
    )) {
      throw StateError(
        'Published sortie ZIP member differs from source: $name',
      );
    }
  }
}

Future<Set<String>> _installedFileNames(
  InstalledSortieMapCatalog installed,
) async {
  final raw = await File(
    '${installed.root.path}/.install-metadata.json',
  ).readAsString();
  final metadata = jsonDecode(raw) as Map<String, dynamic>;
  return (metadata['files'] as Map<String, dynamic>).keys.toSet();
}

Future<void> _verifyPublishedEnemy(
  Map<String, dynamic> manifest,
  List<int> sourceBytes,
) async {
  final uri = Uri.parse(manifest['dataUrl'] as String);
  final publishedBytes = await _downloadPublished(
    uri,
    maximumBytes: 4 * 1024 * 1024,
  );
  if (publishedBytes.length != manifest['dataBytes'] ||
      sha256.convert(publishedBytes).toString() != manifest['dataSha256']) {
    throw StateError('Published enemy JSON does not match tracked manifest.');
  }
  if (!_sameBytes(sourceBytes, publishedBytes)) {
    throw StateError('Published enemy JSON differs from tracked source.');
  }
}

bool _sameBytes(List<int> first, List<int> second) {
  if (first.length != second.length) return false;
  for (var index = 0; index < first.length; index++) {
    if (first[index] != second[index]) return false;
  }
  return true;
}

Future<List<int>> _downloadPublished(
  Uri uri, {
  required int maximumBytes,
}) async {
  if (uri.scheme != 'https' ||
      uri.host != 'github.com' ||
      !uri.path.startsWith(
        '/yamatosaki/yahagi-kancolle-data/releases/download/',
      )) {
    throw FormatException('Unexpected published release URL: $uri');
  }
  Object? lastError;
  for (var attempt = 0; attempt < 2; attempt++) {
    final client = HttpClient()..autoUncompress = false;
    try {
      return await _readPublished(
        client,
        uri,
        maximumBytes,
      ).timeout(const Duration(minutes: 5));
    } on SocketException catch (error) {
      lastError = error;
    } on HttpException catch (error) {
      lastError = error;
    } on TimeoutException catch (error) {
      lastError = error;
    } finally {
      client.close(force: true);
    }
  }
  throw StateError(
    'Published release download failed after two attempts: $lastError',
  );
}

Future<List<int>> _readPublished(
  HttpClient client,
  Uri uri,
  int maximumBytes,
) async {
  const allowedHosts = <String>{
    'github.com',
    'release-assets.githubusercontent.com',
    'objects.githubusercontent.com',
  };
  var current = uri;
  HttpClientResponse? response;
  for (var hop = 0; hop <= 5; hop++) {
    final request = await client.getUrl(current);
    request.followRedirects = false;
    response = await request.close();
    if (response.statusCode == HttpStatus.ok) break;
    if (!const <int>{301, 302, 303, 307, 308}.contains(response.statusCode) ||
        hop == 5) {
      throw HttpException('Unexpected release response', uri: current);
    }
    final location = response.headers.value(HttpHeaders.locationHeader);
    if (location == null) {
      throw HttpException('Release redirect has no location', uri: current);
    }
    final next = current.resolve(location);
    if (next.scheme != 'https' || !allowedHosts.contains(next.host)) {
      throw HttpException('Untrusted release redirect', uri: next);
    }
    await response.drain<void>();
    current = next;
  }
  if (response == null || response.statusCode != HttpStatus.ok) {
    throw HttpException('Release download did not complete', uri: current);
  }
  if (response.contentLength > maximumBytes) {
    throw StateError('Published release exceeds download limit.');
  }
  final data = BytesBuilder(copy: false);
  await for (final chunk in response.timeout(const Duration(seconds: 30))) {
    if (data.length + chunk.length > maximumBytes) {
      throw StateError('Published release exceeds download limit.');
    }
    data.add(chunk);
  }
  return data.takeBytes();
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

bool _sameSortieManifest(String generatedRaw, String trackedRaw) {
  final generated = jsonDecode(generatedRaw) as Map<String, dynamic>;
  final tracked = jsonDecode(trackedRaw) as Map<String, dynamic>;
  // ZIP compression bytes vary with zlib version. Compare all semantic fields
  // here, then bind the published digest to the real downloaded ZIP above.
  final generatedArchive = generated['archive'] as Map<String, dynamic>;
  final trackedArchive = tracked['archive'] as Map<String, dynamic>;
  generatedArchive['bytes'] = trackedArchive['bytes'];
  generatedArchive['sha256'] = trackedArchive['sha256'];
  return jsonEncode(_canonicalJson(generated)) ==
      jsonEncode(_canonicalJson(tracked));
}

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
