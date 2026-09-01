import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/external_fleet_tool_launcher.dart';

void main() {
  const json = '{"version":4,"name":"长门 & 陆奥"}';

  group('externalFleetToolUri', () {
    test('builds a noro6 import fragment with stock and predeck data', () {
      const state = GameState(
        ships: <int, OwnedShip>{
          10: OwnedShip(id: 10, masterId: 187, level: 70),
        },
        slotItems: <int, OwnedSlotItem>{
          20: OwnedSlotItem(instanceId: 20, masterSlotItemId: 86, level: 4),
        },
      );
      final officialUri = externalFleetToolUri(
        ExternalFleetTool.noro6,
        json,
        state: state,
      );
      final mirrorUri = externalFleetToolUri(
        ExternalFleetTool.noro6Mirror,
        json,
        state: state,
      );

      expect(officialUri.scheme, 'https');
      expect(officialUri.host, 'noro6.github.io');
      expect(officialUri.path, '/kc-web/');
      expect(officialUri.queryParameters, isEmpty);
      expect(officialUri.fragment, startsWith('import:'));
      expect(mirrorUri.scheme, 'https');
      expect(mirrorUri.host, 'noro6.kcwiki.cn');
      expect(mirrorUri.path, '/');
      expect(mirrorUri.queryParameters, isEmpty);
      expect(mirrorUri.fragment, startsWith('import:'));
      expect(mirrorUri.fragment, officialUri.fragment);
      final payload =
          jsonDecode(
                Uri.decodeComponent(
                  mirrorUri.fragment.substring('import:'.length),
                ),
              )
              as Map;
      expect(payload['predeck'], jsonDecode(json));
      expect(payload['ships'], hasLength(1));
      expect(payload['items'], hasLength(1));
    });

    test(
      'builds a Jervis-compatible URI with a lossless predeck parameter',
      () {
        final uri = externalFleetToolUri(
          ExternalFleetTool.jervis,
          json,
          state: const GameState(),
        );

        expect(uri.scheme, 'https');
        expect(uri.host, 'fleethub.madonoharu.workers.dev');
        expect(uri.path, '/');
        expect(uri.queryParameters['predeck'], json);
      },
    );
  });

  test('launcher forwards the generated URI and result', () async {
    Uri? received;
    final launcher = ExternalFleetToolLauncher(
      launch: (uri) async {
        received = uri;
        return false;
      },
    );

    final launched = await launcher.open(
      ExternalFleetTool.noro6,
      json,
      state: const GameState(),
    );

    expect(launched, isFalse);
    expect(received.toString(), contains('#import:'));
  });
}
