import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../game_state/game_state.dart';
import 'development_dataset.dart';
import 'development_pool_matcher.dart';
import 'development_projection.dart';
import 'development_recipe_calculator.dart';
import 'development_repository.dart';
import 'development_resources.dart';

enum DevelopmentRecipeSortField { targetRate, totalResources, failureRate }

class EquipmentDevelopmentController extends ChangeNotifier {
  EquipmentDevelopmentController({required this.repository});

  final DevelopmentRepository repository;

  DevelopmentDataset? _dataset;
  GameState _gameState = GameState.empty;
  bool _loading = false;
  Object? _error;
  bool _manualPoolSelection = false;
  String? _selectedPoolKey;
  DevelopmentResources _resources = const DevelopmentResources(10, 10, 10, 10);
  final Set<int> _targets = <int>{};
  int? _equipmentTypeFilter;
  String _equipmentSearch = '';
  DevelopmentRatesResult? _currentRates;
  DevelopmentEquipmentGroups? _equipmentGroups;
  Set<int> _enabledEquipment = const <int>{};
  List<DevelopmentRecipeResult> _recipes = const [];
  DevelopmentRecipeSortField _recipeSort =
      DevelopmentRecipeSortField.targetRate;
  bool _sortAscending = false;
  String? _lastAppliedRecipeKey;

  DevelopmentDataset? get dataset => _dataset;
  bool get isLoading => _loading;
  Object? get error => _error;
  String? get selectedPoolKey => _selectedPoolKey;
  DevelopmentResources get resources => _resources;
  Set<int> get targets => UnmodifiableSetView(_targets);
  int? get equipmentTypeFilter => _equipmentTypeFilter;
  String get equipmentSearch => _equipmentSearch;
  DevelopmentRatesResult? get currentRates => _currentRates;
  DevelopmentEquipmentGroups? get equipmentGroups => _equipmentGroups;
  Set<int> get enabledEquipment => _enabledEquipment;
  List<DevelopmentRecipeResult> get recipes => _recipes;
  DevelopmentRecipeSortField get recipeSort => _recipeSort;
  bool get sortAscending => _sortAscending;
  bool get followsCurrentFlagship => !_manualPoolSelection;

  DevelopmentPoolRecord? get selectedPool {
    final key = _selectedPoolKey;
    return key == null ? null : _dataset?.poolsByKey[key];
  }

  int? get currentFlagshipMasterId {
    Fleet? firstFleet;
    for (final fleet in _gameState.fleets) {
      if (fleet.id == 1) {
        firstFleet = fleet;
        break;
      }
    }
    if (firstFleet == null || firstFleet.shipIds.isEmpty) return null;
    final ownedId = firstFleet.shipIds.firstWhere(
      (id) => id > 0,
      orElse: () => -1,
    );
    return _gameState.ships[ownedId]?.masterId;
  }

  String? get currentFlagshipName {
    final id = currentFlagshipMasterId;
    return id == null ? null : _gameState.masterShips[id]?.name;
  }

  List<DevelopmentEquipmentRecord> get filteredEquipment {
    final data = _dataset;
    if (data == null) return const [];
    final query = _equipmentSearch.trim().toLowerCase();
    final output = data.equipment.values.where((item) {
      if (!_enabledEquipment.contains(item.id) && !_targets.contains(item.id)) {
        return false;
      }
      if (_equipmentTypeFilter != null && item.typeId != _equipmentTypeFilter) {
        return false;
      }
      if (query.isEmpty) return true;
      return equipmentName(item).toLowerCase().contains(query) ||
          item.id.toString() == query;
    }).toList();
    output.sort((left, right) {
      final byType = left.typeId.compareTo(right.typeId);
      if (byType != 0) return byType;
      final byName = equipmentName(left).compareTo(equipmentName(right));
      return byName != 0 ? byName : left.id.compareTo(right.id);
    });
    return output;
  }

  String equipmentName(DevelopmentEquipmentRecord item) =>
      _gameState.masterSlotItems[item.id]?.name ?? item.name;

  Future<void> initialize(GameState state) async {
    _gameState = state;
    await _load();
  }

  Future<void> retry() => _load();

