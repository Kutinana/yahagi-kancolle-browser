import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

typedef ShipPortraitCacheDirectoryProvider = Future<Directory> Function();

class ShipPortraitCache {
  static int _temporaryFileSequence = 0;

  ShipPortraitCache({
    required this.directoryProvider,
    required this.client,
    this.requestTimeout = const Duration(seconds: 15),
    this.maximumResponseBytes = 8 * 1024 * 1024,
  });

  static final ShipPortraitCache shared = ShipPortraitCache(
    directoryProvider: () async {
      final support = await getApplicationSupportDirectory();
      return Directory(path.join(support.path, 'ship_portraits'));
    },
    client: http.Client(),
  );

  final ShipPortraitCacheDirectoryProvider directoryProvider;
  final http.Client client;
  final Duration requestTimeout;
  final int maximumResponseBytes;
  final Map<String, Future<File?>> _inFlight = <String, Future<File?>>{};
  final Map<String, Future<void>> _serialTails = <String, Future<void>>{};

  Future<File?> resolve({required String cacheKey, required Uri uri}) {
    if ((uri.scheme != 'http' && uri.scheme != 'https') || uri.host.isEmpty) {
      return Future<File?>.value();
    }
    final requestKey = '$cacheKey|$uri';
    final existing = _inFlight[requestKey];
    if (existing != null) return existing;

    final previous = _serialTails[cacheKey] ?? Future<void>.value();
    final operation = previous.then(
      (_) => _resolve(cacheKey: cacheKey, uri: uri),
    );
    _inFlight[requestKey] = operation;
    final tail = operation.then<void>((_) {});
    _serialTails[cacheKey] = tail;
    operation.whenComplete(() {
      if (identical(_inFlight[requestKey], operation)) {
        _inFlight.remove(requestKey);
      }
    });
    tail.whenComplete(() {
      if (identical(_serialTails[cacheKey], tail)) {
        _serialTails.remove(cacheKey);
      }
    });
    return operation;
  }

  Future<void> evict({required String cacheKey, required Uri uri}) async {
    try {
      final directory = await directoryProvider();
      final file = _cacheFile(
        directory: directory,
        cacheKey: cacheKey,
        uri: uri,
      );
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Decode failure eviction is best-effort; the placeholder remains usable.
    }
  }

  Future<File?> _resolve({required String cacheKey, required Uri uri}) async {
    File? temporary;
    try {
      final directory = await directoryProvider();
      await directory.create(recursive: true);
      final safeKey = _safeCacheKey(cacheKey);
      final file = _cacheFile(
        directory: directory,
        cacheKey: cacheKey,
        uri: uri,
      );
      if (await _isValidPngFile(file)) return file;
      if (await file.exists()) await file.delete();

      final response = await client.get(uri).timeout(requestTimeout);
      if (response.statusCode != HttpStatus.ok ||
          response.bodyBytes.isEmpty ||
          response.bodyBytes.length > maximumResponseBytes ||
          !_hasPngSignature(response.bodyBytes)) {
        return null;
      }

      temporary = File('${file.path}.${pid}_${_temporaryFileSequence++}.tmp');
      await temporary.writeAsBytes(response.bodyBytes, flush: true);
      if (await file.exists()) {
        if (await _isValidPngFile(file)) {
          await temporary.delete();
        } else {
          await file.delete();
        }
      }
      if (await temporary.exists()) {
        try {
          await temporary.rename(file.path);
        } on FileSystemException {
          if (await _isValidPngFile(file)) {
            await temporary.delete();
          } else {
            if (await file.exists()) await file.delete();
            await temporary.rename(file.path);
          }
        }
      }
      await _removeOlderVersions(
        directory: directory,
        safeKey: safeKey,
        keepPath: file.path,
      );
      return file;
    } catch (_) {
      return null;
    } finally {
      try {
        if (temporary != null && await temporary.exists()) {
          await temporary.delete();
        }
      } catch (_) {
        // A failed download must never make temporary files user-visible.
      }
    }
  }

  File _cacheFile({
    required Directory directory,
    required String cacheKey,
    required Uri uri,
  }) {
    final digest = sha256.convert(uri.toString().codeUnits).toString();
    return File(
      path.join(directory.path, '${_safeCacheKey(cacheKey)}-$digest.png'),
    );
  }

  String _safeCacheKey(String cacheKey) =>
      cacheKey.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');

  Future<bool> _isValidPngFile(File file) async {
    if (!await file.exists() || await file.length() < _pngSignature.length) {
      return false;
    }
    RandomAccessFile? handle;
    try {
      handle = await file.open();
      return _hasPngSignature(await handle.read(_pngSignature.length));
    } catch (_) {
      return false;
    } finally {
      await handle?.close();
    }
  }

  bool _hasPngSignature(List<int> bytes) {
    if (bytes.length < _pngSignature.length) return false;
    for (var index = 0; index < _pngSignature.length; index++) {
      if (bytes[index] != _pngSignature[index]) return false;
    }
    return true;
  }

  static const List<int> _pngSignature = <int>[
    0x89,
    0x50,
    0x4e,
    0x47,
    0x0d,
    0x0a,
    0x1a,
    0x0a,
  ];

  Future<void> _removeOlderVersions({
    required Directory directory,
    required String safeKey,
    required String keepPath,
  }) async {
    await for (final entity in directory.list()) {
      if (entity is! File ||
          entity.path == keepPath ||
          !path.basename(entity.path).startsWith('$safeKey-') ||
          !entity.path.endsWith('.png')) {
        continue;
      }
      try {
        await entity.delete();
      } catch (_) {
        // A stale version may be in use by another image decode. It can be
        // cleaned the next time this portrait receives a newer version.
      }
    }
  }
}
