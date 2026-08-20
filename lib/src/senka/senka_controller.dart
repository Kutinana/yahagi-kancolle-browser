import 'dart:async';

import 'package:flutter/foundation.dart';

import '../bridge/captured_api_event.dart';
import '../game_state/game_api_event_pipeline.dart';
import '../performance/frame_notification_coalescer.dart';
import 'senka_catalog.dart';
import 'senka_reducer.dart';
import 'senka_state.dart';
import 'senka_store.dart';

class SenkaController extends ChangeNotifier implements GameApiEventConsumer {
  SenkaController({
    required this.store,
    this._reducer = const SenkaReducer(),
    DateTime Function()? now,
    FrameNotificationCoalescer? captureNotifications,
  }) : _now = now ?? DateTime.now,
       _captureNotifications =
           captureNotifications ?? FrameNotificationCoalescer(),
       _state = SenkaState.forMonth(
         currentSenkaMonthKey((now ?? DateTime.now)()),
       );

  final SenkaStore store;
  final SenkaReducer _reducer;
  final FrameNotificationCoalescer _captureNotifications;
  final DateTime Function() _now;
  SenkaState _state;
  Future<void> _queue = Future<void>.value();
  int _revision = 0;
  bool _disposed = false;

  SenkaState get state => _state;
  @override
  Future<void> get idle => _queue;

  @override
  bool supportsPath(String path) => _reducer.supportsPath(path);

  Future<void> initialize() async {
    final revisionAtStart = _revision;
    final SenkaState? loaded;
    try {
      loaded = await store.load();
    } catch (_) {
      return;
    }
    if (_disposed || loaded == null || _revision != revisionAtStart) return;
    final month = currentSenkaMonthKey(_now());
    final migrated = migrateSenkaStateToMonth(loaded, month);
    _state = migrated;
    final revision = ++_revision;
    notifyListeners();
    if (!identical(migrated, loaded)) {
      _enqueue(() => _saveIfCurrent(migrated, revision));
      await _queue;
    }
  }

  @override
  void accept(CapturedApiEvent event) {
    if (_disposed) return;
    _enqueue(() async {
      if (_disposed) return;
      final next = _reducer.reduce(_state, event);
      if (identical(next, _state)) return;
      _state = next;
      final revision = ++_revision;
      _captureNotifications.schedule(notifyListeners);
      await _saveIfCurrent(next, revision);
    });
  }

  void cycleEoReward(int id) {
    if (senkaEoById(id) == null || _disposed) return;
    final values = Map<int, SenkaRewardStatus>.of(_state.eoStatuses);
    values[id] = (values[id] ?? SenkaRewardStatus.deferred).next;
    _replace(_state.copyWith(eoStatuses: values));
  }

  void cycleQuestReward(int id) {
    if (senkaQuestById(id) == null || _disposed) return;
    final values = Map<int, SenkaRewardStatus>.of(_state.questStatuses);
    values[id] = (values[id] ?? SenkaRewardStatus.deferred).next;
    _replace(_state.copyWith(questStatuses: values));
  }

  void toggleEo(int id) => cycleEoReward(id);

  void toggleQuest(int id) => cycleQuestReward(id);

  void setCurrentSenka(double value) {
    if (!value.isFinite || _disposed) return;
    final normalized = value < 0 ? 0.0 : value;
    if (_state.calculatorCurrentSenka == normalized) return;
    _replace(_state.copyWith(calculatorCurrentSenka: normalized));
  }

  void setTargetSenka(double value) {
    if (!value.isFinite || _disposed) return;
    final normalized = value < 0 ? 0.0 : value;
    if (_state.targetSenka == normalized) return;
    _replace(_state.copyWith(targetSenka: normalized));
  }

  void toggleSortieFavorite(String mapKey) {
    if (!_canToggleSortieMap(mapKey)) return;
    final values = Set<String>.of(_state.favoriteSortieMapKeys);
    values.contains(mapKey) ? values.remove(mapKey) : values.add(mapKey);
    _replace(_state.copyWith(favoriteSortieMapKeys: values));
  }

  void toggleSortieHidden(String mapKey) {
    if (!_canToggleSortieMap(mapKey)) return;
    final values = Set<String>.of(_state.hiddenSortieMapKeys);
    values.contains(mapKey) ? values.remove(mapKey) : values.add(mapKey);
    _replace(_state.copyWith(hiddenSortieMapKeys: values));
  }

  bool _canToggleSortieMap(String mapKey) =>
      !_disposed &&
      RegExp(r'^[1-9]\d*-[1-9]\d*$').hasMatch(mapKey) &&
      _state.sortieStats.containsKey(mapKey);

  void _replace(SenkaState next) {
    _state = next;
    final revision = ++_revision;
    notifyListeners();
    _enqueue(() => _saveIfCurrent(next, revision));
  }

  void _enqueue(Future<void> Function() operation) {
    final scheduled = _queue.then<void>(
      (_) => operation(),
      onError: (Object _, StackTrace _) => operation(),
    );
    _queue = scheduled.then<void>((_) {}, onError: (Object _, StackTrace _) {});
  }

  Future<void> _saveIfCurrent(SenkaState snapshot, int revision) async {
    if (revision != _revision) return;
    await store.save(snapshot);
  }

  @override
  void dispose() {
    _disposed = true;
    _captureNotifications.dispose();
    super.dispose();
  }
}
