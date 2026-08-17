import 'package:flutter_test/flutter_test.dart';

import '../tool/build_game_resource_baseline_manifest.dart';

void main() {
  test('converter validates paths and produces a stable sorted manifest', () {
    final converted = convertBaselineIndex(<String, Object?>{
      '/kcs2/img/b.png': <String, Object?>{
        'version': '?version=2',
        'length': 2,
      },
      '/kcs2/img/a.png': <String, Object?>{
        'version': '?version=1',
        'length': 1,
      },
      '/kcs/sound/a.mp3': <String, Object?>{'length': '3'},
      '/gadget_html5/js/a.js': <String, Object?>{'length': 4},
      '/html/maintenance.png': <String, Object?>{'length': 5},
      '/kcscontents/image/a.png': <String, Object?>{'length': 6},
      '/kcsapi/api_port/port': <String, Object?>{'length': 100},
      '../unsafe.png': <String, Object?>{'length': 100},
      '/kcs2/img/negative.png': <String, Object?>{'length': -1},
    });

    expect(converted.entryCount, 6);
    expect(converted.targetBytes, 21);
    expect(
      converted.entries.map((entry) => entry.path),
      orderedEquals(<String>[
        '/gadget_html5/js/a.js',
        '/html/maintenance.png',
        '/kcs/sound/a.mp3',
        '/kcs2/img/a.png',
        '/kcs2/img/b.png',
        '/kcscontents/image/a.png',
      ]),
    );
    expect(converted.entries[3].version, '?version=1');
  });

  test(
    'converter rejects malformed metadata without aborting valid entries',
    () {
      final converted = convertBaselineIndex(<String, Object?>{
        '/kcs2/img/valid.png': <String, Object?>{
          'version': 'version=7',
          'length': 7,
        },
        '/kcs2/img/not-a-map.png': 'invalid',
        '/kcs2/img/not-a-length.png': <String, Object?>{'length': 'invalid'},
      });

      expect(converted.entryCount, 1);
      expect(converted.entries.single.version, '?version=7');
      expect(converted.targetBytes, 7);
    },
  );
}
