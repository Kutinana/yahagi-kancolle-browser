import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../game_state/game_state.dart';
import '../../widgets/top_notice.dart';
import 'exp_calc_models.dart';
import 'exp_tracker_store.dart';
import 'ship_exp_table.dart';

abstract final class _ExpCalcPalette {
  static const background = Color(0xff091923);
  static const surface = Color(0xff102732);
  static const surfaceRaised = Color(0xff16333f);
  static const surfaceInset = Color(0xff0c202b);
  static const border = Color(0xff284553);
  static const borderStrong = Color(0xff3a5967);
  static const gold = Color(0xffd7b56d);
  static const goldSoft = Color(0xffffdc88);
  static const goldDark = Color(0xffa98545);
  static const goldSurface = Color(0xff332d22);
  static const data = Color(0xff76c6df);
  static const text = Color(0xffecf3f5);
  static const textMuted = Color(0xff91aab8);
  static const textFaint = Color(0xff6f8a98);
  static const success = Color(0xff63c59b);
  static const danger = Color(0xffe66e68);
  static const target = Color(0xffe5a95f);
}

/// Single planned battle node in a multi-node sortie route.
class _RouteNodeState {
  _RouteNodeState({
    required this.id,
    required this.mapId,
    required this.nodeId,
    required int baseExp,
    this.rank = BattleRank.s,
    this.isFlagship = true,
    this.isMvp = false,
  }) : baseExpController = TextEditingController(text: '$baseExp');

  final String id;
  String mapId;
  String nodeId;
  final TextEditingController baseExpController;
  BattleRank rank;
  bool isFlagship;
  bool isMvp;

  int get baseExp {
    final val = int.tryParse(baseExpController.text.trim());
    return (val != null && val > 0) ? val : 1;
  }

  int computeExp() => computeMapExp(
    baseExp: baseExp,
    rank: rank,
    isFlagship: isFlagship,
    isMvp: isMvp,
  );

  void dispose() {
    baseExpController.dispose();
  }
}

class ExpCalcPage extends StatefulWidget {
  const ExpCalcPage({super.key, required this.state, this.store});

  final GameState state;
  final ExpTrackerStore? store;

  @override
  State<ExpCalcPage> createState() => _ExpCalcPageState();
}

class _ExpCalcPageState extends State<ExpCalcPage> {
  late final ExpTrackerStore _store;

  // Selected ship state
  int? _selectedShipInstanceId;
  String _selectedShipName = '';
  int _currentLevel = 1;
  int _currentExp = 0;
  int _targetLevel = 2;
  int _targetExp = 100;

  // User preference for card vs table view in tracker list
  bool? _preferCardView;

  // Controllers for level inputs
  final TextEditingController _curLevelController = TextEditingController(
    text: '1',
  );
  final TextEditingController _targetLevelController = TextEditingController(
    text: '2',
  );

  // Multi-node route plan
  final List<_RouteNodeState> _routeNodes = <_RouteNodeState>[];

  // Tracker table items
  List<ExpCalcTrackItem> _trackItems = <ExpCalcTrackItem>[];

  @override
  void initState() {
    super.initState();
    _store = widget.store ?? SharedPreferencesExpTrackerStore();

    // Default node 1 (5-2 C point 150 EXP, S rank, Flagship, MVP)
    _routeNodes.add(
      _RouteNodeState(
        id: 'node_init',
        mapId: '5-2',
        nodeId: 'C',
        baseExp: 150,
        rank: BattleRank.s,
        isFlagship: true,
        isMvp: true,
      ),
    );

    _initShipSelection();
    _loadTrackItems();
  }

