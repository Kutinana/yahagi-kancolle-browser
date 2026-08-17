import 'dart:convert';

import 'package:flutter/services.dart';

import 'game_resource_cache_channel.dart';

final class GameResourceManifestBuilder {
  const GameResourceManifestBuilder({required this.resourceOrigin});

  final String resourceOrigin;

  GameResourceManifest buildLight({
    required Map<String, Object?> start2,
    required Set<int> ownedShipMasterIds,
    required Set<int> ownedSlotItemMasterIds,
    required List<String> staticUrls,
  }) => _build(
    profile: 'light',
    start2: start2,
    shipIds: ownedShipMasterIds,
    slotItemIds: ownedSlotItemMasterIds,
    staticUrls: staticUrls,
    full: false,
  );

  GameResourceManifest buildFull({
    required Map<String, Object?> start2,
    required List<String> staticUrls,
  }) => _build(
    profile: 'full',
    start2: start2,
    shipIds: null,
    slotItemIds: null,
    staticUrls: staticUrls,
    full: true,
  );

  GameResourceManifest _build({
    required String profile,
    required Map<String, Object?> start2,
    required Set<int>? shipIds,
    required Set<int>? slotItemIds,
    required List<String> staticUrls,
    required bool full,
  }) {
    final paths = <String>{...staticUrls.map(_absolute)};
    final ships = _maps(start2['api_mst_shipgraph'])
        .where(
          (ship) => shipIds == null || shipIds.contains(_int(ship['api_id'])),
        )
        .toList();
    final masterShips = <int, Map<String, Object?>>{
      for (final ship in _maps(start2['api_mst_ship']))
        _int(ship['api_id']): ship,
    };
    for (final graph in ships) {
      _addShip(paths, graph, masterShips[_int(graph['api_id'])], full: full);
    }

    for (final item in _maps(start2['api_mst_slotitem'])) {
      final id = _int(item['api_id']);
      if (slotItemIds != null && !slotItemIds.contains(id)) continue;
      _addSlotItem(paths, item, full: full);
    }

    if (full) {
      _addFurniture(paths, _maps(start2['api_mst_furniture']));
      _addMaps(paths, _maps(start2['api_mst_mapinfo']));
      _addSounds(paths, start2);
    }

    final urls = paths.toList()..sort();
    return GameResourceManifest(
      profile: profile,
      urls: urls,
      targetBytes: urls.fold<int>(0, (sum, url) => sum + _estimatedBytes(url)),
    );
  }

  void _addShip(
    Set<String> paths,
    Map<String, Object?> graph,
    Map<String, Object?>? master, {
    required bool full,
  }) {
    final id = _int(graph['api_id']);
    final fileName = _string(graph['api_filename']);
    if (id <= 0 || fileName.isEmpty) return;
    final versions = _list(graph['api_version']);
    final imageVersion = _version(versions.isEmpty ? null : versions.first);
    final types = full
        ? const <String>[
            'card',
            'card_dmg',
            'banner',
            'banner_dmg',
            'banner_g_dmg',
            'banner2',
            'banner2_dmg',
            'character_full',
            'character_full_dmg',
            'character_up',
            'character_up_dmg',
            'remodel',
            'remodel_dmg',
            'supply_character',
            'supply_character_dmg',
            'album_status',
          ]
        : const <String>['card', 'banner', 'character_full', 'character_up'];
    for (final type in types) {
      paths.add(
        _absolute('${_keyedPath(id, 'ship', type, 'png')}$imageVersion'),
      );
    }
    for (final type
        in full ? const <String>['full', 'full_dmg'] : const <String>['full']) {
      paths.add(
        _absolute(
          '${_keyedPath(id, 'ship', type, 'png', fileName: fileName)}$imageVersion',
        ),
      );
    }
    if (master != null && (full || master.isNotEmpty)) {
      _addShipVoices(paths, graph, master, full: full);
    }
  }

  void _addSlotItem(
    Set<String> paths,
    Map<String, Object?> item, {
    required bool full,
  }) {
    final id = _int(item['api_id']);
    if (id <= 0) return;
    final version = _version(item['api_version']);
    final types = full
        ? const <String>[
            'card',
            'card_t',
            'item_character',
            'item_on',
            'item_up',
            'remodel',
            'statustop_item',
          ]
        : const <String>['card', 'item_on', 'item_up', 'statustop_item'];
    for (final type in types) {
      if (id == 42 && type == 'item_character') continue;
      paths.add(_absolute('${_keyedPath(id, 'slot', type, 'png')}$version'));
    }
    final apiType = _list(item['api_type']);
    if (apiType.length > 4 && _int(apiType[4]) != 0) {
      for (final type in const <String>[
        'airunit_fairy',
        'airunit_banner',
        'airunit_name',
      ]) {
        paths.add(_absolute('${_keyedPath(id, 'slot', type, 'png')}$version'));
      }
    }
  }

