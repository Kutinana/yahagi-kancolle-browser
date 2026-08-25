import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../bridge/captured_api_event.dart';
import '../game_state/game_api_event_pipeline.dart';
import '../game_state/game_state.dart';
import '../inventory/unowned_inventory_projection.dart';
import 'new_ship_reminder_store.dart';

class NewShipAlert {
  NewShipAlert({
    required this.key,
    required Iterable<int> masterIds,
    required Iterable<NewShipAcquisitionSource> sources,
    required this.occurredAt,
  }) : masterIds = List<int>.unmodifiable((masterIds.toSet().toList()..sort())),
       sources = Set<NewShipAcquisitionSource>.unmodifiable(sources.toSet());

  final String key;
  final List<int> masterIds;
  final Set<NewShipAcquisitionSource> sources;
  final DateTime occurredAt;
}

typedef NewShipAlertPublisher = void Function(NewShipAlert alert);

final class NewShipReminderController extends ChangeNotifier
    implements GameApiEventConsumer {
  NewShipReminderController({
    required this.stateProvider,
    required this.store,
    required this.onPublish,
  });

  final GameState Function() stateProvider;
  final NewShipReminderStore store;
  final NewShipAlertPublisher onPublish;
  Future<void> _queue = Future<void>.value();
  final Set<String> _acceptedEventKeys = <String>{};
  Set<int> _excludedFamilyIds = <int>{};
  int _loadedMemberId = 0;
  NewShipAlert? _currentAlert;

  Set<int> get excludedFamilyIds => Set<int>.unmodifiable(_excludedFamilyIds);
  NewShipAlert? get currentAlert => _currentAlert;

  @override
  Future<void> get idle => _queue;

  @override
  bool supportsPath(String path) =>
      path == '/kcsapi/api_port/port' ||
      path.endsWith('/battleresult') ||
      path.endsWith('/battle_result') ||
      path == '/kcsapi/api_req_kousyou/getship' ||
      path == '/kcsapi/api_req_quest/clearitemget' ||
      path == '/kcsapi/api_req_map/next';

  @override
  void accept(CapturedApiEvent event) {
    final stateBeforeEvent = stateProvider();
    _queue = _queue.then(
      (_) => _process(event, stateBeforeEvent),
      onError: (_) => _process(event, stateBeforeEvent),
    );
  }

  Future<void> setFamilyExcluded(int familyRootId, bool excluded) async {
    final memberId = stateProvider().memberId;
    await _ensureAccount(memberId);
    if (familyRootId <= 0 || memberId <= 0) return;
    if (excluded) {
      _excludedFamilyIds.add(familyRootId);
    } else {
      _excludedFamilyIds.remove(familyRootId);
    }
    await store.saveExcludedFamilyIds(memberId, _excludedFamilyIds);
    notifyListeners();
  }

  Future<void> clearExcludedFamilies() async {
    final memberId = stateProvider().memberId;
    await _ensureAccount(memberId);
    _excludedFamilyIds.clear();
    await store.saveExcludedFamilyIds(memberId, _excludedFamilyIds);
    notifyListeners();
  }

  void acknowledge(String alertKey) {
    if (_currentAlert?.key != alertKey) return;
    _currentAlert = null;
    notifyListeners();
  }

  Future<void> _process(CapturedApiEvent event, GameState state) async {
    if (!supportsPath(event.path) || event.apiResult != 1) return;
    final memberId = state.memberId;
    if (memberId <= 0) return;
    await _ensureAccount(memberId);
    final eventKey = '${event.path}:${event.sequence}';
    if (!_acceptedEventKeys.add(eventKey)) return;
    if (_acceptedEventKeys.length > 512)
      _acceptedEventKeys.remove(_acceptedEventKeys.first);

    if (event.path == '/kcsapi/api_port/port') {
      await _publishPending(memberId);
      return;
    }

    final data = _apiData(event);
    final source = _sourceFor(event.path);
    final detected = _shipMasterIds(data, event.path);
    final eligible = _eligibleMasterIds(state, detected);
    if (eligible.isEmpty) return;

    final pending = PendingNewShipAcquisition(
      key: eventKey,
      masterIds: eligible,
      source: source,
      occurredAt: event.capturedAt,
    );
    if (source == NewShipAcquisitionSource.battle) {
      final existing = await store.loadPending(memberId);
      await store.savePending(memberId, <PendingNewShipAcquisition>[
        ...existing,
        pending,
      ]);
      return;
    }
    _publish(<PendingNewShipAcquisition>[pending]);
  }

  Future<void> _ensureAccount(int memberId) async {
    if (memberId <= 0 || memberId == _loadedMemberId) return;
    _excludedFamilyIds = await store.loadExcludedFamilyIds(memberId);
    _loadedMemberId = memberId;
    notifyListeners();
  }

  Future<void> _publishPending(int memberId) async {
    final pending = await store.loadPending(memberId);
    await store.savePending(memberId, const <PendingNewShipAcquisition>[]);
    if (pending.isNotEmpty) _publish(pending);
  }

  void _publish(List<PendingNewShipAcquisition> acquisitions) {
    final ids = <int>{};
    final sources = <NewShipAcquisitionSource>{};
    var occurredAt = acquisitions.first.occurredAt;
    final keys = <String>[];
    final projection = UnownedInventoryProjection(stateProvider());
    for (final acquisition in acquisitions) {
      keys.add(acquisition.key);
      sources.add(acquisition.source);
      if (acquisition.occurredAt.isAfter(occurredAt)) {
        occurredAt = acquisition.occurredAt;
      }
      for (final id in acquisition.masterIds) {
        if (!_excludedFamilyIds.contains(projection.familyRootOf(id))) {
          ids.add(id);
        }
      }
    }
    if (ids.isEmpty) return;
    keys.sort();
    final alert = NewShipAlert(
      key: keys.join('|'),
      masterIds: ids,
      sources: sources,
      occurredAt: occurredAt,
    );
    _currentAlert = alert;
    onPublish(alert);
    notifyListeners();
  }

  Set<int> _eligibleMasterIds(GameState state, Set<int> detected) {
    final projection = UnownedInventoryProjection(state);
    final ownedRoots = state.ships.values
        .map((ship) => projection.familyRootOf(ship.masterId))
        .toSet();
    return <int>{
      for (final id in detected)
        if (state.masterShips.containsKey(id) &&
            !ownedRoots.contains(projection.familyRootOf(id)) &&
            !_excludedFamilyIds.contains(projection.familyRootOf(id)))
          id,
    };
  }

  static NewShipAcquisitionSource _sourceFor(String path) {
    if (path.endsWith('/battleresult') || path.endsWith('/battle_result')) {
      return NewShipAcquisitionSource.battle;
    }
    if (path == '/kcsapi/api_req_kousyou/getship') {
      return NewShipAcquisitionSource.construction;
    }
    if (path == '/kcsapi/api_req_quest/clearitemget') {
      return NewShipAcquisitionSource.questReward;
    }
    return NewShipAcquisitionSource.eventReward;
  }

  static Object? _apiData(CapturedApiEvent event) {
    try {
      final envelope = event.decodedEnvelope ?? jsonDecode(event.responseBody);
      return envelope is Map ? envelope['api_data'] : null;
    } on FormatException {
      return null;
    }
  }

  static Set<int> _shipMasterIds(Object? data, String path) {
    if (data is! Map) return <int>{};
    if (path.endsWith('/battleresult') || path.endsWith('/battle_result')) {
      final ship = data['api_get_ship'];
      return ship is Map ? <int>{?_positiveInt(ship['api_ship_id'])} : <int>{};
    }
    if (path == '/kcsapi/api_req_kousyou/getship') {
      final ship = data['api_ship'];
      return ship is Map ? <int>{?_positiveInt(ship['api_ship_id'])} : <int>{};
    }
    final result = <int>{};
    _collectRewardShipIds(data, result);
    return result;
  }

  static void _collectRewardShipIds(Object? value, Set<int> result) {
    if (value is List) {
      for (final item in value) _collectRewardShipIds(item, result);
      return;
    }
    if (value is! Map) return;
    final direct = _positiveInt(value['api_ship_id']);
    if (direct != null) result.add(direct);
    final type = _positiveInt(value['api_type']);
    final item = value['api_item'];
    if (type == 1 && item is Map) {
      final rewardId = _positiveInt(item['api_id']);
      if (rewardId != null) result.add(rewardId);
    }
    for (final child in value.values) _collectRewardShipIds(child, result);
  }

  static int? _positiveInt(Object? value) {
    final parsed = value is num ? value.toInt() : int.tryParse('$value');
    return parsed != null && parsed > 0 ? parsed : null;
  }
}
