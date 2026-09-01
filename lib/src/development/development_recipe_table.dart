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
    final Widget content;
    if (controller.targets.isEmpty) {
      content = _EmptyRecipes(
        icon: Icons.track_changes,
        text: l10n.developmentNoTargets,
      );
    } else if (controller.recipes.isEmpty) {
      content = _EmptyRecipes(
        icon: Icons.route_outlined,
        text: l10n.developmentNoResults,
      );
    } else {
      content = LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: DataTable(
              key: const Key('development-recipe-table'),
              showCheckboxColumn: false,
              sortColumnIndex: _sortColumn(controller.recipeSort),
              sortAscending: controller.sortAscending,
              headingRowColor: const WidgetStatePropertyAll(Color(0xff0d2935)),
              headingRowHeight: 34,
              dataRowMinHeight: 44,
              dataRowMaxHeight: 44,
              horizontalMargin: 8,
              columnSpacing: 16,
              headingTextStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
              dataTextStyle: const TextStyle(fontSize: 12),
              columns: [
                DataColumn(label: Text(l10n.developmentSecretary)),
                DataColumn(
                  numeric: true,
                  label: _ResourceHeader(
                    index: 0,
                    asset: 'assets/images/material/01.png',
                    label: l10n.fuel,
                  ),
                ),
                DataColumn(
                  numeric: true,
                  label: _ResourceHeader(
                    index: 1,
                    asset: 'assets/images/material/02.png',
                    label: l10n.ammo,
                  ),
                ),
                DataColumn(
                  numeric: true,
                  label: _ResourceHeader(
                    index: 2,
                    asset: 'assets/images/material/03.png',
                    label: l10n.steel,
                  ),
                ),
                DataColumn(
                  numeric: true,
                  label: _ResourceHeader(
                    index: 3,
                    asset: 'assets/images/material/04.png',
                    label: l10n.bauxite,
                  ),
                ),
                DataColumn(
                  numeric: true,
                  label: Text(l10n.developmentTotalResources),
                  onSort: (_, _) => controller.sortRecipes(
                    DevelopmentRecipeSortField.totalResources,
                  ),
                ),
                DataColumn(
                  numeric: true,
                  label: Text(l10n.developmentOutputRate),
                  onSort: (_, _) => controller.sortRecipes(
                    DevelopmentRecipeSortField.targetRate,
                  ),
                ),
                DataColumn(
                  numeric: true,
                  label: Text(l10n.developmentFailureRate),
                  onSort: (_, _) => controller.sortRecipes(
                    DevelopmentRecipeSortField.failureRate,
                  ),
                ),
                DataColumn(label: Text(l10n.developmentPoolType)),
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
        ),
      );
    }
    return Container(
      key: const Key('development-recipe-table-frame'),
      width: double.infinity,
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
              l10n.developmentAvailableRecipes,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
          ),
          const Divider(height: 1, color: Color(0xff31596a)),
          content,
        ],
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
        DataCell(Text(_poolTypeLabel(l10n, recipe.poolType))),
      ],
    );
  }
}

class _ResourceHeader extends StatelessWidget {
  const _ResourceHeader({
    required this.index,
    required this.asset,
    required this.label,
  });

  final int index;
  final String asset;
  final String label;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: label,
    child: Semantics(
      label: label,
      image: true,
      child: Image.asset(
        asset,
        key: Key('development-recipe-resource-$index'),
        width: 20,
        height: 20,
      ),
    ),
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

int _sortColumn(DevelopmentRecipeSortField field) => switch (field) {
  DevelopmentRecipeSortField.targetRate => 6,
  DevelopmentRecipeSortField.totalResources => 5,
  DevelopmentRecipeSortField.failureRate => 7,
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