  Future<void> _load() async {
    if (_loading) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _dataset = await repository.load();
      _selectAutomaticPool();
      _recompute();
    } on Object catch (error) {
      _error = error;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void updateGameState(GameState state) {
    _gameState = state;
    if (!_manualPoolSelection) _selectAutomaticPool();
    _recompute();
    notifyListeners();
  }

  void selectPool(String key) {
    final pool = _dataset?.poolsByKey[key];
    if (pool == null || !pool.isSelectable || key == _selectedPoolKey) return;
    _selectedPoolKey = key;
    _manualPoolSelection = true;
    _lastAppliedRecipeKey = null;
    _recompute();
    notifyListeners();
  }

  void useCurrentFlagship() {
    _manualPoolSelection = false;
    _selectAutomaticPool();
    _lastAppliedRecipeKey = null;
    _recompute();
    notifyListeners();
  }

  void commitResources(DevelopmentResources value) {
    if (value.values.any((amount) => amount < 10 || amount > 300) ||
        value == _resources) {
      return;
    }
    _resources = value;
    _recompute();
    notifyListeners();
  }

  void toggleTarget(int equipmentId) {
    if (_targets.remove(equipmentId)) {
      _lastAppliedRecipeKey = null;
      _recompute();
      notifyListeners();
      return;
    }
    if (!_enabledEquipment.contains(equipmentId)) return;
    _targets.add(equipmentId);
    _lastAppliedRecipeKey = null;
    _recompute();
    notifyListeners();
  }

  void applyRecipe(DevelopmentRecipeResult recipe) {
    final applicationKey =
        '${recipe.poolKey}:${recipe.resources.values.join(',')}';
    if (_lastAppliedRecipeKey == applicationKey) return;
    _lastAppliedRecipeKey = applicationKey;
    _resources = recipe.resources;
    _selectedPoolKey = recipe.poolKey;
    _manualPoolSelection = true;
    _recompute();
    notifyListeners();
  }

  void setEquipmentTypeFilter(int? typeId) {
    if (_equipmentTypeFilter == typeId) return;
    _equipmentTypeFilter = typeId;
    notifyListeners();
  }

  void setEquipmentSearch(String value) {
    if (_equipmentSearch == value) return;
    _equipmentSearch = value;
    notifyListeners();
  }

  void sortRecipes(DevelopmentRecipeSortField field) {
    if (_recipeSort == field) {
      _sortAscending = !_sortAscending;
    } else {
      _recipeSort = field;
      _sortAscending = field != DevelopmentRecipeSortField.targetRate;
    }
    _sortRecipeOutput();
    notifyListeners();
  }

  void _selectAutomaticPool() {
    final data = _dataset;
    if (data == null) return;
    final flagshipId = currentFlagshipMasterId;
    final matched = flagshipId == null
        ? null
        : data.secretaries[flagshipId]?.poolKey;
    _selectedPoolKey =
        matched ??
        (data.selectablePools.isEmpty ? null : data.selectablePools.first.key);
  }

  void _recompute() {
    final data = _dataset;
    final pool = selectedPool;
    if (data == null || pool == null) {
      _currentRates = null;
      _equipmentGroups = null;
      _enabledEquipment = const <int>{};
      _recipes = const [];
      return;
    }
    _currentRates = calculateDevelopmentRates(data, pool, _resources);
    _equipmentGroups = projectDevelopmentEquipment(
      totals: _currentRates!.totals,
      details: _currentRates!.details,
      targets: _targets,
      resources: _resources,
      equipment: data.equipment,
    );
    _enabledEquipment = calculateEnabledDevelopmentEquipment(data, _targets);
    _recipes = calculateDevelopmentRecipes(data, _targets);
    _sortRecipeOutput();
  }

  void _sortRecipeOutput() {
    final sorted = _recipes.toList();
    int compare(DevelopmentRecipeResult left, DevelopmentRecipeResult right) {
      final comparison = switch (_recipeSort) {
        DevelopmentRecipeSortField.targetRate => left.targetRate.compareTo(
          right.targetRate,
        ),
        DevelopmentRecipeSortField.totalResources =>
          left.totalResources.compareTo(right.totalResources),
        DevelopmentRecipeSortField.failureRate => left.failureRate.compareTo(
          right.failureRate,
        ),
      };
      if (comparison != 0) return _sortAscending ? comparison : -comparison;
      return left.poolKey.compareTo(right.poolKey);
    }

    sorted.sort(compare);
    _recipes = List.unmodifiable(sorted);
  }
}
