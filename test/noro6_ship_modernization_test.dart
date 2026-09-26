import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_reducer.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_serializer.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/deck_builder_exporter.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/external_fleet_tool_launcher.dart';
import 'fixtures/kcsapi_fixtures.dart';

void main() {
  const improvement = [20, 0, 30, 15, 12, 2, 6];
  GameState capture() => GameStateReducer().reduce(
    const GameState(
      fleets: [
        Fleet(id: 1, name: 'fleet', shipIds: [7]),
      ],
    ),
    kcsapiEvent('/kcsapi/api_get_member/ship3', {
      'api_ship_data': [
        {
          'api_id': 7,
          'api_ship_id': 187,
          'api_lv': 133,
          'api_nowhp': 40,
          'api_maxhp': 96,
          'api_lucky': [30, 99],
          'api_kyouka': improvement,
          'api_exp': [1000000, 1000, 0],
        },
      ],
    }),
  );
  Map payload(GameState state, ExternalFleetTool tool) {
    final uri = externalFleetToolUri(
      tool,
      const DeckBuilderExporter().exportJson(state),
      state: state,
    );
    return jsonDecode(
          Uri.decodeComponent(uri.fragment.substring('import:'.length)),
        )
        as Map;
  }

  for (final tool in [ExternalFleetTool.noro6, ExternalFleetTool.noro6Mirror]) {
    test(
      '$tool retains modernization from capture through cache and ship updates',
      () {
        var state = capture();
        for (var phase = 0; phase < 3; phase++) {
          final data = payload(state, tool);
          final ship = (data['ships'] as List).single as Map;
          expect(
            ship['st'],
            improvement,
            reason:
                'Noro6 stock uses seven ordered modernization increments, phase $phase',
          );
          expect(data['predeck']['f1']['s1']['luck'], 30);
          expect(
            data['predeck']['f1']['s1']['hp'],
            96,
            reason:
                'Export maximum HP, including marriage and modernization, not current damaged HP',
          );
          state = phase == 0
              ? GameStateReducer().reduce(
                  state,
                  kcsapiEvent('/kcsapi/api_req_hokyu/charge', {
                    'api_ship': [
                      {'api_id': 7, 'api_fuel': 100, 'api_bull': 100},
                    ],
                  }),
                )
              : GameStateSerializer.deserialize(
                  GameStateSerializer.serialize(state),
                );
        }
      },
    );
  }
  test('modernization response immediately updates the next export', () {
    final state = GameStateReducer().reduce(
      capture(),
      kcsapiEvent(
        '/kcsapi/api_req_kaisou/powerup',
        {
          'api_powerup_flag': 1,
          'api_ship': {
            'api_id': 7,
            'api_ship_id': 187,
            'api_lv': 133,
            'api_nowhp': 40,
            'api_maxhp': 97,
            'api_lucky': [32, 99],
            'api_kyouka': [20, 0, 30, 15, 14, 3, 6],
          },
        },
        requestParams: {'api_id': 7, 'api_id_items': '8'},
      ),
    );
    final data = payload(state, ExternalFleetTool.noro6);
    expect((data['ships'] as List).single['st'], [20, 0, 30, 15, 14, 3, 6]);
    expect(data['predeck']['f1']['s1']['luck'], 32);
    expect(data['predeck']['f1']['s1']['hp'], 97);
  });
  test('legacy cache exports without inventing modernization or zero HP', () {
    final state = GameStateSerializer.deserialize(
      '{"ships":{"7":{"id":7,"masterId":187,"level":99}}}',
    );
    final data = payload(state, ExternalFleetTool.noro6);
    expect((data['ships'] as List).single['st'], isNull);
  });
}
