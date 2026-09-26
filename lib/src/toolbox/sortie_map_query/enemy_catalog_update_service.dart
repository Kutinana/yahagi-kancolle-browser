import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:pub_semver/pub_semver.dart';

import 'enemy_catalog.dart';
import 'enemy_catalog_store.dart';

const enemyCatalogManifestSources = <String>[
  'https://raw.githubusercontent.com/yamatosaki/yahagi-kancolle-browser/master/data/enemy/manifest.json',
  'https://cdn.jsdelivr.net/gh/yamatosaki/yahagi-kancolle-browser@master/data/enemy/manifest.json',
];

sealed class EnemyCatalogUpdateResult {
  const EnemyCatalogUpdateResult({required this.sourceHost});
  final String sourceHost;
}

final class EnemyCatalogUpToDate extends EnemyCatalogUpdateResult {
  const EnemyCatalogUpToDate(this.catalog, {required super.sourceHost});
  final EnemyCatalogData catalog;
}

final class EnemyCatalogUpdated extends EnemyCatalogUpdateResult {
  const EnemyCatalogUpdated(this.catalog, {required super.sourceHost});
  final EnemyCatalogData catalog;
}

enum EnemyCatalogUpdateFailure { network, validation, incompatible, storage }

final class EnemyCatalogUpdateFailed extends EnemyCatalogUpdateResult {
  const EnemyCatalogUpdateFailed(
    this.kind,
    this.error, {
    required super.sourceHost,
  });
  final EnemyCatalogUpdateFailure kind;
  final Object error;
}

abstract interface class EnemyCatalogUpdateClient {
  Future<EnemyCatalogUpdateResult> checkAndUpdate({
    required EnemyCatalogData current,
  });
}

final class EnemyCatalogUpdateService implements EnemyCatalogUpdateClient {
  const EnemyCatalogUpdateService({
    required this.client,
    required this.store,
    required this.appVersion,
    this.timeout = const Duration(seconds: 20),
    this.maximumManifestDuration = const Duration(minutes: 1),
    this.maximumDataDuration = const Duration(minutes: 5),
    this.maximumManifestBytes = 64 * 1024,
    this.maximumDataBytes = 4 * 1024 * 1024,
  });

  final http.Client client;
  final FileEnemyCatalogStore store;
  final String appVersion;
  final Duration timeout;
  final Duration maximumManifestDuration;
  final Duration maximumDataDuration;
  final int maximumManifestBytes;
  final int maximumDataBytes;

  @override
  Future<EnemyCatalogUpdateResult> checkAndUpdate({
    required EnemyCatalogData current,
  }) async {
    var sourceHost = '';
    try {
      final downloaded = await _downloadManifest();
      sourceHost = downloaded.$2;
      final manifest = _EnemyCatalogManifest.parse(utf8.decode(downloaded.$1));
      if (Version.parse(appVersion) <
          Version.parse(manifest.minimumAppVersion)) {
        return EnemyCatalogUpdateFailed(
          EnemyCatalogUpdateFailure.incompatible,
          StateError('Enemy catalog requires ${manifest.minimumAppVersion}.'),
          sourceHost: sourceHost,
        );
      }
      if (manifest.revision <= current.revision) {
        return EnemyCatalogUpToDate(current, sourceHost: sourceHost);
      }
      if (manifest.dataBytes > maximumDataBytes) {
        throw const FormatException('Enemy catalog exceeds the size limit.');
      }
      final bytes = await _get(
        manifest.dataUri,
        maximumDataBytes,
        maximumDataDuration,
      );
      if (bytes.length != manifest.dataBytes ||
          sha256.convert(bytes).toString() != manifest.dataSha256) {
        throw const FormatException('Enemy catalog digest does not match.');
      }
      final catalog = EnemyCatalogData.fromJsonString(utf8.decode(bytes));
      if (catalog.revision != manifest.revision ||
          catalog.dataVersion != manifest.dataVersion ||
          catalog.ships.length != manifest.shipCount ||
          catalog.aliasCount != manifest.aliasCount) {
        throw const FormatException('Enemy catalog does not match manifest.');
      }
      try {
        await store.save(catalog);
      } on IOException catch (error) {
        return EnemyCatalogUpdateFailed(
          EnemyCatalogUpdateFailure.storage,
          error,
          sourceHost: sourceHost,
        );
      }
      return EnemyCatalogUpdated(catalog, sourceHost: sourceHost);
    } on FormatException catch (error) {
      return EnemyCatalogUpdateFailed(
        EnemyCatalogUpdateFailure.validation,
        error,
        sourceHost: sourceHost,
      );
    } on Object catch (error) {
      return EnemyCatalogUpdateFailed(
        EnemyCatalogUpdateFailure.network,
        error,
        sourceHost: sourceHost,
      );
    }
  }

