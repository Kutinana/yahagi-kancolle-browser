import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';

import 'game_resource_cache_channel.dart';

final class GameResourceBaselineCatalog {
  const GameResourceBaselineCatalog._();

  static const assetPath =
      'assets/data/game_resource_baseline_manifest.json.gz';
  static const gadgetOrigin = 'https://w00g.kancolle-server.com';

  static Future<Uint8List> loadCompressed({AssetBundle? bundle}) async {
    final data = await (bundle ?? rootBundle).load(assetPath);
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }

  static GameResourceManifest decode({
    required Uint8List compressed,
    required String resourceOrigin,
  }) {
    final decoded = jsonDecode(utf8.decode(gzip.decode(compressed)));
    if (decoded is! Map) {
      throw const FormatException('Baseline manifest must be a JSON object.');
    }
    final manifest = Map<String, Object?>.from(decoded);
    if (_integer(manifest['schemaVersion']) != 1) {
      throw const FormatException('Unsupported baseline manifest schema.');
    }
    final rawEntries = manifest['entries'];
    if (rawEntries is! List) {
      throw const FormatException('Baseline manifest entries are missing.');
    }
    final entriesJson = jsonEncode(rawEntries);
    final expectedHash = manifest['entriesSha256']?.toString() ?? '';
    final actualHash = sha256.convert(utf8.encode(entriesJson)).toString();
    if (expectedHash.isEmpty || expectedHash != actualHash) {
      throw const FormatException('Baseline manifest checksum mismatch.');
    }
    if (_integer(manifest['entryCount']) != rawEntries.length) {
      throw const FormatException('Baseline manifest entry count mismatch.');
    }

    final resourceBase = resourceOrigin.replaceFirst(RegExp(r'/$'), '');
    final urls = <String>[];
    var targetBytes = 0;
    for (final rawEntry in rawEntries) {
      if (rawEntry is! List || rawEntry.length != 3) {
        throw const FormatException('Malformed baseline manifest entry.');
      }
      final path = rawEntry[0];
      final version = rawEntry[1];
      final length = _integer(rawEntry[2]);
      if (path is! String ||
          version is! String ||
          length == null ||
          length < 0 ||
          !_isSafeResourcePath(path) ||
          (version.isNotEmpty && !version.startsWith('?'))) {
        throw const FormatException('Invalid baseline manifest entry.');
      }
      final origin = path.startsWith('/kcs/') || path.startsWith('/kcs2/')
          ? resourceBase
          : gadgetOrigin;
      urls.add('$origin$path$version');
      targetBytes += length;
    }
    if (_integer(manifest['targetBytes']) != targetBytes) {
      throw const FormatException('Baseline manifest byte total mismatch.');
    }
    return GameResourceManifest(
      profile: 'full',
      urls: List<String>.unmodifiable(urls),
      targetBytes: targetBytes,
    );
  }

  static bool _isSafeResourcePath(String path) {
    if (path.contains('..') || path.contains(r'\')) return false;
    return const <String>[
      '/gadget_html5/',
      '/html/',
      '/kcs/',
      '/kcs2/',
      '/kcscontents/',
    ].any(path.startsWith);
  }

  static int? _integer(Object? value) => switch (value) {
    int number => number,
    num number when number.isFinite && number == number.roundToDouble() =>
      number.toInt(),
    _ => null,
  };
}
