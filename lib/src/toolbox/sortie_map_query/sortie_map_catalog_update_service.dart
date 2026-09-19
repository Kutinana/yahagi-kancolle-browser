import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import 'sortie_map_catalog_manifest.dart';
import 'sortie_map_catalog_store.dart';
import 'sortie_map_models.dart';

const sortieMapManifestSources = <String>[
  'https://raw.githubusercontent.com/yamatosaki/yahagi-kancolle-browser/master/data/sortie/manifest.json',
  'https://cdn.jsdelivr.net/gh/yamatosaki/yahagi-kancolle-browser@master/data/sortie/manifest.json',
];

sealed class SortieMapCatalogUpdateResult {
  const SortieMapCatalogUpdateResult({required this.sourceHost});
  final String sourceHost;
}

final class SortieMapCatalogUpToDate extends SortieMapCatalogUpdateResult {
  const SortieMapCatalogUpToDate(this.version, {required super.sourceHost});
  final SortieMapCatalogVersion version;
}

final class SortieMapCatalogUpdated extends SortieMapCatalogUpdateResult {
  const SortieMapCatalogUpdated(this.catalog, {required super.sourceHost});
  final InstalledSortieMapCatalog catalog;
}

enum SortieMapCatalogUpdateFailure {
  network,
  validation,
  incompatible,
  storage,
}

final class SortieMapCatalogUpdateFailed extends SortieMapCatalogUpdateResult {
  const SortieMapCatalogUpdateFailed(
    this.kind,
    this.error, {
    required super.sourceHost,
  });
  final SortieMapCatalogUpdateFailure kind;
  final Object error;
}

abstract interface class SortieMapCatalogUpdateClient {
  Future<SortieMapCatalogUpdateResult> checkAndUpdate({
    required SortieMapCatalogData current,
  });
}

final class SortieMapCatalogUpdateService
    implements SortieMapCatalogUpdateClient {
  const SortieMapCatalogUpdateService({
    required this.client,
    required this.installer,
    required this.appVersion,
    this.timeout = const Duration(seconds: 20),
    this.maximumManifestBytes = 64 * 1024,
    this.maximumArchiveBytes = 64 * 1024 * 1024,
  });

  final http.Client client;
  final SortieMapCatalogInstaller installer;
  final String appVersion;
  final Duration timeout;
  final int maximumManifestBytes;
  final int maximumArchiveBytes;

  @override
  Future<SortieMapCatalogUpdateResult> checkAndUpdate({
    required SortieMapCatalogData current,
  }) async {
    var sourceHost = '';
    try {
      final downloaded = await _downloadManifest();
      sourceHost = downloaded.$2;
      final manifest = SortieMapCatalogManifest.fromJsonString(
        utf8.decode(downloaded.$1),
      );
      if (!manifest.isCompatibleWith(appVersion)) {
        return SortieMapCatalogUpdateFailed(
          SortieMapCatalogUpdateFailure.incompatible,
          StateError(
            'App $appVersion is older than ${manifest.minimumAppVersion}.',
          ),
          sourceHost: sourceHost,
        );
      }
      if (manifest.version.compareTo(current.versionInfo) <= 0) {
        return SortieMapCatalogUpToDate(
          current.versionInfo,
          sourceHost: sourceHost,
        );
      }
      if (manifest.archiveBytes > maximumArchiveBytes) {
        throw const FormatException(
          'Sortie archive exceeds the download limit.',
        );
      }
      final archive = await _get(manifest.releaseUri, maximumArchiveBytes);
      if (archive.length != manifest.archiveBytes ||
          sha256.convert(archive).toString() != manifest.archiveSha256) {
        throw const FormatException(
          'Sortie archive digest or size does not match manifest.',
        );
      }
      try {
        final installed = await installer.installArchive(
          archive,
          expected: SortieMapCatalogInstallExpectation(
            version: manifest.version,
            mapCount: manifest.mapCount,
            nodeCount: manifest.nodeCount,
            formationCount: manifest.formationCount,
          ),
        );
        if (installed.data.revision != manifest.version.revision ||
            installed.data.maps.length != manifest.mapCount ||
            installed.data.maps.fold<int>(
                  0,
                  (sum, map) => sum + map.nodes.length,
                ) !=
                manifest.nodeCount ||
            installed.data.maps.fold<int>(
                  0,
                  (sum, map) =>
                      sum +
                      map.nodes.fold<int>(
                        0,
                        (count, node) => count + node.formations.length,
                      ),
                ) !=
                manifest.formationCount) {
          throw const FormatException(
            'Installed sortie catalog does not match manifest counts.',
          );
        }
        return SortieMapCatalogUpdated(installed, sourceHost: sourceHost);
      } on FileSystemException catch (error) {
        return SortieMapCatalogUpdateFailed(
          SortieMapCatalogUpdateFailure.storage,
          error,
          sourceHost: sourceHost,
        );
      }
    } on FormatException catch (error) {
      return SortieMapCatalogUpdateFailed(
        SortieMapCatalogUpdateFailure.validation,
        error,
        sourceHost: sourceHost,
      );
    } on Object catch (error) {
      return SortieMapCatalogUpdateFailed(
        SortieMapCatalogUpdateFailure.network,
        error,
        sourceHost: sourceHost,
      );
    }
  }

  Future<(List<int>, String)> _downloadManifest() async {
    Object? lastError;
    for (final value in sortieMapManifestSources) {
      final uri = Uri.parse(value);
      try {
        return (await _get(uri, maximumManifestBytes), uri.host);
      } on Object catch (error) {
        lastError = error;
      }
    }
    throw lastError ??
        const HttpException('No sortie manifest source is available.');
  }

  Future<List<int>> _get(Uri uri, int maximumBytes) async {
    final allowedManifest = sortieMapManifestSources
        .map(Uri.parse)
        .contains(uri);
    final allowedArchive =
        uri.scheme == 'https' &&
        uri.host == 'github.com' &&
        uri.path.startsWith(
          '/yamatosaki/yahagi-kancolle-browser/releases/download/',
        );
    if (uri.scheme != 'https' || (!allowedManifest && !allowedArchive)) {
      throw FormatException('Sortie update URL is not allowed: $uri');
    }
    final request = http.Request('GET', uri)
      ..headers['User-Agent'] = 'Yahagi-Kancolle-Browser/$appVersion';
    final response = await client.send(request).timeout(timeout);
    if (response.statusCode != 200) {
      throw http.ClientException(
        'Sortie update failed with HTTP ${response.statusCode}',
        uri,
      );
    }
    final contentLength = response.contentLength;
    if (contentLength != null && contentLength > maximumBytes) {
      throw const FormatException('Sortie update response is too large.');
    }
    final bytes = <int>[];
    await for (final chunk in response.stream.timeout(timeout)) {
      if (bytes.length + chunk.length > maximumBytes) {
        throw const FormatException('Sortie update response is too large.');
      }
      bytes.addAll(chunk);
    }
    return bytes;
  }
}
