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
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xff0a222d),
        border: Border.all(color: const Color(0xff31596a)),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          key: const Key('development-recipe-table'),
          showCheckboxColumn: false,
          sortColumnIndex: _sortColumn(controller.recipeSort),
          sortAscending: controller.sortAscending,
          headingRowColor: const WidgetStatePropertyAll(Color(0xff0d2935)),
          dataRowMinHeight: 46,
          dataRowMaxHeight: 54,
          columns: [
            DataColumn(label: Text(l10n.developmentSecretary)),
            DataColumn(numeric: true, label: Text(l10n.developmentFuelShort)),
            DataColumn(numeric: true, label: Text(l10n.developmentAmmoShort)),
            DataColumn(numeric: true, label: Text(l10n.developmentSteelShort)),
            DataColumn(
              numeric: true,
              label: Text(l10n.developmentBauxiteShort),
            ),
            DataColumn(
              numeric: true,
              label: Text(l10n.developmentTotalResources),
              onSort: (_, _) => controller.sortRecipes(
                DevelopmentRecipeSortField.totalResources,
              ),
            ),
            DataColumn(label: Text(l10n.developmentPoolType)),
            DataColumn(
              numeric: true,
              label: Text(l10n.developmentOutputRate),
              onSort: (_, _) =>
                  controller.sortRecipes(DevelopmentRecipeSortField.targetRate),
            ),
            DataColumn(
              numeric: true,
              label: Text(l10n.developmentFailureRate),
              onSort: (_, _) => controller.sortRecipes(
                DevelopmentRecipeSortField.failureRate,
              ),
            ),
          ],
          rows: [
            for (var index = 0; index < controller.recipes.length; index++)
              _recipeRow(
                index,
                controller.recipes[index],
                controller.dataset?.poolsByKey[controller
                    .recipes[index]
                    .poolKey],
                l10n,
              ),
          ],
        ),
      ),
    );
  }

  DataRow _recipeRow(
    int index,
    DevelopmentRecipeResult recipe,
    DevelopmentPoolRecord? pool,
    AppLocalizations l10n,
  ) {
    final applied = controller.isRecipeApplied(recipe);
    return DataRow(
      selected: applied,
      color: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const Color(0xff315b73);
        }
        return index.isEven ? const Color(0xff0a222d) : const Color(0xff0c2732);
      }),
      onSelectChanged: (_) => controller.applyRecipe(recipe),
      cells: [
        DataCell(
          Semantics(
            key: Key('development-recipe-row-$index'),
            selected: applied,
            button: true,
            child: Text(
              pool?.label(locale) ?? recipe.poolKey,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
        DataCell(Text('${recipe.resources.fuel}')),
        DataCell(Text('${recipe.resources.ammo}')),
        DataCell(Text('${recipe.resources.steel}')),
        DataCell(Text('${recipe.resources.bauxite}')),
        DataCell(Text('${recipe.totalResources}')),
        DataCell(Text(_poolTypeLabel(l10n, recipe.poolType))),
        DataCell(
          Text(
            '${_rate(recipe.targetRate)}%',
            style: const TextStyle(
              color: Color(0xffffc85a),
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        DataCell(Text('${_rate(recipe.failureRate)}%')),
      ],
    );
  }
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

int _sortColumn(DevelopmentRecipeSortField field) => switch (field) {
  DevelopmentRecipeSortField.targetRate => 7,
  DevelopmentRecipeSortField.totalResources => 5,
  DevelopmentRecipeSortField.failureRate => 8,
};

String _rate(double value) => value == value.roundToDouble()
    ? '${value.round()}'
    : value.toStringAsFixed(1);

String _poolTypeLabel(AppLocalizations l10n, DevelopmentPoolType type) =>
    switch (type) {
      DevelopmentPoolType.bauxite => l10n.developmentPoolBauxite,
      DevelopmentPoolType.ammunition => l10n.developmentPoolAmmunition,
      DevelopmentPoolType.fuelSteel => l10n.developmentPoolFuelSteel,
    };
