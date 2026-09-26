import 'package:flutter/material.dart';

import '../game_state/game_state.dart';
import 'fleet_ui_strings.dart';

/// The immediate remodel only: reversible remodels may form cycles.
class ShipRemodelCapsule extends StatelessWidget {
  const ShipRemodelCapsule({
    super.key,
    required this.state,
    required this.ship,
  });

  final GameState state;
  final OwnedShip ship;

  @override
  Widget build(BuildContext context) {
    final master = state.masterForShip(ship);
    final target = state.masterShips[master?.afterShipId];
    final String value;
    if (master == null) {
      value = fleetText(context, FleetUiKeys.dataIncomplete);
    } else if (master.afterShipId == 0 && master.afterLv == 0) {
      value = fleetText(context, FleetUiKeys.noFurtherRemodel);
    } else if (master.afterShipId <= 0 ||
        master.afterShipId == master.id ||
        master.afterLv <= 0 ||
        target == null ||
        target.name.trim().isEmpty) {
      value = fleetText(context, FleetUiKeys.dataIncomplete);
    } else {
      value = '${target.name} · Lv.${master.afterLv}';
    }

    return Container(
      key: const Key('fleet-remodel-capsule'),
      constraints: const BoxConstraints(minHeight: 38),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xff102331),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '${fleetText(context, FleetUiKeys.remodel)}：',
              style: const TextStyle(color: Color(0xffa9bac4)),
            ),
            TextSpan(text: value),
          ],
        ),
        style: const TextStyle(
          color: Color(0xffe1e9ed),
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