  Future<(List<int>, String)> _downloadManifest() async {
    Object? lastError;
    for (final source in enemyCatalogManifestSources) {
      final uri = Uri.parse(source);
      try {
        return (
          await _get(uri, maximumManifestBytes, maximumManifestDuration),
          uri.host,
        );
      } on Object catch (error) {
        lastError = error;
      }
    }
    throw lastError ?? const HttpException('No enemy manifest is available.');
  }

  Future<List<int>> _get(
    Uri uri,
    int maximumBytes,
    Duration maximumDuration,
  ) async {
    return _getWithRedirects(
      uri,
      maximumBytes,
      DateTime.now().add(maximumDuration),
    );
  }

  Future<List<int>> _getWithRedirects(
    Uri uri,
    int maximumBytes,
    DateTime overallDeadline,
  ) async {
    if (!_isAllowed(uri)) {
      throw FormatException('Enemy update URL is not allowed: $uri');
    }
    var requestUri = uri;
    http.StreamedResponse? response;
    Completer<void>? responseAbort;
    late DateTime idleDeadline;
    for (var redirects = 0; redirects <= 5; redirects++) {
      idleDeadline = DateTime.now().add(timeout);
      final abort = Completer<void>();
      final request =
          http.AbortableRequest('GET', requestUri, abortTrigger: abort.future)
            ..followRedirects = false
            ..headers['User-Agent'] = 'Yahagi-Kancolle-Browser/$appVersion';
      response = await client
          .send(request)
          .timeout(
            _enemyShorter(
              _enemyRemaining(idleDeadline),
              _enemyRemaining(overallDeadline),
            ),
            onTimeout: () {
              if (!abort.isCompleted) abort.complete();
              throw TimeoutException('Enemy update request timed out.');
            },
          );
      if (_isRedirect(response.statusCode)) {
        final location = response.headers['location'];
        if (location == null || redirects == 5) {
          await _discardEnemyResponse(response, abort);
          throw const FormatException('Enemy update redirect is invalid.');
        }
        final redirected = requestUri.resolve(location);
        if (!_isAllowedReleaseRedirect(redirected)) {
          await _discardEnemyResponse(response, abort);
          throw FormatException('Enemy redirect is not allowed: $redirected');
        }
        await _discardEnemyResponse(response, abort);
        requestUri = redirected;
        continue;
      }
      responseAbort = abort;
      break;
    }
    if (response == null) {
      throw const HttpException('Enemy update returned no response.');
    }
    if (response.statusCode != 200) {
      await _discardEnemyResponse(response, responseAbort!);
      throw http.ClientException(
        'Enemy update failed with HTTP ${response.statusCode}',
        requestUri,
      );
    }
    if (response.contentLength case final length? when length > maximumBytes) {
      await _discardEnemyResponse(response, responseAbort!);
      throw const FormatException('Enemy update response is too large.');
    }
    return _readEnemyResponse(
      response,
      maximumBytes,
      idleDeadline,
      overallDeadline,
      timeout,
      responseAbort!,
    );
  }
}

Future<void> _discardEnemyResponse(
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
    // The request is already invalid and its response is being discarded.
  }
}

Duration _enemyRemaining(DateTime deadline) {
  final value = deadline.difference(DateTime.now());
  if (value <= Duration.zero) {
    throw TimeoutException('Enemy update request timed out.');
  }
  return value;
}

Duration _enemyShorter(Duration first, Duration second) =>
    first < second ? first : second;