  @override
  void didUpdateWidget(covariant ExpCalcPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.memberId != widget.state.memberId) {
      _loadTrackItems();
    }
    if (_selectedShipInstanceId != null) {
      final updatedShip = widget.state.ships[_selectedShipInstanceId];
      final oldShip = oldWidget.state.ships[_selectedShipInstanceId];
      if (updatedShip != null &&
          oldShip != null &&
          (updatedShip.experience != oldShip.experience ||
              updatedShip.level != oldShip.level)) {
        setState(() {
          _currentLevel = updatedShip.level;
          _currentExp = updatedShip.experience;
          _curLevelController.text = '$_currentLevel';
          if (_targetLevel <= _currentLevel) {
            _targetLevel = math.min(kShipMaxLevel, _currentLevel + 1);
            _targetExp = shipCumulativeExp(_targetLevel);
            _targetLevelController.text = '$_targetLevel';
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _curLevelController.dispose();
    _targetLevelController.dispose();
    for (final node in _routeNodes) {
      node.dispose();
    }
    super.dispose();
  }

  Future<void> _loadTrackItems() async {
    final items = await _store.loadTrackItems();
    if (!mounted) return;
    setState(() {
      _trackItems = items;
    });
  }

  void _initShipSelection() {
    final sortedShips = _getSortedOwnedShips();
    if (sortedShips.isNotEmpty) {
      final first = sortedShips.first;
      _selectShip(first);
    } else {
      _currentLevel = 1;
      _currentExp = 0;
      _targetLevel = 2;
      _targetExp = shipCumulativeExp(2);
      _curLevelController.text = '1';
      _targetLevelController.text = '2';
    }
  }

  List<OwnedShip> _getSortedOwnedShips() {
    final list = widget.state.ships.values.toList();
    list.sort((a, b) {
      final lvCmp = b.level.compareTo(a.level);
      if (lvCmp != 0) return lvCmp;
      return a.id.compareTo(b.id);
    });
    return list;
  }

  void _selectShip(OwnedShip? ship) {
    if (ship == null) {
      setState(() {
        _selectedShipInstanceId = null;
        _selectedShipName = '';
        _curLevelController.text = '$_currentLevel';
        _targetLevelController.text = '$_targetLevel';
      });
      return;
    }

    final master = widget.state.masterShips[ship.masterId];
    final shipName = master?.name ?? 'Ship #${ship.id}';
    final afterLv = master?.afterLv ?? 0;

    int targetLv;
    if (afterLv > 0 && ship.level < afterLv) {
      targetLv = math.min(afterLv, kShipMaxLevel);
    } else {
      targetLv = math.min(ship.level + 1, kShipMaxLevel);
    }

    setState(() {
      _selectedShipInstanceId = ship.id;
      _selectedShipName = shipName;
      _currentLevel = math.min(ship.level, kShipMaxLevel);
      _currentExp = ship.experience;
      _targetLevel = targetLv;
      _targetExp = shipCumulativeExp(targetLv);
      _curLevelController.text = '$_currentLevel';
      _targetLevelController.text = '$_targetLevel';
    });
  }

  void _stepTargetLevel(int delta) {
    final newLv = math.max(1, math.min(kShipMaxLevel, _targetLevel + delta));
    setState(() {
      _targetLevel = newLv;
      _targetExp = shipCumulativeExp(newLv);
      _targetLevelController.text = '$newLv';
    });
  }

  void _onTargetLevelInput(String text) {
    final val = int.tryParse(text.trim());
    if (val != null) {
      final clamped = math.max(1, math.min(kShipMaxLevel, val));
      setState(() {
        _targetLevel = clamped;
        _targetExp = shipCumulativeExp(clamped);
      });
    }
  }

  void _onCurLevelInput(String text) {
    if (_selectedShipInstanceId != null) return;
    final val = int.tryParse(text.trim());
    if (val != null) {
      final clamped = math.max(1, math.min(kShipMaxLevel, val));
      setState(() {
        _currentLevel = clamped;
        _currentExp = shipCumulativeExp(clamped);
        if (_targetLevel < _currentLevel) {
          _targetLevel = math.min(kShipMaxLevel, _currentLevel + 1);
          _targetExp = shipCumulativeExp(_targetLevel);
          _targetLevelController.text = '$_targetLevel';
        }
      });
    }
  }

  void _addRouteNode() {
    final defaultMap = kPresetMapDatabase.first;
    final defaultNode = defaultMap.nodes.first;
    setState(() {
      _routeNodes.add(
        _RouteNodeState(
          id: 'node_${DateTime.now().microsecondsSinceEpoch}',
          mapId: defaultMap.id,
          nodeId: defaultNode.id,
          baseExp: defaultNode.baseExp,
          rank: BattleRank.s,
          isFlagship: true,
          isMvp: false,
        ),
      );
    });
  }

  void _removeRouteNode(int index) {
    if (_routeNodes.length <= 1) return;
    setState(() {
      final removed = _routeNodes.removeAt(index);
      removed.dispose();
    });
  }

  int get _totalSortieExp =>
      _routeNodes.fold(0, (sum, n) => sum + n.computeExp());

  int get _remainExp => math.max(0, _targetExp - _currentExp);

  int get _sortieCount =>
      computeBattleCount(remainExp: _remainExp, mapExp: _totalSortieExp);

  String get _routeSummary =>
      _routeNodes.map((n) => '${n.mapId}(${n.nodeId})').join(' + ');

  Future<void> _addTrackItem() async {
    final l10n = AppLocalizations.of(context)!;
    final shipName = _selectedShipInstanceId != null
        ? _selectedShipName
        : l10n.expCalcFreeMode;

    final firstNode = _routeNodes.isNotEmpty ? _routeNodes.first : null;
    final item = ExpCalcTrackItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      shipInstanceId: _selectedShipInstanceId ?? -1,
      shipMasterId: -1,
      shipName: shipName,
      targetLevel: _targetLevel,
      targetExp: _targetExp,
      map: firstNode?.mapId ?? '5-2',
      rank: firstNode?.rank ?? BattleRank.s,
      isFlagship: firstNode?.isFlagship ?? true,
      isMvp: firstNode?.isMvp ?? false,
      baseExp: firstNode?.baseExp ?? 150,
      mapExp: firstNode?.computeExp() ?? 540,
      recordedLevel: _currentLevel,
      recordedExp: _currentExp,
      routeSummary: _routeSummary,
      totalSortieExp: _totalSortieExp,
      createdAt: DateTime.now(),
    );

    final updated = <ExpCalcTrackItem>[item, ..._trackItems];
    await _store.saveTrackItems(updated);

    if (!mounted) return;
    setState(() => _trackItems = updated);

    TopNotice.show(context, message: l10n.expCalcTrackAdded);
  }

  Future<void> _deleteTrackItem(String id) async {
    final l10n = AppLocalizations.of(context)!;
    final updated = _trackItems.where((i) => i.id != id).toList();
    await _store.saveTrackItems(updated);

    if (!mounted) return;
    setState(() => _trackItems = updated);

    TopNotice.show(context, message: l10n.expCalcTrackDeleted);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final sortedShips = _getSortedOwnedShips();

    return Scaffold(
      backgroundColor: _ExpCalcPalette.background,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 640;
          final isNarrow = constraints.maxWidth < 420;
          final isWide = constraints.maxWidth >= 760;
          final setupIsCompact = isWide
              ? constraints.maxWidth < 1120
              : isCompact;

          final setupColumn = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildStep1Card(
                l10n,
                sortedShips,
                isCompact: setupIsCompact,
                isNarrow: isNarrow,
              ),
              SizedBox(height: isNarrow ? 10 : 16),
              _buildStep2Card(
                l10n,
                isCompact: setupIsCompact,
                isNarrow: isNarrow,
              ),
            ],
          );

          final resultCard = _buildResultHudCard(
            l10n,
            isCompact: isWide || isCompact,
            isNarrow: isNarrow,
          );

          final workspace = isWide
              ? Row(
                  key: const Key('exp-calc-wide-workspace'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: setupColumn),
                    const SizedBox(width: 16),
                    Expanded(flex: 2, child: resultCard),
                  ],
                )
              : Column(
                  key: const Key('exp-calc-compact-workspace'),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    setupColumn,
                    SizedBox(height: isNarrow ? 10 : 16),
                    resultCard,
                  ],
                );

          return SingleChildScrollView(
            padding: EdgeInsets.all(isNarrow ? 10 : 16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeaderBanner(
                      l10n,
                      isCompact: isCompact,
                      isNarrow: isNarrow,
                    ),
                    SizedBox(height: isNarrow ? 10 : 16),
                    workspace,
                    SizedBox(height: isNarrow ? 10 : 16),
                    _buildTrackingTableCard(
                      l10n,
                      isCompact: isCompact,
                      isNarrow: isNarrow,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeaderBanner(
    AppLocalizations l10n, {
    required bool isCompact,
    required bool isNarrow,
  }) {
    return Container(
      padding: const EdgeInsets.only(bottom: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _ExpCalcPalette.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: isNarrow ? 32 : 38,
            height: isNarrow ? 32 : 38,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_ExpCalcPalette.gold, _ExpCalcPalette.goldDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text(
              '矢',
              style: TextStyle(
                color: _ExpCalcPalette.surfaceInset,
                fontWeight: FontWeight.w900,
                fontSize: isNarrow ? 16 : 18,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 2,
                  children: [
                    Text(
                      l10n.expCalculator,
                      style: TextStyle(
                        color: _ExpCalcPalette.text,
                        fontSize: isNarrow ? 16 : 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.2,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: _ExpCalcPalette.goldSurface,
                        border: Border.all(color: _ExpCalcPalette.goldDark),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'Yahagi Route Planner',
                        style: TextStyle(
                          color: _ExpCalcPalette.goldSoft,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  isNarrow
                      ? '海域预设 · 多点加算 · 动态追踪'
                      : '海域点位字库预设 · 多战斗点路线加算 · 动态追踪表格',
                  style: TextStyle(
                    color: _ExpCalcPalette.textMuted,
                    fontSize: isNarrow ? 10 : 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (!isNarrow)
            const Text(
              'Lv.1 ~ Lv.188',
              style: TextStyle(
                color: _ExpCalcPalette.textFaint,
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStep1Card(
    AppLocalizations l10n,
    List<OwnedShip> sortedShips, {
    required bool isCompact,
    required bool isNarrow,
  }) {
    return Container(
      padding: EdgeInsets.all(isNarrow ? 12 : 16),
      decoration: BoxDecoration(
        color: _ExpCalcPalette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _ExpCalcPalette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: _ExpCalcPalette.gold,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.expCalcStep1Title,
                  style: const TextStyle(
                    color: _ExpCalcPalette.gold,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (!isNarrow) ...[
                const SizedBox(width: 8),
                const Text(
                  'STEP 01',
                  style: TextStyle(
                    color: _ExpCalcPalette.textFaint,
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),

          // Ship picker Dropdown
          Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: _ExpCalcPalette.surfaceRaised,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _ExpCalcPalette.borderStrong),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int?>(
                key: const Key('exp-calc-ship-selector'),
                value: _selectedShipInstanceId,
                dropdownColor: _ExpCalcPalette.surfaceRaised,
                isExpanded: true,
                icon: const Icon(
                  Icons.arrow_drop_down,
                  color: _ExpCalcPalette.textMuted,
                ),
                items: [
                  DropdownMenuItem<int?>(
                    value: null,
                    child: Text(
                      l10n.expCalcFreeMode,
                      style: const TextStyle(
                        color: _ExpCalcPalette.textMuted,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  for (final s in sortedShips)
                    DropdownMenuItem<int?>(
                      value: s.id,
                      child: Text(
                        '[Lv.${s.level}] ${widget.state.masterShips[s.masterId]?.name ?? 'Ship #${s.id}'}',
                        style: const TextStyle(
                          color: _ExpCalcPalette.text,
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (newId) {
                  if (newId == null) {
                    _selectShip(null);
                  } else {
                    _selectShip(widget.state.ships[newId]);
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Level transition card with stepper
          Container(
            padding: EdgeInsets.all(isNarrow ? 10 : 14),
            decoration: BoxDecoration(
              color: _ExpCalcPalette.surfaceInset,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _ExpCalcPalette.border),
            ),
            child: Column(
              children: [
                if (!isCompact)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Current Level
                      Expanded(child: _buildCurrentLevelBox(l10n)),

                      // Arrow
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: _ExpCalcPalette.goldSurface,
                            shape: BoxShape.circle,
                            border: Border.all(color: _ExpCalcPalette.goldDark),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.arrow_forward_rounded,
                            size: 14,
                            color: _ExpCalcPalette.data,
                          ),
                        ),
                      ),

                      // Target Level with Stepper
                      Expanded(child: _buildTargetLevelBox(l10n)),
                    ],
                  )
                else
                  Column(
                    children: [
                      _buildCurrentLevelBox(l10n),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: _ExpCalcPalette.goldSurface,
                            shape: BoxShape.circle,
                            border: Border.all(color: _ExpCalcPalette.goldDark),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.arrow_downward_rounded,
                            size: 14,
                            color: _ExpCalcPalette.data,
                          ),
                        ),
                      ),
                      _buildTargetLevelBox(l10n),
                    ],
                  ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.only(top: 8),
                  decoration: const BoxDecoration(
                    border: Border(
                      top: BorderSide(color: _ExpCalcPalette.border),
                    ),
                  ),
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${l10n.expCalcTargetGapLabel}: ',
                            style: const TextStyle(
                              color: _ExpCalcPalette.textMuted,
                              fontSize: 11,
                            ),
                          ),
                          Text(
                            '$_remainExp EXP',
                            style: const TextStyle(
                              color: _ExpCalcPalette.data,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                      Text(
                        l10n.expCalcTargetAlignHint,
                        style: const TextStyle(
                          color: _ExpCalcPalette.textFaint,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentLevelBox(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _ExpCalcPalette.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _ExpCalcPalette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.expCalcCurrentLevel,
            style: const TextStyle(
              color: _ExpCalcPalette.textMuted,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 4),
          if (_selectedShipInstanceId == null)
            TextField(
              key: const Key('exp-calc-current-level'),
              controller: _curLevelController,
              keyboardType: TextInputType.number,
              style: const TextStyle(
                color: _ExpCalcPalette.text,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                prefixText: 'Lv. ',
                prefixStyle: TextStyle(
                  color: _ExpCalcPalette.data,
                  fontSize: 14,
                ),
              ),
              onChanged: _onCurLevelInput,
            )
          else
            Text(
              key: const Key('exp-calc-current-level'),
              'Lv. $_currentLevel',
              style: const TextStyle(
                color: _ExpCalcPalette.text,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '$_currentExp EXP',
              style: const TextStyle(
                color: _ExpCalcPalette.data,
                fontSize: 11,
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTargetLevelBox(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _ExpCalcPalette.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _ExpCalcPalette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.expCalcTargetLevel,
            style: const TextStyle(color: _ExpCalcPalette.target, fontSize: 11),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              InkWell(
                key: const Key('exp-calc-target-level-decrease'),
                onTap: () => _stepTargetLevel(-1),
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: _ExpCalcPalette.surfaceRaised,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: _ExpCalcPalette.border),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    '－',
                    style: TextStyle(
                      color: _ExpCalcPalette.text,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  key: const Key('exp-calc-target-level'),
                  controller: _targetLevelController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(
                    color: _ExpCalcPalette.target,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    border: InputBorder.none,
                    prefixText: 'Lv. ',
                    prefixStyle: TextStyle(
                      color: _ExpCalcPalette.target,
                      fontSize: 14,
                    ),
                  ),
                  onChanged: _onTargetLevelInput,
                ),
              ),
              InkWell(
                key: const Key('exp-calc-target-level-increase'),
                onTap: () => _stepTargetLevel(1),
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: _ExpCalcPalette.surfaceRaised,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: _ExpCalcPalette.border),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    '＋',
                    style: TextStyle(
                      color: _ExpCalcPalette.text,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '$_targetExp EXP',
              style: const TextStyle(
                color: _ExpCalcPalette.target,
                fontSize: 11,
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep2Card(
    AppLocalizations l10n, {
    required bool isCompact,
    required bool isNarrow,
  }) {
    return Container(
      padding: EdgeInsets.all(isNarrow ? 12 : 16),
      decoration: BoxDecoration(
        color: _ExpCalcPalette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _ExpCalcPalette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: _ExpCalcPalette.target,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.expCalcStep2Title,
                  style: const TextStyle(
                    color: _ExpCalcPalette.target,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (!isNarrow) ...[
                const SizedBox(width: 8),
                const Text(
                  'STEP 02',
                  style: TextStyle(
                    color: _ExpCalcPalette.textFaint,
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),

          // Nodes list
          for (var i = 0; i < _routeNodes.length; i++) ...[
            _buildRouteNodeCard(
              l10n,
              _routeNodes[i],
              i,
              isCompact: isCompact,
              isNarrow: isNarrow,
            ),
            if (i < _routeNodes.length - 1) const SizedBox(height: 10),
          ],
          const SizedBox(height: 12),

          // Actions & Summary row
          if (!isCompact)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildAddNodeButton(l10n),
                _buildRouteSummaryBanner(l10n),
              ],
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildRouteSummaryBanner(l10n),
                const SizedBox(height: 8),
                _buildAddNodeButton(l10n),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildAddNodeButton(AppLocalizations l10n) {
    return ElevatedButton.icon(
      key: const Key('exp-calc-add-node-button'),
      style: ElevatedButton.styleFrom(
        backgroundColor: _ExpCalcPalette.surfaceRaised,
        foregroundColor: _ExpCalcPalette.goldSoft,
        side: const BorderSide(color: _ExpCalcPalette.goldDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      icon: const Icon(Icons.add, size: 16),
      label: Text(
        l10n.expCalcAddNode,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
      ),
      onPressed: _addRouteNode,
    );
  }

  Widget _buildRouteSummaryBanner(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _ExpCalcPalette.surfaceInset,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _ExpCalcPalette.border),
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 4,
        children: [
          Text(
            '${l10n.expCalcRouteSummaryPrefix}: ',
            style: const TextStyle(
              color: _ExpCalcPalette.textMuted,
              fontSize: 11,
            ),
          ),
          Text(
            '${_routeNodes.length} ${l10n.expCalcCombatNodesSuffix}',
            style: const TextStyle(
              color: _ExpCalcPalette.target,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            ' · ${l10n.expCalcAccumulatedExpLabel}: ',
            style: const TextStyle(
              color: _ExpCalcPalette.textMuted,
              fontSize: 11,
            ),
          ),
          Text(
            '$_totalSortieExp EXP',
            style: const TextStyle(
              color: _ExpCalcPalette.data,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteNodeCard(
    AppLocalizations l10n,
    _RouteNodeState node,
    int index, {
    required bool isCompact,
    required bool isNarrow,
  }) {
    final currentMap = kPresetMapDatabase.firstWhere(
      (m) => m.id == node.mapId,
      orElse: () => kPresetMapDatabase.first,
    );

    return Container(
      padding: EdgeInsets.all(isNarrow ? 10 : 12),
      decoration: BoxDecoration(
        color: _ExpCalcPalette.surfaceInset,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _ExpCalcPalette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!isCompact)
            // Wide Screen: Single compact row for Map, Point, Base EXP, Subtotal, and Delete
            Row(
              children: [
                _buildNodeIndexBadge(index),
                const SizedBox(width: 8),
                Expanded(flex: 3, child: _buildMapDropdown(node, index)),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: _buildPointDropdown(node, currentMap, index),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 76,
                  height: 36,
                  child: _buildBaseExpField(node, index),
                ),
                const SizedBox(width: 8),
                _buildSubtotalText(node),
                if (_routeNodes.length > 1) ...[
                  const SizedBox(width: 8),
                  _buildRemoveNodeButton(l10n, index),
                ],
              ],
            )
          else ...[
            // Compact Mode (HD Portrait / Narrow window / Mobile)
            // Sub-row 1: Index + Map + Point
            Row(
              children: [
                _buildNodeIndexBadge(index),
                const SizedBox(width: 8),
                Expanded(flex: 1, child: _buildMapDropdown(node, index)),
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: _buildPointDropdown(node, currentMap, index),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Sub-row 2: Base EXP + Subtotal + Remove
            Row(
              children: [
                SizedBox(
                  width: 84,
                  height: 34,
                  child: _buildBaseExpField(node, index),
                ),
                const SizedBox(width: 8),
                _buildSubtotalText(node),
                const Spacer(),
                if (_routeNodes.length > 1) _buildRemoveNodeButton(l10n, index),
              ],
            ),
          ],
          const SizedBox(height: 10),

          // Tactical buffs (Rank, Flagship, MVP)
          if (!isNarrow)
            Row(
              children: [
                Expanded(flex: 4, child: _buildRankSegmented(node, index)),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: _buildFlagshipToggle(l10n, node, index),
                ),
                const SizedBox(width: 8),
                Expanded(flex: 3, child: _buildMvpToggle(l10n, node, index)),
              ],
            )
          else ...[
            // Extremely narrow (< 420px): split into 2 clean sub-rows
            _buildRankSegmented(node, index),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(child: _buildFlagshipToggle(l10n, node, index)),
                const SizedBox(width: 8),
                Expanded(child: _buildMvpToggle(l10n, node, index)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNodeIndexBadge(int index) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: _ExpCalcPalette.goldSurface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _ExpCalcPalette.goldDark),
      ),
      alignment: Alignment.center,
      child: Text(
        '${index + 1}',
        style: const TextStyle(
          color: _ExpCalcPalette.goldSoft,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          fontFamily: 'monospace',
        ),
      ),
    );
  }

  Widget _buildMapDropdown(_RouteNodeState node, int index) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: _ExpCalcPalette.surfaceRaised,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _ExpCalcPalette.borderStrong),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          key: index == 0
              ? const Key('exp-calc-map-selector')
              : Key('exp-calc-map-selector-$index'),
          value: node.mapId,
          dropdownColor: _ExpCalcPalette.surfaceRaised,
          isExpanded: true,
          items: [
            for (final m in kPresetMapDatabase)
              DropdownMenuItem<String>(
                value: m.id,
                child: Text(
                  m.name,
                  style: const TextStyle(
                    color: _ExpCalcPalette.text,
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (newMapId) {
            if (newMapId == null) return;
            setState(() {
              node.mapId = newMapId;
              final newMap = kPresetMapDatabase.firstWhere(
                (m) => m.id == newMapId,
              );
              final firstPoint = newMap.nodes.first;
              node.nodeId = firstPoint.id;
              node.baseExpController.text = '${firstPoint.baseExp}';
            });
          },
        ),
      ),
    );
  }

  Widget _buildPointDropdown(
    _RouteNodeState node,
    SortieMapPreset currentMap,
    int index,
  ) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: _ExpCalcPalette.surfaceRaised,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _ExpCalcPalette.borderStrong),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          key: Key('exp-calc-point-selector-$index'),
          value: node.nodeId,
          dropdownColor: _ExpCalcPalette.surfaceRaised,
          isExpanded: true,
          items: [
            for (final p in currentMap.nodes)
              DropdownMenuItem<String>(
                value: p.id,
                child: Text(
                  p.name,
                  style: const TextStyle(
                    color: _ExpCalcPalette.data,
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (newPointId) {
            if (newPointId == null) return;
            setState(() {
              node.nodeId = newPointId;
              final pt = currentMap.nodes.firstWhere((p) => p.id == newPointId);
              node.baseExpController.text = '${pt.baseExp}';
            });
          },
        ),
      ),
    );
  }

  Widget _buildBaseExpField(_RouteNodeState node, int index) {
    return TextField(
      key: index == 0
          ? const Key('exp-calc-base-exp-input')
          : Key('exp-calc-base-exp-input-$index'),
      controller: node.baseExpController,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: _ExpCalcPalette.text,
        fontSize: 12,
        fontWeight: FontWeight.bold,
      ),
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        filled: true,
        fillColor: _ExpCalcPalette.surfaceRaised,
        suffixText: 'EXP',
        suffixStyle: const TextStyle(color: _ExpCalcPalette.data, fontSize: 9),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: _ExpCalcPalette.borderStrong),
          borderRadius: BorderRadius.circular(6),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: _ExpCalcPalette.gold),
          borderRadius: BorderRadius.circular(6),
        ),
      ),
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _buildSubtotalText(_RouteNodeState node) {
    return Text(
      '${node.computeExp()} EXP',
      style: const TextStyle(
        color: _ExpCalcPalette.data,
        fontSize: 12,
        fontWeight: FontWeight.bold,
        fontFamily: 'monospace',
      ),
    );
  }

  Widget _buildRemoveNodeButton(AppLocalizations l10n, int index) {
    return InkWell(
      key: Key('exp-calc-remove-node-$index'),
      onTap: () => _removeRouteNode(index),
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Text(
          l10n.expCalcRemoveNode,
          style: const TextStyle(color: _ExpCalcPalette.danger, fontSize: 11),
        ),
      ),
    );
  }

  Widget _buildRankSegmented(_RouteNodeState node, int index) {
    return Container(
      height: 34,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: _ExpCalcPalette.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _ExpCalcPalette.border),
      ),
      child: Row(
        children: [
          for (final r in BattleRank.values)
            Expanded(
              child: InkWell(
                key: Key('exp-calc-rank-${r.name}-$index'),
                onTap: () => setState(() => node.rank = r),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: node.rank == r
                        ? _ExpCalcPalette.gold
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    r.label,
                    style: TextStyle(
                      color: node.rank == r
                          ? _ExpCalcPalette.surfaceInset
                          : _ExpCalcPalette.textMuted,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFlagshipToggle(
    AppLocalizations l10n,
    _RouteNodeState node,
    int index,
  ) {
    return InkWell(
      key: index == 0
          ? const Key('exp-calc-flagship-checkbox')
          : Key('exp-calc-flagship-$index'),
      onTap: () => setState(() => node.isFlagship = !node.isFlagship),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: node.isFlagship
              ? _ExpCalcPalette.success.withValues(alpha: 0.5)
              : _ExpCalcPalette.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: node.isFlagship
                ? _ExpCalcPalette.success.withValues(alpha: 0.6)
                : _ExpCalcPalette.border,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                '🎖️ ${l10n.expCalcFlagship}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: node.isFlagship
                      ? _ExpCalcPalette.success
                      : _ExpCalcPalette.textFaint,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: _ExpCalcPalette.success.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                '1.5x',
                style: TextStyle(
                  color: _ExpCalcPalette.success,
                  fontSize: 9,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMvpToggle(
    AppLocalizations l10n,
    _RouteNodeState node,
    int index,
  ) {
    return InkWell(
      key: index == 0
          ? const Key('exp-calc-mvp-checkbox')
          : Key('exp-calc-mvp-$index'),
      onTap: () => setState(() => node.isMvp = !node.isMvp),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: node.isMvp
              ? _ExpCalcPalette.target.withValues(alpha: 0.5)
              : _ExpCalcPalette.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: node.isMvp
                ? _ExpCalcPalette.target.withValues(alpha: 0.6)
                : _ExpCalcPalette.border,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                '👑 ${l10n.expCalcMvp}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: node.isMvp
                      ? _ExpCalcPalette.goldSoft
                      : _ExpCalcPalette.textFaint,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: _ExpCalcPalette.target.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                '2.0x',
                style: TextStyle(
                  color: _ExpCalcPalette.goldSoft,
                  fontSize: 9,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultHudCard(
    AppLocalizations l10n, {
    required bool isCompact,
    required bool isNarrow,
  }) {
    final formulaBreakdowns = _routeNodes
        .map((n) => '${n.mapId}-${n.nodeId}(${n.computeExp()})')
        .join(' + ');

    return Container(
      padding: EdgeInsets.all(isNarrow ? 12 : 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_ExpCalcPalette.surfaceRaised, _ExpCalcPalette.surface],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _ExpCalcPalette.goldDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top formula bar
          if (!isCompact)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.insights,
                      size: 16,
                      color: _ExpCalcPalette.gold,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      l10n.expCalcResultHudTitle,
                      style: const TextStyle(
                        color: _ExpCalcPalette.goldSoft,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Flexible(
                  child: Text(
                    '路线综合: $formulaBreakdowns = $_totalSortieExp EXP/出击',
                    style: const TextStyle(
                      color: _ExpCalcPalette.textMuted,
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.insights,
                      size: 16,
                      color: _ExpCalcPalette.gold,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      l10n.expCalcResultHudTitle,
                      style: const TextStyle(
                        color: _ExpCalcPalette.goldSoft,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: _ExpCalcPalette.goldSurface,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _ExpCalcPalette.goldDark),
                  ),
                  child: Text(
                    '路线综合: $formulaBreakdowns = $_totalSortieExp EXP/出击',
                    style: const TextStyle(
                      color: _ExpCalcPalette.data,
                      fontSize: 10,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 12),

          // Stats columns
          if (!isNarrow)
            Row(
              children: [
                Expanded(child: _buildRemainExpStatCard(l10n)),
                const SizedBox(width: 8),
                Expanded(child: _buildRouteTotalStatCard(l10n)),
                const SizedBox(width: 8),
                Expanded(child: _buildSortieCountStatCard(l10n)),
              ],
            )
          else ...[
            Row(
              children: [
                Expanded(child: _buildRemainExpStatCard(l10n)),
                const SizedBox(width: 8),
                Expanded(child: _buildRouteTotalStatCard(l10n)),
              ],
            ),
            const SizedBox(height: 8),
            _buildSortieCountStatCard(l10n, isFullWidth: true),
          ],
          const SizedBox(height: 12),

          // Add to Track List Action Button
          if (!isCompact)
            Align(
              alignment: Alignment.centerRight,
              child: _buildAddTrackButton(l10n),
            )
          else
            SizedBox(
              width: double.infinity,
              height: 42,
              child: _buildAddTrackButton(l10n),
            ),
        ],
      ),
    );
  }

  Widget _buildRemainExpStatCard(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _ExpCalcPalette.surfaceInset.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _ExpCalcPalette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.expCalcRemainExp,
            style: const TextStyle(
              color: _ExpCalcPalette.textMuted,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '$_remainExp',
              style: const TextStyle(
                color: _ExpCalcPalette.data,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteTotalStatCard(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _ExpCalcPalette.surfaceInset.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _ExpCalcPalette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.expCalcRouteTotal,
            style: const TextStyle(
              color: _ExpCalcPalette.textMuted,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '$_totalSortieExp',
              style: const TextStyle(
                color: _ExpCalcPalette.text,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSortieCountStatCard(
    AppLocalizations l10n, {
    bool isFullWidth = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _ExpCalcPalette.danger.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _ExpCalcPalette.danger.withValues(alpha: 0.3),
        ),
      ),
      child: isFullWidth
          ? Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.military_tech_rounded,
                      color: _ExpCalcPalette.danger,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      l10n.expCalcBattle,
                      style: const TextStyle(
                        color: _ExpCalcPalette.danger,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      '$_sortieCount 次出击',
                      style: const TextStyle(
                        color: _ExpCalcPalette.danger,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.expCalcBattle,
                  style: const TextStyle(
                    color: _ExpCalcPalette.danger,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '$_sortieCount',
                    style: const TextStyle(
                      color: _ExpCalcPalette.danger,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildAddTrackButton(AppLocalizations l10n) {
    return ElevatedButton.icon(
      key: const Key('exp-calc-add-button'),
      style: ElevatedButton.styleFrom(
        backgroundColor: _ExpCalcPalette.gold,
        foregroundColor: _ExpCalcPalette.surfaceInset,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 4,
      ),
      icon: const Icon(Icons.playlist_add, size: 18),
      label: Text(
        l10n.expCalcAddTrack,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
      ),
      onPressed: _addTrackItem,
    );
  }

  Widget _buildTrackingTableCard(
    AppLocalizations l10n, {
    required bool isCompact,
    required bool isNarrow,
  }) {
    final showCardView = _preferCardView ?? isCompact;

    return Container(
      padding: EdgeInsets.all(isNarrow ? 12 : 16),
      decoration: BoxDecoration(
        color: _ExpCalcPalette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _ExpCalcPalette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        l10n.expCalcTrackListTitle,
                        style: TextStyle(
                          color: _ExpCalcPalette.text,
                          fontSize: isNarrow ? 13 : 14,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: _ExpCalcPalette.surfaceRaised,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_trackItems.length}',
                        style: const TextStyle(
                          color: _ExpCalcPalette.data,
                          fontSize: 11,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // View mode switch pills
              Container(
                height: 28,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: _ExpCalcPalette.surfaceRaised,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _ExpCalcPalette.borderStrong),
                ),
                child: Row(
                  children: [
                    InkWell(
                      key: const Key('exp-calc-view-table'),
                      onTap: () => setState(() => _preferCardView = false),
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: !showCardView
                              ? _ExpCalcPalette.gold
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          l10n.expCalcTableView,
                          style: TextStyle(
                            color: !showCardView
                                ? _ExpCalcPalette.surfaceInset
                                : _ExpCalcPalette.textMuted,
                            fontSize: 11,
                            fontWeight: !showCardView
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                    InkWell(
                      key: const Key('exp-calc-view-card'),
                      onTap: () => setState(() => _preferCardView = true),
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: showCardView
                              ? _ExpCalcPalette.gold
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          l10n.expCalcCardView,
                          style: TextStyle(
                            color: showCardView
                                ? _ExpCalcPalette.surfaceInset
                                : _ExpCalcPalette.textMuted,
                            fontSize: 11,
                            fontWeight: showCardView
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!isNarrow) ...[
            const SizedBox(height: 4),
            Text(
              l10n.expCalcAutoSyncHint,
              style: const TextStyle(
                color: _ExpCalcPalette.textFaint,
                fontSize: 11,
              ),
            ),
          ],
          const SizedBox(height: 12),

          if (_trackItems.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  l10n.expCalcEmptyTrackList,
                  style: const TextStyle(
                    color: _ExpCalcPalette.textFaint,
                    fontSize: 13,
                  ),
                ),
              ),
            )
          else if (showCardView)
            KeyedSubtree(
              key: const Key('exp-calc-track-list'),
              child: _buildTrackingCardList(l10n),
            )
          else
            SingleChildScrollView(
              key: const Key('exp-calc-track-list'),
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 700),
                child: DataTable(
                  horizontalMargin: 8,
                  columnSpacing: 16,
                  headingRowHeight: 36,
                  dataRowMinHeight: 38,
                  dataRowMaxHeight: 44,
                  columns: [
                    DataColumn(
                      label: Text(
                        l10n.expCalcShip,
                        style: const TextStyle(
                          color: _ExpCalcPalette.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        l10n.expCalcCurrentLevel,
                        style: const TextStyle(
                          color: _ExpCalcPalette.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        l10n.expCalcTargetLevel,
                        style: const TextStyle(
                          color: _ExpCalcPalette.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        l10n.expCalcRouteSummary,
                        style: const TextStyle(
                          color: _ExpCalcPalette.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        l10n.expCalcRouteTotal,
                        style: const TextStyle(
                          color: _ExpCalcPalette.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        l10n.expCalcRemainExp,
                        style: const TextStyle(
                          color: _ExpCalcPalette.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        l10n.expCalcBattle,
                        style: const TextStyle(
                          color: _ExpCalcPalette.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        l10n.expCalcDelete,
                        style: const TextStyle(
                          color: _ExpCalcPalette.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                  rows: [
                    for (final item in _trackItems)
                      _buildTrackDataRow(l10n, item),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTrackingCardList(AppLocalizations l10n) {
    return Column(
      children: [
        for (final item in _trackItems) _buildTrackItemCard(l10n, item),
      ],
    );
  }

  Widget _buildTrackItemCard(AppLocalizations l10n, ExpCalcTrackItem item) {
    final liveLv = item.resolveCurrentLevel(widget.state);
    final remain = item.resolveRemainExp(widget.state);
    final battles = item.resolveBattleCount(widget.state);
    final isDone = remain == 0;
    final routeText = item.routeSummary ?? '${item.map} (基准 ${item.baseExp})';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _ExpCalcPalette.surfaceInset,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDone
              ? _ExpCalcPalette.success.withValues(alpha: 0.5)
              : _ExpCalcPalette.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Row 1: Ship name + Level badge + Delete button
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        item.shipName,
                        style: const TextStyle(
                          color: _ExpCalcPalette.text,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _ExpCalcPalette.goldSurface,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: _ExpCalcPalette.goldDark),
                      ),
                      child: Text(
                        'Lv.$liveLv → Lv.${item.targetLevel}',
                        style: const TextStyle(
                          color: _ExpCalcPalette.data,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              InkWell(
                key: Key('exp-calc-delete-button-${item.id}'),
                onTap: () => _deleteTrackItem(item.id),
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  child: Text(
                    l10n.expCalcDelete,
                    style: const TextStyle(
                      color: _ExpCalcPalette.danger,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Row 2: Route summary
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _ExpCalcPalette.surface,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.alt_route_rounded,
                  size: 14,
                  color: _ExpCalcPalette.textFaint,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    routeText,
                    style: const TextStyle(
                      color: _ExpCalcPalette.text,
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${item.effectiveSortieExp} EXP/出击',
                  style: const TextStyle(
                    color: _ExpCalcPalette.data,
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Row 3: Remain EXP + Sortie count
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '剩 $remain EXP',
                style: TextStyle(
                  color: isDone
                      ? _ExpCalcPalette.success
                      : _ExpCalcPalette.textMuted,
                  fontSize: 12,
                  fontFamily: 'monospace',
                  fontWeight: isDone ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isDone
                      ? _ExpCalcPalette.success.withValues(alpha: 0.5)
                      : _ExpCalcPalette.danger.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isDone
                        ? _ExpCalcPalette.success
                        : _ExpCalcPalette.danger.withValues(alpha: 0.5),
                  ),
                ),
                child: Text(
                  isDone ? l10n.expCalcCompletedTag : '$battles 次',
                  style: TextStyle(
                    color: isDone
                        ? _ExpCalcPalette.success
                        : _ExpCalcPalette.danger,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  DataRow _buildTrackDataRow(AppLocalizations l10n, ExpCalcTrackItem item) {
    final liveLv = item.resolveCurrentLevel(widget.state);
    final remain = item.resolveRemainExp(widget.state);
    final battles = item.resolveBattleCount(widget.state);
    final isDone = remain == 0;
    final routeText = item.routeSummary ?? '${item.map} (基准 ${item.baseExp})';

    return DataRow(
      cells: [
        DataCell(
          Text(
            item.shipName,
            style: const TextStyle(
              color: _ExpCalcPalette.text,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
        DataCell(
          Text(
            'Lv. $liveLv',
            style: const TextStyle(
              color: _ExpCalcPalette.data,
              fontSize: 12,
              fontFamily: 'monospace',
            ),
          ),
        ),
        DataCell(
          Text(
            'Lv. ${item.targetLevel}',
            style: const TextStyle(
              color: _ExpCalcPalette.target,
              fontWeight: FontWeight.bold,
              fontSize: 12,
              fontFamily: 'monospace',
            ),
          ),
        ),
        DataCell(
          Text(
            routeText,
            style: const TextStyle(
              color: _ExpCalcPalette.text,
              fontSize: 11,
              fontFamily: 'monospace',
            ),
          ),
        ),
        DataCell(
          Text(
            '${item.effectiveSortieExp} EXP',
            style: const TextStyle(
              color: _ExpCalcPalette.data,
              fontSize: 12,
              fontFamily: 'monospace',
            ),
          ),
        ),
        DataCell(
          Text(
            '$remain',
            style: TextStyle(
              color: isDone ? _ExpCalcPalette.success : _ExpCalcPalette.text,
              fontSize: 12,
              fontFamily: 'monospace',
            ),
          ),
        ),
        DataCell(
          Text(
            isDone ? l10n.expCalcCompletedTag : '$battles 次',
            style: TextStyle(
              color: isDone ? _ExpCalcPalette.success : _ExpCalcPalette.danger,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
        DataCell(
          InkWell(
            key: Key('exp-calc-delete-button-${item.id}'),
            onTap: () => _deleteTrackItem(item.id),
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Text(
                l10n.expCalcDelete,
                style: const TextStyle(
                  color: _ExpCalcPalette.danger,
                  fontSize: 11,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
