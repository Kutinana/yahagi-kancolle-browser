import 'dart:convert';

import 'package:url_launcher/url_launcher.dart';

import '../game_state/game_state.dart';

enum ExternalFleetTool { noro6, jervis }

typedef FleetToolLaunchCallback = Future<bool> Function(Uri uri);

Uri externalFleetToolUri(
  ExternalFleetTool tool,
  String deckBuilderJson, {
  required GameState state,
}) {
  if (tool == ExternalFleetTool.noro6) {
    final ships = state.ships.values.toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    final items = state.slotItems.values.toList()
      ..sort((a, b) => a.instanceId.compareTo(b.instanceId));
    final importJson = jsonEncode(<String, Object?>{
      'ships': ships
          .map(
            (ship) => <String, Object?>{
              'id': ship.id,
              'ship_id': ship.masterId,
              'lv': ship.level,
              'exp': <int>[0, ship.nextExperience, 0],
              'ex': ship.extraSlotId > 0 ? 1 : 0,
            },
          )
          .toList(),
      'items': items
          .map(
            (item) => <String, Object?>{
              'id': item.masterSlotItemId,
              'lv': item.level,
            },
          )
          .toList(),
      'predeck': jsonDecode(deckBuilderJson),
    });
    return Uri.parse(
      'https://noro6.github.io/kc-web/#import:${Uri.encodeComponent(importJson)}',
    );
  }

  return Uri.parse(
    'https://fleethub.madonoharu.workers.dev/',
  ).replace(queryParameters: <String, String>{'predeck': deckBuilderJson});
}

class ExternalFleetToolLauncher {
  const ExternalFleetToolLauncher({FleetToolLaunchCallback? launch})
    : _launch = launch ?? _launchInExternalApplication;

  final FleetToolLaunchCallback _launch;

  Future<bool> open(
    ExternalFleetTool tool,
    String deckBuilderJson, {
    required GameState state,
  }) => _launch(externalFleetToolUri(tool, deckBuilderJson, state: state));

  static Future<bool> _launchInExternalApplication(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.externalApplication);
}
