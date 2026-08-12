import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/bridge/captured_api_event.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_reducer.dart';

void main() {
  test('preserves stat maxima and ship/equipment lock state from the API', () {
    final reducer = GameStateReducer();
    final state = reducer.reduce(
      GameState.empty,
      CapturedApiEvent(
        path: '/kcsapi/api_port/port',
        source: CaptureSource.manual,
        requestParams: const <String, String>{},
        responseBody: jsonEncode(const <String, Object?>{
          'api_result': 1,
          'api_data': <String, Object?>{
            'api_ship': <Object?>[
              <String, Object?>{
                'api_id': 1,
                'api_ship_id': 101,
                'api_lv': 98,
                'api_locked': 1,
                'api_karyoku': <int>[55, 59],
                'api_raisou': <int>[88, 88],
                'api_taiku': <int>[70, 77],
                'api_soukou': <int>[49, 49],
                'api_lucky': <int>[17, 59],
              },
            ],
            'api_slot_item': <Object?>[
              <String, Object?>{
                'api_id': 301,
                'api_slotitem_id': 201,
                'api_level': 7,
                'api_alv': 6,
                'api_locked': 1,
              },
            ],
          },
        }),
        capturedAt: DateTime(2026),
        sourceOrigin: 'https://example.invalid',
      ),
    );

    expect(state.ships[1]?.firepowerMax, 59);
    expect(state.ships[1]?.luckMax, 59);
    expect(state.ships[1]?.locked, isTrue);
    expect(state.slotItems[301]?.locked, isTrue);
  });
}
