import 'package:flutter/material.dart';

import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';

import '../game_state/fleet_metrics.dart';

AppLocalizations _airPowerL10n(BuildContext context) =>
    AppLocalizations.of(context) ?? lookupAppLocalizations(const Locale('zh'));

Future<void> showFleetAirPowerDetails(
  BuildContext context,
  FleetMetrics metrics,
) {
  final l10n = _airPowerL10n(context);
  final rows = <(String, int?)>[
    (l10n.minimumValue, metrics.airPower),
    (l10n.maximumValue, metrics.airPowerMaximum),
    (l10n.withoutBonus, metrics.airPowerWithoutProficiency),
  ];
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: const Color(0xff142735),
      title: Text(
        l10n.airPowerDetails,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var index = 0; index < rows.length; index++) ...[
            _AirPowerDetailRow(
              label: rows[index].$1,
              value: rows[index].$2?.toString() ?? '—',
            ),
            if (index != rows.length - 1)
              const Divider(color: Color(0xff294052)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.close),
        ),
      ],
    ),
  );
}

class _AirPowerDetailRow extends StatelessWidget {
  const _AirPowerDetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Expanded(
          child: Text(label, style: const TextStyle(color: Color(0xff9fb4bf))),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xffe1e9ed),
            fontWeight: FontWeight.w800,
            fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
          ),
        ),
      ],
    ),
  );
}
