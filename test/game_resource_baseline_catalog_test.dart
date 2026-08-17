import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_resource_baseline_catalog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'decodes verified baseline and maps resource paths to official origins',
    () {
      final entries = <Object?>[
        <Object?>['/kcs2/img/a.png', '?version=1', 2],
        <Object?>['/kcs/sound/a.mp3', '', 3],
        <Object?>['/gadget_html5/js/a.js', '?version=2', 5],
        <Object?>['/html/a.html', '', 7],
        <Object?>['/kcscontents/a.png', '', 11],
      ];
      final compressed = _manifestBytes(entries, targetBytes: 28);

      final manifest = GameResourceBaselineCatalog.decode(
        compressed: compressed,
        resourceOrigin: 'https://w17k.kancolle-server.com/',
      );

      expect(manifest.profile, 'full');
      expect(manifest.targetBytes, 28);
      expect(manifest.urls, <String>[
        'https://w17k.kancolle-server.com/kcs2/img/a.png?version=1',
        'https://w17k.kancolle-server.com/kcs/sound/a.mp3',
        'https://w00g.kancolle-server.com/gadget_html5/js/a.js?version=2',
        'https://w00g.kancolle-server.com/html/a.html',
        'https://w00g.kancolle-server.com/kcscontents/a.png',
      ]);
    },
  );

  test('rejects a baseline whose entries checksum is invalid', () {
    final entries = <Object?>[
      <Object?>['/kcs2/img/a.png', '', 2],
    ];
    final compressed = _manifestBytes(
      entries,
      targetBytes: 2,
      entriesSha256: 'invalid',
    );

    expect(
      () => GameResourceBaselineCatalog.decode(
        compressed: compressed,
        resourceOrigin: 'https://w17k.kancolle-server.com',
      ),
      throwsFormatException,
    );
  });

  test('bundled baseline has the expected verified totals', () async {
    final compressed = await GameResourceBaselineCatalog.loadCompressed();

    final manifest = GameResourceBaselineCatalog.decode(
      compressed: compressed,
      resourceOrigin: 'https://w17k.kancolle-server.com',
    );

    expect(manifest.urls, hasLength(63434));
    expect(manifest.targetBytes, 5744880702);
  });
}

Uint8List _manifestBytes(
  List<Object?> entries, {
  required int targetBytes,
  String? entriesSha256,
}) {
  final entriesJson = jsonEncode(entries);
  final payload = <String, Object?>{
    'schemaVersion': 1,
    'entryCount': entries.length,
    'targetBytes': targetBytes,
    'entriesSha256':
        entriesSha256 ?? sha256.convert(utf8.encode(entriesJson)).toString(),
    'entries': entries,
  };
  return Uint8List.fromList(gzip.encode(utf8.encode(jsonEncode(payload))));
}