Future<Uint8List> _readEnemyResponse(
  http.StreamedResponse response,
  int maximumBytes,
  DateTime idleDeadline,
  DateTime overallDeadline,
  Duration idleTimeout,
  Completer<void> abort,
) async {
  final bytes = BytesBuilder(copy: false);
  final result = Completer<Uint8List>();
  StreamSubscription<List<int>>? subscription;
  var cancelWhenSubscribed = false;
  var sawChunk = false;
  Timer? idleTimer;
  Timer? overallTimer;
  void cancelSubscription() {
    final active = subscription;
    if (active == null) {
      cancelWhenSubscribed = true;
    } else {
      unawaited(active.cancel());
    }
  }

  void failOnTimeout(String message) {
    if (!result.isCompleted) result.completeError(TimeoutException(message));
    if (!abort.isCompleted) abort.complete();
    cancelSubscription();
  }

  subscription = response.stream.listen(
    (chunk) {
      if (result.isCompleted) return;
      sawChunk = true;
      idleTimer?.cancel();
      idleTimer = Timer(
        idleTimeout,
        () => failOnTimeout('Enemy update response stalled.'),
      );
      if (bytes.length + chunk.length > maximumBytes) {
        result.completeError(
          const FormatException('Enemy update response is too large.'),
        );
        if (!abort.isCompleted) abort.complete();
        cancelSubscription();
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
  if (cancelWhenSubscribed) cancelSubscription();
  try {
    if (!result.isCompleted) {
      if (!sawChunk) {
        idleTimer = Timer(
          _enemyRemaining(idleDeadline),
          () => failOnTimeout('Enemy update response stalled.'),
        );
      }
      overallTimer = Timer(
        _enemyRemaining(overallDeadline),
        () => failOnTimeout('Enemy update response timed out.'),
      );
    }
    return await result.future;
  } on TimeoutException {
    if (!abort.isCompleted) abort.complete();
    rethrow;
  } finally {
    idleTimer?.cancel();
    overallTimer?.cancel();
    await subscription.cancel();
  }
}

final class _EnemyCatalogManifest {
  const _EnemyCatalogManifest({
    required this.dataVersion,
    required this.revision,
    required this.minimumAppVersion,
    required this.dataUri,
    required this.dataBytes,
    required this.dataSha256,
    required this.shipCount,
    required this.aliasCount,
  });

  factory _EnemyCatalogManifest.parse(String raw) {
    final json = jsonDecode(raw);
    if (json is! Map<String, dynamic> || json['schemaVersion'] != 1) {
      throw const FormatException('Enemy manifest is invalid.');
    }
    final url = json['dataUrl'];
    final sha = json['dataSha256'];
    if (url is! String ||
        sha is! String ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(sha)) {
      throw const FormatException(
        'Enemy manifest download fields are invalid.',
      );
    }
    final manifest = _EnemyCatalogManifest(
      dataVersion: _manifestString(json, 'dataVersion'),
      revision: _manifestInt(json, 'revision'),
      minimumAppVersion: _manifestString(json, 'minimumAppVersion'),
      dataUri: Uri.parse(url),
      dataBytes: _manifestInt(json, 'dataBytes'),
      dataSha256: sha,
      shipCount: _manifestInt(json, 'shipCount'),
      aliasCount: _manifestInt(json, 'aliasCount'),
    );
    Version.parse(manifest.minimumAppVersion);
    if (DateTime.tryParse(_manifestString(json, 'publishedAt')) == null ||
        !manifest.dataUri.hasScheme ||
        manifest.revision <= 0 ||
        manifest.dataBytes <= 0 ||
        manifest.shipCount <= 0 ||
        manifest.aliasCount <= 0) {
      throw const FormatException('Enemy manifest values are invalid.');
    }
    return manifest;
  }

  final String dataVersion;
  final int revision;
  final String minimumAppVersion;
  final Uri dataUri;
  final int dataBytes;
  final String dataSha256;
  final int shipCount;
  final int aliasCount;
}

String _manifestString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('Enemy manifest $key is invalid.');
  }
  return value;
}

int _manifestInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! int || value < 0) {
    throw FormatException('Enemy manifest $key is invalid.');
  }
  return value;
}

bool _isAllowed(Uri uri) {
  if (uri.scheme != 'https') return false;
  if (enemyCatalogManifestSources.map(Uri.parse).contains(uri)) return true;
  return uri.host == 'github.com' &&
      uri.path.startsWith(
        '/yamatosaki/yahagi-kancolle-data/releases/download/',
      );
}

bool _isAllowedReleaseRedirect(Uri uri) =>
    uri.scheme == 'https' &&
    const <String>{
      'github.com',
      'release-assets.githubusercontent.com',
      'objects.githubusercontent.com',
    }.contains(uri.host);

bool _isRedirect(int status) =>
    status == 301 ||
    status == 302 ||
    status == 303 ||
    status == 307 ||
    status == 308;
