import 'package:flutter/material.dart';

import '../fleet/equipment_type_icon.dart';
import 'development_projection.dart';
import 'equipment_development_controller.dart';

List<DevelopmentEquipmentProjection> visibleDevelopmentOutput({
  required DevelopmentEquipmentGroups groups,
  required Set<int> targets,
  required bool ascending,
}) {
  final items = <DevelopmentEquipmentProjection>[
    ...groups.targets,
    ...groups.other,
  ];
  items.sort((left, right) {
    final leftTarget = targets.contains(left.id);
    final rightTarget = targets.contains(right.id);
    if (leftTarget != rightTarget) return leftTarget ? -1 : 1;
    final rate = left.totalRate.compareTo(right.totalRate);
    if (rate != 0) return ascending ? rate : -rate;
    return left.id.compareTo(right.id);
  });
  return List.unmodifiable(items);
}

class DevelopmentOutputTable extends StatefulWidget {
  const DevelopmentOutputTable({
    super.key,
    required this.controller,
    required this.title,
    required this.finalProbabilityLabel,
    this.typeLabel = '类型',
    this.targetLabel = '目标',
  });

  final EquipmentDevelopmentController controller;
  final String title;
  final String finalProbabilityLabel;
  final String typeLabel;
  final String targetLabel;

  @override
  State<DevelopmentOutputTable> createState() => _DevelopmentOutputTableState();
}

class _DevelopmentOutputTableState extends State<DevelopmentOutputTable> {
  bool _ascending = false;

  @override
  Widget build(BuildContext context) {
    final groups = widget.controller.equipmentGroups;
    if (groups == null) return const SizedBox.shrink();
    final items = visibleDevelopmentOutput(
      groups: groups,
      targets: widget.controller.targets,
      ascending: _ascending,
    );
    if (items.isEmpty) {
      return const SizedBox(height: 96, child: Center(child: Text('—')));
    }
    return Container(
      key: const Key('development-output-table'),
      decoration: BoxDecoration(
        color: const Color(0xff0a222d),
        border: Border.all(color: const Color(0xff31596a)),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(13, 11, 13, 9),
            child: Text(
              widget.title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
          ),
          const Divider(height: 1, color: Color(0xff31596a)),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: const WidgetStatePropertyAll(Color(0xff0d2935)),
              dataRowMinHeight: 48,
              dataRowMaxHeight: 56,
              columns: [
                const DataColumn(label: Text('装备')),
                DataColumn(label: Text(widget.typeLabel)),
                DataColumn(
                  numeric: true,
                  onSort: (_, _) => setState(() => _ascending = !_ascending),
                  label: Row(
                    key: const Key('development-output-probability-sort'),
                    children: [
                      Text(widget.finalProbabilityLabel),
                      const SizedBox(width: 4),
                      Icon(
                        _ascending ? Icons.arrow_upward : Icons.arrow_downward,
                        size: 14,
                        color: const Color(0xffffc85a),
                      ),
                    ],
                  ),
                ),
              ],
              rows: [
                for (final item in items)
                  DataRow(
                    key: ValueKey('development-output-${item.id}'),
                    cells: [
                      DataCell(
                        Row(
                          children: [
                            EquipmentTypeIconImage(
                              iconId: item.equipment.iconId,
                              width: 27,
                              height: 27,
                            ),
                            const SizedBox(width: 7),
                            Text(
                              widget.controller.equipmentName(item.equipment),
                            ),
                            if (widget.controller.targets.contains(
                              item.id,
                            )) ...[
                              const SizedBox(width: 7),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: const Color(0xffb48732),
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  widget.targetLabel,
                                  style: const TextStyle(
                                    color: Color(0xffffc85a),
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      DataCell(Text('#${item.equipment.typeId}')),
                      DataCell(
                        Text(
                          '${_rate(item.totalRate)}%',
                          key: Key('development-final-rate-${item.id}'),
                          style: const TextStyle(
                            color: Color(0xffffc85a),
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _rate(double value) => value == value.roundToDouble()
    ? '${value.round()}'
    : value.toStringAsFixed(1);
