import 'package:flutter/material.dart';

import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';

import '../game_state/fleet_metrics.dart';

Future<void> showFleetLineOfSightDetails(
  BuildContext context,
  FleetMetrics metrics,
) {
  final l10n = AppLocalizations.of(context);
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: const Color(0xff142735),
      title: Text(
        l10n?.losDetails ?? '索敌详情',
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Formula33DetailRow(
            label: l10n?.totalLos ?? '总索敌',
            value: '${metrics.lineOfSight}',
          ),
          const Divider(color: Color(0xff294052)),
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(
                l10n?.formula33 ?? '33式',
                style: const TextStyle(
                  color: Color(0xffdce6eb),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          for (final result in metrics.formula33)
            _Formula33DetailRow(
              label: '× ${result.mapModifier.toInt()}',
              value: result.total.toStringAsFixed(2),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n?.close ?? '关闭'),
        ),
      ],
    ),
  );
}

class _Formula33DetailRow extends StatelessWidget {
  const _Formula33DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Color(0xff9fb4bf)),
            ),
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
}
