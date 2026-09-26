import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

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
    this.beforeBodyRead,
  });

  final http.Client client;
  final SortieMapCatalogInstaller installer;
  final String appVersion;
  final Duration timeout;
  final int maximumManifestBytes;
  final int maximumArchiveBytes;
  final Future<void> Function(Uri uri)? beforeBodyRead;

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
            minimumAppVersion: manifest.minimumAppVersion,
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
    return _getWithRedirects(uri, maximumBytes, DateTime.now().add(timeout));
  }

  Future<List<int>> _getWithRedirects(
    Uri uri,
    int maximumBytes,
    DateTime deadline,
  ) async {
    final allowedManifest = sortieMapManifestSources
        .map(Uri.parse)
        .contains(uri);
    final allowedArchive =
        uri.scheme == 'https' &&
        uri.host == 'github.com' &&
        uri.path.startsWith(
          '/yamatosaki/yahagi-kancolle-data/releases/download/',
        );
    if (uri.scheme != 'https' || (!allowedManifest && !allowedArchive)) {
      throw FormatException('Sortie update URL is not allowed: $uri');
    }
    var requestUri = uri;
    http.StreamedResponse? response;
    Completer<void>? responseAbort;
    for (var redirects = 0; redirects <= 5; redirects++) {
      final abort = Completer<void>();
      final request =
          http.AbortableRequest('GET', requestUri, abortTrigger: abort.future)
            ..followRedirects = false
            ..headers['User-Agent'] = 'Yahagi-Kancolle-Browser/$appVersion';
      response = await client
          .send(request)
          .timeout(
            _remaining(deadline),
            onTimeout: () {
              if (!abort.isCompleted) abort.complete();
              throw TimeoutException('Sortie update request timed out.');
            },
          );
      if (!_isRedirectStatus(response.statusCode)) {
        responseAbort = abort;
        break;
      }
      final location = response.headers['location'];
      if (!allowedArchive || location == null || redirects == 5) {
        await _discardResponse(response, abort);
        throw const FormatException('Sortie update redirect is not allowed.');
      }
      final redirected = requestUri.resolve(location);
      if (!_isAllowedReleaseRedirect(redirected)) {
        await _discardResponse(response, abort);
        throw FormatException(
          'Sortie update redirect host is not allowed: ${redirected.host}',
        );
      }
      await _discardResponse(response, abort);
      requestUri = redirected;
    }
    if (response == null) {
      throw const HttpException('Sortie update returned no response.');
    }
    if (response.statusCode != 200) {
      await _discardResponse(response, responseAbort!);
      throw http.ClientException(
        'Sortie update failed with HTTP ${response.statusCode}',
        requestUri,
      );
    }
    final contentLength = response.contentLength;
    if (contentLength != null && contentLength > maximumBytes) {
      await _discardResponse(response, responseAbort!);
      throw const FormatException('Sortie update response is too large.');
    }
    await beforeBodyRead?.call(requestUri);
    return _readResponse(response, maximumBytes, deadline, responseAbort!);
  }
}

Future<void> _discardResponse(
  http.StreamedResponse response,
  Completer<void> abort,
) async {
  final subscription = response.stream.listen(
    (_) {},
    onError: (Object _) {},
    cancelOnError: true,
  );
  if (!abort.isCompleted) abort.complete();
  try {
    await subscription.cancel();
  } on Object {
    // The response is being discarded because its request is already invalid.
  }
}

Duration _remaining(DateTime deadline) {
  final value = deadline.difference(DateTime.now());
  if (value <= Duration.zero) {
    throw TimeoutException('Sortie update request timed out.');
  }
  return value;
}

Future<Uint8List> _readResponse(
  http.StreamedResponse response,
  int maximumBytes,
  DateTime deadline,
  Completer<void> abort,
) async {
  final bytes = BytesBuilder(copy: false);
  final result = Completer<Uint8List>();
  late StreamSubscription<List<int>> subscription;
  subscription = response.stream.listen(
    (chunk) {
      if (result.isCompleted) return;
      if (bytes.length + chunk.length > maximumBytes) {
        result.completeError(
          const FormatException('Sortie update response is too large.'),
        );
        if (!abort.isCompleted) abort.complete();
        unawaited(subscription.cancel());
        return;
      }
      bytes.add(chunk);
    },
    onError: (Object error, StackTrace stackTrace) {
      if (!result.isCompleted) result.completeError(error, stackTrace);
    },
    onDone: () {
      if (!result.isCompleted) result.complete(bytes.takeBytes());
    },
    cancelOnError: true,
  );
  Timer? timer;
  try {
    timer = Timer(_remaining(deadline), () {
      if (!result.isCompleted) {
        result.completeError(
          TimeoutException('Sortie update response timed out.'),
        );
      }
      if (!abort.isCompleted) abort.complete();
      unawaited(subscription.cancel());
    });
    return await result.future;
  } on TimeoutException {
    if (!abort.isCompleted) abort.complete();
    rethrow;
  } finally {
    timer?.cancel();
    await subscription.cancel();
  }
}

bool _isAllowedReleaseRedirect(Uri uri) =>
    uri.scheme == 'https' &&
    const <String>{
      'github.com',
      'release-assets.githubusercontent.com',
      'objects.githubusercontent.com',
    }.contains(uri.host);

bool _isRedirectStatus(int statusCode) =>
    statusCode == 301 ||
    statusCode == 302 ||
    statusCode == 303 ||
    statusCode == 307 ||
    statusCode == 308;