  void _addFurniture(Set<String> paths, List<Map<String, Object?>> furniture) {
    for (final item in furniture) {
      final id = _int(item['api_id']);
      final version = _version(item['api_version']);
      if (_int(item['api_active_flag']) == 1) {
        for (final spec in const <(String, String)>[
          ('scripts', 'json'),
          ('movable', 'json'),
          ('movable', 'png'),
          ('thumbnail', 'png'),
        ]) {
          paths.add(
            _absolute(
              '${_keyedPath(id, 'furniture', spec.$1, spec.$2)}$version',
            ),
          );
        }
      } else {
        paths.add(
          _absolute('${_keyedPath(id, 'furniture', 'normal', 'png')}$version'),
        );
      }
    }
  }

  void _addMaps(Set<String> paths, List<Map<String, Object?>> maps) {
    for (final map in maps) {
      final area = _int(map['api_maparea_id']).toString().padLeft(3, '0');
      final number = _int(map['api_no']).toString().padLeft(2, '0');
      for (final suffix in <String>[
        '.png',
        '_info.json',
        '_image.json',
        '_image.png',
      ]) {
        paths.add(_absolute('/kcs2/resources/map/$area/$number$suffix'));
      }
      if (map.containsKey('api_required_defeat_count') ||
          map.containsKey('api_max_maphp')) {
        paths.add(_absolute('/kcs2/resources/gauge/$area$number.json'));
      }
    }
  }

  void _addSounds(Set<String> paths, Map<String, Object?> start2) {
    for (var id = 1; id <= 86; id++) {
      paths.add(
        _absolute(
          '/kcs2/resources/voice/titlecall_1/${id.toString().padLeft(3, '0')}.mp3',
        ),
      );
    }
    for (var id = 1; id <= 49; id++) {
      paths.add(
        _absolute(
          '/kcs2/resources/voice/titlecall_2/${id.toString().padLeft(3, '0')}.mp3',
        ),
      );
    }
    const missingSe = <int>{
      119,
      232,
      233,
      234,
      236,
      251,
      259,
      260,
      261,
      262,
      263,
    };
    for (final range in const <(int, int)>[
      (101, 120),
      (201, 264),
      (301, 327),
    ]) {
      for (var id = range.$1; id <= range.$2; id++) {
        if (!missingSe.contains(id))
          paths.add(_absolute('/kcs2/resources/se/$id.mp3'));
      }
    }
    final portBgm = <int>{
      for (var id = 101; id <= 143; id++) id,
      for (var id = 201; id <= 249; id++) id,
      for (final item in _maps(start2['api_mst_bgm'])) _int(item['api_id']),
    }..removeWhere((id) => id <= 0);
    for (final id in portBgm) {
      paths.add(_absolute(_keyedPath(id, 'bgm', 'port', 'mp3')));
    }
  }

  void _addShipVoices(
    Set<String> paths,
    Map<String, Object?> graph,
    Map<String, Object?> master, {
    required bool full,
  }) {
    final id = _int(graph['api_id']);
    final fileName = _string(graph['api_filename']);
    final versions = _list(graph['api_version']);
    final lines = full
        ? <int>[
            1,
            25,
            2,
            3,
            4,
            28,
            24,
            8,
            13,
            9,
            10,
            26,
            27,
            11,
            12,
            5,
            7,
            14,
            15,
            16,
            18,
            17,
            23,
            19,
            20,
            21,
            22,
          ]
        : <int>[1, 2, 3, 4, 8, 9, 10, 11, 12, 13];
    final voiceFlags = _int(master['api_voicef']);
    if (full && (voiceFlags & 1) != 0) lines.add(29);
    if (full && (voiceFlags & 2) != 0)
      lines.addAll(<int>[for (var line = 30; line <= 53; line++) line]);
    if (full && (voiceFlags & 4) != 0) lines.add(129);
    for (final line in lines) {
      final versionIndex = line == 2 || line == 3 ? 2 : 1;
      final version = _version(
        versions.length > versionIndex ? versions[versionIndex] : null,
      );
      paths.add(
        _absolute(
          '/kcs/sound/kc$fileName/${_voiceFileName(id, line)}.mp3$version',
        ),
      );
    }
  }

