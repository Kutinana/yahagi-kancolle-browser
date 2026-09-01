import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../fleet/equipment_type_icon.dart';
import '../game_state/game_state.dart';
import 'development_equipment_picker.dart';
import 'development_pool_matcher.dart';
import 'development_projection.dart';
import 'development_recipe_table.dart';
import 'development_repository.dart';
import 'development_resources.dart';
import 'equipment_development_controller.dart';

class EquipmentDevelopmentPage extends StatefulWidget {
  const EquipmentDevelopmentPage({
    super.key,
    required this.state,
    this.repository,
  });

  final GameState state;
  final DevelopmentRepository? repository;

  @override
  State<EquipmentDevelopmentPage> createState() =>
      _EquipmentDevelopmentPageState();
}

class _EquipmentDevelopmentPageState extends State<EquipmentDevelopmentPage> {
  late final EquipmentDevelopmentController controller;

  @override
  void initState() {
    super.initState();
    controller = EquipmentDevelopmentController(
      repository: widget.repository ?? DevelopmentRepository(),
    )..addListener(_refresh);
    controller.initialize(widget.state);
  }

  @override
  void didUpdateWidget(covariant EquipmentDevelopmentPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.state, widget.state)) {
      controller.updateGameState(widget.state);
    }
  }

  @override
  void dispose() {
    controller
      ..removeListener(_refresh)
      ..dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (controller.isLoading && controller.dataset == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (controller.error != null && controller.dataset == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 42),
            const SizedBox(height: 8),
            Text(l10n.developmentDataError),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: controller.retry,
              icon: const Icon(Icons.refresh),
              label: Text(l10n.developmentRetry),
            ),
          ],
        ),
      );
    }
    final locale = Localizations.localeOf(context);
    return ColoredBox(
      color: const Color(0xff071820),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _CommandCard(controller: controller, locale: locale),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final outcomes = _OutcomePanel(controller: controller);
                final recommendations = _RecommendationsPanel(
                  controller: controller,
                  locale: locale,
                );
                if (constraints.maxWidth >= 760) {
                  return Row(
                    key: const Key('development-wide-layout'),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 6, child: outcomes),
                      const SizedBox(width: 12),
                      Expanded(flex: 5, child: recommendations),
                    ],
                  );
                }
                return Column(
                  key: const Key('development-narrow-layout'),
                  children: [
                    outcomes,
                    const SizedBox(height: 12),
                    recommendations,
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _CommandCard extends StatelessWidget {
  const _CommandCard({required this.controller, required this.locale});
  final EquipmentDevelopmentController controller;
  final Locale locale;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final pools = controller.dataset?.selectablePools.toList() ?? const [];
    return Container(
      key: const Key('development-command-card'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xff173747), Color(0xff0d2734)],
        ),
        border: Border.all(color: const Color(0xff49697a)),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 12,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.precision_manufacturing,
                color: Color(0xffffc85a),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.developmentCommandTitle,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              OutlinedButton.icon(
                key: const Key('development-open-target-picker'),
                onPressed: () =>
                    showDevelopmentEquipmentPicker(context, controller),
                icon: const Icon(Icons.add_circle_outline, size: 18),
                label: Text(
                  controller.targets.isEmpty
                      ? l10n.developmentTargetEquipment
                      : l10n.developmentSelectedCount(
                          controller.targets.length,
                        ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 260,
                child: DropdownButtonFormField<String>(
                  key: const Key('development-pool-selector'),
                  initialValue: controller.selectedPoolKey,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: l10n.developmentSelectPool,
                    isDense: true,
                    filled: true,
                    fillColor: const Color(0xff0a202b),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(9),
                    ),
                  ),
                  items: [
                    for (final pool in pools)
                      DropdownMenuItem(
                        value: pool.key,
                        child: Text(
                          pool.label(locale),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (key) {
                    if (key != null) controller.selectPool(key);
                  },
                ),
              ),
              ActionChip(
                avatar: const Icon(Icons.flag_outlined, size: 17),
                label: Text(
                  '${l10n.developmentCurrentFlagship}: ${controller.currentFlagshipName ?? l10n.noValue}',
                ),
                onPressed: controller.useCurrentFlagship,
                side: BorderSide(
                  color: controller.followsCurrentFlagship
                      ? const Color(0xffd5a44b)
                      : const Color(0xff49697a),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ResourceInput(
                label: l10n.fuel,
                value: controller.resources.fuel,
                onCommit: (v) => _commitResource(controller, 0, v),
              ),
              _ResourceInput(
                label: l10n.ammo,
                value: controller.resources.ammo,
                onCommit: (v) => _commitResource(controller, 1, v),
              ),
              _ResourceInput(
                label: l10n.steel,
                value: controller.resources.steel,
                onCommit: (v) => _commitResource(controller, 2, v),
              ),
              _ResourceInput(
                label: l10n.bauxite,
                value: controller.resources.bauxite,
                onCommit: (v) => _commitResource(controller, 3, v),
              ),
              Chip(
                avatar: const Icon(Icons.hub_outlined, size: 17),
                label: Text(
                  _poolTypeLabel(
                    l10n,
                    selectDevelopmentPoolType(controller.resources),
                  ),
                ),
                backgroundColor: const Color(0xff3a301e),
              ),
            ],
          ),
          if (controller.targets.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final id in controller.targets)
                  InputChip(
                    label: Text(
                      controller.equipmentName(
                        controller.dataset!.equipment[id]!,
                      ),
                    ),
                    onDeleted: () => controller.toggleTarget(id),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ResourceInput extends StatelessWidget {
  const _ResourceInput({
    required this.label,
    required this.value,
    required this.onCommit,
  });
  final String label;
  final int value;
  final ValueChanged<int> onCommit;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 92,
    child: TextFormField(
      key: ValueKey('$label-$value'),
      initialValue: '$value',
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.done,
      onFieldSubmitted: (text) {
        final parsed = int.tryParse(text);
        if (parsed != null) onCommit(parsed);
      },
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        filled: true,
        fillColor: const Color(0xff0a202b),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(9)),
      ),
    ),
  );
}

void _commitResource(
  EquipmentDevelopmentController controller,
  int index,
  int value,
) {
  final values = controller.resources.values..[index] = value;
  controller.commitResources(
    DevelopmentResources(values[0], values[1], values[2], values[3]),
  );
}

class _OutcomePanel extends StatelessWidget {
  const _OutcomePanel({required this.controller});
  final EquipmentDevelopmentController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final groups = controller.equipmentGroups;
    return _Panel(
      title: l10n.developmentCurrentRecipe,
      icon: Icons.inventory_2_outlined,
      child: groups == null
          ? const SizedBox.shrink()
          : Column(
              children: [
                _EquipmentGroup(
                  title: l10n.developmentTargetDrops,
                  items: groups.targets,
                  controller: controller,
                  accent: const Color(0xffffc85a),
                ),
                _EquipmentGroup(
                  title: l10n.developmentOtherDrops,
                  items: groups.other,
                  controller: controller,
                  accent: const Color(0xff75b9d8),
                ),
                _EquipmentGroup(
                  title: l10n.developmentInsufficient,
                  items: groups.insufficient,
                  controller: controller,
                  accent: const Color(0xffd59667),
                ),
                _EquipmentGroup(
                  title: l10n.developmentReplaced,
                  items: groups.replaced,
                  controller: controller,
                  accent: const Color(0xff9c849f),
                ),
              ],
            ),
    );
  }
}

class _EquipmentGroup extends StatelessWidget {
  const _EquipmentGroup({
    required this.title,
    required this.items,
    required this.controller,
    required this.accent,
  });
  final String title;
  final List<DevelopmentEquipmentProjection> items;
  final EquipmentDevelopmentController controller;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '$title  ${items.length}',
            style: TextStyle(
              color: accent,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final item in items)
                Container(
                  constraints: const BoxConstraints(
                    minWidth: 150,
                    maxWidth: 230,
                  ),
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: const Color(0xff102a38),
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: accent.withValues(alpha: 0.48)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      EquipmentTypeIconImage(
                        iconId: item.equipment.iconId,
                        width: 28,
                        height: 28,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          controller.equipmentName(item.equipment),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${_rate(item.totalRate)}%',
                        style: TextStyle(
                          color: accent,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RecommendationsPanel extends StatelessWidget {
  const _RecommendationsPanel({required this.controller, required this.locale});
  final EquipmentDevelopmentController controller;
  final Locale locale;

  @override
  Widget build(BuildContext context) => _Panel(
    title: AppLocalizations.of(context)!.developmentRecommendations,
    icon: Icons.auto_awesome_outlined,
    child: DevelopmentRecipeTable(controller: controller, locale: locale),
  );
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.icon, required this.child});
  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xff0a202b),
      border: Border.all(color: const Color(0xff294b5d)),
      borderRadius: BorderRadius.circular(13),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: const Color(0xff8bb7ca)),
            const SizedBox(width: 7),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                color: Color(0xffd9e7ee),
              ),
            ),
          ],
        ),
        const Divider(height: 18, color: Color(0xff294b5d)),
        child,
      ],
    ),
  );
}

String _poolTypeLabel(AppLocalizations l10n, DevelopmentPoolType type) =>
    switch (type) {
      DevelopmentPoolType.bauxite => l10n.developmentPoolBauxite,
      DevelopmentPoolType.ammunition => l10n.developmentPoolAmmunition,
      DevelopmentPoolType.fuelSteel => l10n.developmentPoolFuelSteel,
    };

String _rate(double value) => value == value.roundToDouble()
    ? '${value.round()}'
    : value.toStringAsFixed(1);
