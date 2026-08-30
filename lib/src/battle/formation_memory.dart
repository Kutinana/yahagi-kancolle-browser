import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

const Set<int> validFormationIds = <int>{1, 2, 3, 4, 5, 6, 11, 12, 13, 14};

final RegExp _formationMemoryKeyPattern = RegExp(
  r'^[1-9]\d*-[1-9]\d*-[1-9]\d*$',
);

String formationMemoryKey({
  required int mapAreaId,
  required int mapInfoNo,
  required int node,
}) => '$mapAreaId-$mapInfoNo-$node';

bool isValidFormationMemoryKey(String value) =>
    _formationMemoryKeyPattern.hasMatch(value);

abstract interface class FormationMemoryStore {
  Future<Map<String, int>> load();

  Future<void> save(Map<String, int> formations);
}

final class SharedPreferencesFormationMemoryStore
    implements FormationMemoryStore {
  static const String _key = 'battle.formationMemory';

  @override
  Future<Map<String, int>> load() async {
    final raw = (await SharedPreferences.getInstance()).getString(_key);
    if (raw == null || raw.isEmpty) return <String, int>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return <String, int>{};
      return <String, int>{
        for (final entry in decoded.entries)
          if (entry.key is String &&
              isValidFormationMemoryKey(entry.key as String) &&
              entry.value is int &&
              validFormationIds.contains(entry.value))
            entry.key as String: entry.value as int,
      };
    } on FormatException {
      return <String, int>{};
    }
  }

  @override
  Future<void> save(Map<String, int> formations) async {
    final saved = await (await SharedPreferences.getInstance()).setString(
      _key,
      jsonEncode(formations),
    );
    if (!saved) throw StateError('formation memory was not saved');
  }
}

final class MemoryFormationMemoryStore implements FormationMemoryStore {
  MemoryFormationMemoryStore([Map<String, int> initial = const <String, int>{}])
    : _values = Map<String, int>.from(initial);

  Map<String, int> _values;
  int saveCount = 0;

  Map<String, int> get values => Map<String, int>.unmodifiable(_values);

  @override
  Future<Map<String, int>> load() async => Map<String, int>.from(_values);

  @override
  Future<void> save(Map<String, int> formations) async {
    saveCount++;
    _values = Map<String, int>.from(formations);
  }
}

final class FormationMemoryController {
  FormationMemoryController._(this._store, this._formations);

  final FormationMemoryStore _store;
  final Map<String, int> _formations;
  Future<void> _pendingSave = Future<void>.value();

  static Future<FormationMemoryController> load(
    FormationMemoryStore store,
  ) async => FormationMemoryController._(
    store,
    Map<String, int>.from(await store.load()),
  );

  int? formationFor({
    required int mapAreaId,
    required int mapInfoNo,
    required int node,
  }) {
    if (mapAreaId <= 0 || mapInfoNo <= 0 || node <= 0) return null;
    return _formations[formationMemoryKey(
      mapAreaId: mapAreaId,
      mapInfoNo: mapInfoNo,
      node: node,
    )];
  }

  Future<void> remember({
    required int mapAreaId,
    required int mapInfoNo,
    required int node,
    required int formation,
  }) {
    if (!validFormationIds.contains(formation) ||
        mapAreaId <= 0 ||
        mapInfoNo <= 0 ||
        node <= 0) {
      return Future<void>.value();
    }
    final key = formationMemoryKey(
      mapAreaId: mapAreaId,
      mapInfoNo: mapInfoNo,
      node: node,
    );
    if (_formations[key] == formation) return Future<void>.value();
    _formations[key] = formation;
    final snapshot = Map<String, int>.unmodifiable(_formations);
    final operation = _pendingSave
        .catchError((Object _) {})
        .then((_) => _store.save(snapshot));
    _pendingSave = operation;
    return operation;
  }
}
