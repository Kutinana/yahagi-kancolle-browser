import 'package:flutter/material.dart';

import '../fleet/ship_portrait.dart';
import '../game_state/game_state.dart';
import 'battle_models.dart';

class OfficialEnemyPreview extends StatelessWidget {
  const OfficialEnemyPreview({
    super.key,
    required this.ships,
    this.combined = false,
    this.showPortraits = false,
    this.masterShips = const <int, MasterShip>{},
    this.serverOrigin = '',
  });

  final List<EnemyPreviewShip> ships;
  final bool combined;
  final bool showPortraits;
  final Map<int, MasterShip> masterShips;
  final String serverOrigin;

  @override
  Widget build(BuildContext context) {
    final escortShips = ships
        .where((ship) => ship.fleetRole == BattleFleetRole.escort)
        .toList();
    final mainShips = ships
        .where((ship) => ship.fleetRole == BattleFleetRole.main)
        .toList();
    return Container(
      key: const Key('official-enemy-preview'),
      decoration: BoxDecoration(
        color: const Color(0xff10212e),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.fromLTRB(9, 7, 9, 5),
            child: Text(
              '敌方部队（战前预测）',
              key: Key('official-enemy-preview-title'),
              style: TextStyle(
                color: Color(0xffff8c78),
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (!combined)
            for (var index = 0; index < ships.length; index++) ...<Widget>[
              if (index > 0) const Divider(height: 1, color: Color(0xff203746)),
              _nameCell(
                ships[index],
                index: index,
                portraitWidth: 52,
                portraitHeight: 24,
                key: Key('official-enemy-preview-row-$index'),
              ),
            ]
          else
            for (var index = 0; index < 3; index++) ...<Widget>[
              if (index > 0) const Divider(height: 1, color: Color(0xff203746)),
              Row(
                key: Key('official-enemy-preview-row-$index'),
                children: <Widget>[
                  Expanded(
                    child: DecoratedBox(
                      decoration: const BoxDecoration(
                        border: Border(
                          right: BorderSide(color: Color(0xff203746)),
                        ),
                      ),
                      child: _nameCell(
                        _shipAt(escortShips, index),
                        index: index,
                        portraitWidth: 52,
                        portraitHeight: 24,
                        key: Key('official-enemy-preview-escort-$index'),
                      ),
                    ),
                  ),
                  Expanded(
                    child: _nameCell(
                      _shipAt(mainShips, index),
                      index: index + 3,
                      portraitWidth: 52,
                      portraitHeight: 24,
                      key: Key('official-enemy-preview-main-$index'),
                    ),
                  ),
                ],
              ),
            ],
        ],
      ),
    );
  }

  EnemyPreviewShip? _shipAt(List<EnemyPreviewShip> fleet, int index) =>
      index < fleet.length ? fleet[index] : null;

  Widget _nameCell(
    EnemyPreviewShip? preview, {
    required int index,
    required double portraitWidth,
    required double portraitHeight,
    required Key key,
  }) {
    final name = preview?.name ?? '';
    final masterShip = preview == null ? null : masterShips[preview.masterId];
    final resourceType = (masterShip?.id ?? 0) >= 1500
        ? ShipPortraitResourceType.banner
        : ShipPortraitResourceType.remodel;
    final portraitUri = masterShip == null
        ? null
        : ShipPortraitUriBuilder.build(
            ship: masterShip,
            serverOrigin: serverOrigin,
            resourceType: resourceType,
          );
    return Padding(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      child: Row(
        children: <Widget>[
          if (showPortraits && portraitUri != null) ...<Widget>[
            ShipPortrait(
              key: Key('official-enemy-preview-portrait-$index'),
              ship: masterShip,
              serverOrigin: serverOrigin,
              width: portraitWidth,
              height: portraitHeight,
              decodeHeight: (portraitHeight * 2).round(),
              resourceType: resourceType,
            ),
            const SizedBox(width: 7),
          ],
          Expanded(
            child: Tooltip(
              message: name,
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
