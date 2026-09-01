import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import 'development_dataset.dart';
import 'development_recipe_calculator.dart';
import 'development_resources.dart';
import 'equipment_development_controller.dart';

class DevelopmentRecipeTable extends StatelessWidget {
  const DevelopmentRecipeTable({
    super.key,
    required this.controller,
    required this.locale,
  });

  final EquipmentDevelopmentController controller;
  final Locale locale;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (controller.targets.isEmpty) {
      return _EmptyRecipes(
        icon: Icons.track_changes,
        text: l10n.developmentNoTargets,
      );
    }
    if (controller.recipes.isEmpty) {
      return _EmptyRecipes(
        icon: Icons.route_outlined,
        text: l10n.developmentNoResults,
      );
    }
    return Column(
      children: [
        _RecipeHeader(controller: controller),
        const SizedBox(height: 6),
        for (var index = 0; index < controller.recipes.length; index++)
          Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: _RecipeRow(
              key: Key('development-recipe-row-$index'),
              index: index,
              recipe: controller.recipes[index],
              pool: controller
                  .dataset
                  ?.poolsByKey[controller.recipes[index].poolKey],
              applied: controller.isRecipeApplied(controller.recipes[index]),
              locale: locale,
              onApply: () => controller.applyRecipe(controller.recipes[index]),
            ),
          ),
      ],
    );
  }
}

class _RecipeHeader extends StatelessWidget {
  const _RecipeHeader({required this.controller});
  final EquipmentDevelopmentController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _SortChip(
            label: l10n.developmentTargetRate,
            selected:
                controller.recipeSort == DevelopmentRecipeSortField.targetRate,
            onTap: () =>
                controller.sortRecipes(DevelopmentRecipeSortField.targetRate),
          ),
          _SortChip(
            label: l10n.developmentTotalResources,
            selected:
                controller.recipeSort ==
                DevelopmentRecipeSortField.totalResources,
            onTap: () => controller.sortRecipes(
              DevelopmentRecipeSortField.totalResources,
            ),
          ),
          _SortChip(
            label: l10n.developmentFailureRate,
            selected:
                controller.recipeSort == DevelopmentRecipeSortField.failureRate,
            onTap: () =>
                controller.sortRecipes(DevelopmentRecipeSortField.failureRate),
          ),
        ],
      ),
    );
  }
}

class _SortChip extends StatelessWidget {
  const _SortChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 6),
    child: ActionChip(
      label: Text(label),
      avatar: selected ? const Icon(Icons.swap_vert, size: 16) : null,
      onPressed: onTap,
      side: BorderSide(
        color: selected ? const Color(0xffd8a64a) : const Color(0xff365566),
      ),
      backgroundColor: selected
          ? const Color(0xff3c301d)
          : const Color(0xff102a38),
    ),
  );
}

class _RecipeRow extends StatelessWidget {
  const _RecipeRow({
    super.key,
    required this.index,
    required this.recipe,
    required this.pool,
    required this.locale,
    required this.onApply,
    required this.applied,
  });
  final int index;
  final DevelopmentRecipeResult recipe;
  final DevelopmentPoolRecord? pool;
  final Locale locale;
  final VoidCallback onApply;
  final bool applied;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Semantics(
      selected: applied,
      button: true,
      child: Material(
        color: applied ? const Color(0xff3b301d) : const Color(0xff0d2532),
        shape: RoundedRectangleBorder(
          side: BorderSide(
            color: applied ? const Color(0xffffc85a) : const Color(0xff294b5d),
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: InkWell(
          onTap: onApply,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 9, 6, 9),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pool?.label(locale) ?? recipe.poolKey,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xffd9e7ee),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        _poolTypeLabel(l10n, recipe.poolType),
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xff84a6b6),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 7,
                        runSpacing: 4,
                        children: [
                          _Metric(
                            icon: Icons.local_gas_station,
                            value: '${recipe.resources.fuel}',
                          ),
                          _Metric(
                            icon: Icons.grain,
                            value: '${recipe.resources.ammo}',
                          ),
                          _Metric(
                            icon: Icons.hexagon_outlined,
                            value: '${recipe.resources.steel}',
                          ),
                          _Metric(
                            icon: Icons.landscape_outlined,
                            value: '${recipe.resources.bauxite}',
                          ),
                          _Metric(
                            icon: Icons.track_changes,
                            value: '${_rate(recipe.targetRate)}%',
                            accent: true,
                          ),
                          _Metric(
                            icon: Icons.close,
                            value: '${_rate(recipe.failureRate)}%',
                          ),
                          _Metric(
                            icon: Icons.functions,
                            value: '${recipe.totalResources}',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  key: Key('development-apply-recipe-$index'),
                  tooltip: l10n.developmentApplyRecipe,
                  onPressed: onApply,
                  icon: const Icon(Icons.input, color: Color(0xffffc85a)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.icon, required this.value, this.accent = false});
  final IconData icon;
  final String value;
  final bool accent;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(
        icon,
        size: 13,
        color: accent ? const Color(0xffffc85a) : const Color(0xff7fa3b5),
      ),
      const SizedBox(width: 2),
      Text(
        value,
        style: TextStyle(
          fontSize: 12,
          color: accent ? const Color(0xffffd783) : const Color(0xffb8ccd6),
        ),
      ),
    ],
  );
}

class _EmptyRecipes extends StatelessWidget {
  const _EmptyRecipes({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
    child: Column(
      children: [
        Icon(icon, size: 30, color: const Color(0xff658696)),
        const SizedBox(height: 8),
        Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xff91a9b5)),
        ),
      ],
    ),
  );
}

String _rate(double value) => value == value.roundToDouble()
    ? '${value.round()}'
    : value.toStringAsFixed(1);

String _poolTypeLabel(AppLocalizations l10n, DevelopmentPoolType type) =>
    switch (type) {
      DevelopmentPoolType.bauxite => l10n.developmentPoolBauxite,
      DevelopmentPoolType.ammunition => l10n.developmentPoolAmmunition,
      DevelopmentPoolType.fuelSteel => l10n.developmentPoolFuelSteel,
    };