  String _keyedPath(
    int id,
    String group,
    String type,
    String extension, {
    String? fileName,
  }) {
    final padded = id.toString().padLeft(
      group == 'ship' || group == 'slot' ? 4 : 3,
      '0',
    );
    final key = _resourceKey(id, '${group}_$type');
    final unique = fileName == null ? '' : '_$fileName';
    return '/kcs2/resources/$group/$type/${padded}_$key$unique.$extension';
  }

  int _resourceKey(int id, String type) {
    final characterSum = type.codeUnits.fold<int>(
      0,
      (sum, value) => sum + value,
    );
    final factor =
        _resourceFactors[(characterSum + id * type.length) %
            _resourceFactors.length];
    return 17 * (id + 7) * factor % 8973 + 1000;
  }

  int _voiceFileName(int shipId, int line) => line <= 53
      ? 100000 + 17 * (shipId + 7) * _voiceFactors[line - 1] % 99173
      : line;

  String _absolute(String path) {
    final uri = Uri.tryParse(path);
    if (uri?.hasScheme == true) return path;
    return '${resourceOrigin.replaceFirst(RegExp(r'/$'), '')}/${path.replaceFirst(RegExp(r'^/'), '')}';
  }

  static String _version(Object? value) {
    final text = _string(value);
    return text.isEmpty || text == '1'
        ? ''
        : '?version=${Uri.encodeQueryComponent(text)}';
  }

  static int _estimatedBytes(String url) {
    final path = url.toLowerCase().split('?').first;
    if (path.endsWith('.mp3') || path.endsWith('.ogg')) return 220000;
    if (path.endsWith('.png') || path.endsWith('.jpg')) return 420000;
    if (path.endsWith('.js')) return 350000;
    if (path.endsWith('.json')) return 80000;
    return 120000;
  }

  static List<Map<String, Object?>> _maps(Object? value) => _list(
    value,
  ).whereType<Map>().map((item) => Map<String, Object?>.from(item)).toList();
  static List<Object?> _list(Object? value) =>
      value is List ? List<Object?>.from(value) : const <Object?>[];
  static int _int(Object? value) => switch (value) {
    num number => number.toInt(),
    String text => int.tryParse(text) ?? 0,
    _ => 0,
  };
  static String _string(Object? value) => value?.toString() ?? '';

  static const _voiceFactors = <int>[
    2475,
    6547,
    1471,
    8691,
    7847,
    3595,
    1767,
    3311,
    2507,
    9651,
    5321,
    4473,
    7117,
    5947,
    9489,
    2669,
    8741,
    6149,
    1301,
    7297,
    2975,
    6413,
    8391,
    9705,
    2243,
    2091,
    4231,
    3107,
    9499,
    4205,
    6013,
    3393,
    6401,
    6985,
    3683,
    9447,
    3287,
    5181,
    7587,
    9353,
    2135,
    4947,
    5405,
    5223,
    9457,
    5767,
    9265,
    8191,
    3927,
    3061,
    2805,
    3273,
    7331,
  ];
  static const _resourceFactors = <int>[
    6657,
    5699,
    3371,
    8909,
    7719,
    6229,
    5449,
    8561,
    2987,
    5501,
    3127,
    9319,
    4365,
    9811,
    9927,
    2423,
    3439,
    1865,
    5925,
    4409,
    5509,
    1517,
    9695,
    9255,
    5325,
    3691,
    5519,
    6949,
    5607,
    9539,
    4133,
    7795,
    5465,
    2659,
    6381,
    6875,
    4019,
    9195,
    5645,
    2887,
    1213,
    1815,
    8671,
    3015,
    3147,
    2991,
    7977,
    7045,
    1619,
    7909,
    4451,
    6573,
    4545,
    8251,
    5983,
    2849,
    7249,
    7449,
    9477,
    5963,
    2711,
    9019,
    7375,
    2201,
    5631,
    4893,
    7653,
    3719,
    8819,
    5839,
    1853,
    9843,
    9119,
    7023,
    5681,
    2345,
    9873,
    6349,
    9315,
    3795,
    9737,
    4633,
    4173,
    7549,
    7171,
    6147,
    4723,
    5039,
    2723,
    7815,
    6201,
    5999,
    5339,
    4431,
    2911,
    4435,
    3611,
    4423,
    9517,
    3243,
  ];
}

final class GameResourceStaticCatalog {
  const GameResourceStaticCatalog._();

  static Future<List<String>> load({AssetBundle? bundle}) async {
    final decoded = jsonDecode(
      await (bundle ?? rootBundle).loadString(
        'assets/data/game_resource_static_catalog.json',
      ),
    );
    if (decoded is! List) return const <String>[];
    return decoded.whereType<String>().toList(growable: false);
  }
}
