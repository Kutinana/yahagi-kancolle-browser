import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_resource_manifest_builder.dart';

void main() {
  const builder = GameResourceManifestBuilder(
    resourceOrigin: 'https://w01y.kancolle-server.com',
  );
  final start2 = <String, Object?>{
    'api_mst_shipgraph': <Object?>[
      <String, Object?>{
        'api_id': 1,
        'api_filename': 'ship_a',
        'api_version': <Object?>['11', '12', '13'],
        'api_battle_n': 1,
        'api_boko_d': 1,
      },
      <String, Object?>{
        'api_id': 2,
        'api_filename': 'ship_b',
        'api_version': <Object?>['21', '22', '23'],
        'api_battle_n': 1,
        'api_boko_d': 1,
      },
    ],
    'api_mst_ship': <Object?>[
      <String, Object?>{'api_id': 1, 'api_name': 'A', 'api_voicef': 0},
      <String, Object?>{'api_id': 2, 'api_name': 'B', 'api_voicef': 0},
    ],
    'api_mst_slotitem': <Object?>[
      <String, Object?>{
        'api_id': 100,
        'api_version': '7',
        'api_type': <Object?>[0, 0, 0, 0, 1],
      },
      <String, Object?>{
        'api_id': 101,
        'api_version': '8',
        'api_type': <Object?>[0, 0, 0, 0, 0],
      },
    ],
    'api_mst_furniture': <Object?>[
      <String, Object?>{'api_id': 5, 'api_active_flag': 0, 'api_version': '4'},
    ],
    'api_mst_mapinfo': <Object?>[
      <String, Object?>{'api_maparea_id': 1, 'api_no': 2},
    ],
    'api_mst_bgm': <Object?>[
      <String, Object?>{'api_id': 145},
    ],
  };
  const staticUrls = <String>[
    '/kcs2/js/main.js?version=123',
    '/kcs2/img/common/common.png?version=9',
  ];

  test('light manifest includes core files and only owned assets', () {
    final manifest = builder.buildLight(
      start2: start2,
      ownedShipMasterIds: const <int>{1},
      ownedSlotItemMasterIds: const <int>{100},
      staticUrls: staticUrls,
    );

    expect(manifest.profile, 'light');
    expect(
      manifest.urls,
      contains('https://w01y.kancolle-server.com/kcs2/js/main.js?version=123'),
    );
    expect(
      manifest.urls.any(
        (url) =>
            url.contains('/ship/full/') &&
            url.contains('_ship_a.png?version=11'),
      ),
      isTrue,
    );
    expect(manifest.urls.any((url) => url.contains('_ship_b.png')), isFalse);
    expect(
      manifest.urls.any(
        (url) => url.contains('/slot/card/0100_') && url.endsWith('?version=7'),
      ),
      isTrue,
    );
    expect(
      manifest.urls.any((url) => url.contains('/slot/card/0101_')),
      isFalse,
    );
    expect(manifest.targetBytes, greaterThan(0));
  });

  test('full manifest includes all master assets maps furniture and sounds', () {
    final manifest = builder.buildFull(start2: start2, staticUrls: staticUrls);

    expect(manifest.profile, 'full');
    expect(
      manifest.urls.any((url) => url.contains('_ship_b.png?version=21')),
      isTrue,
    );
    expect(
      manifest.urls.any(
        (url) => url.contains('/slot/card/0101_') && url.endsWith('?version=8'),
      ),
      isTrue,
    );
    expect(
      manifest.urls,
      contains(
        'https://w01y.kancolle-server.com/kcs2/resources/map/001/02.png',
      ),
    );
    expect(
      manifest.urls.any(
        (url) =>
            url.contains('/furniture/normal/005_') &&
            url.endsWith('?version=4'),
      ),
      isTrue,
    );
    expect(
      manifest.urls,
      contains(
        'https://w01y.kancolle-server.com/kcs2/resources/voice/titlecall_1/001.mp3',
      ),
    );
    expect(
      manifest.urls.any((url) => url.contains('/kcs/sound/kcship_b/')),
      isTrue,
    );
    expect(manifest.urls.toSet().length, manifest.urls.length);
  });
}
