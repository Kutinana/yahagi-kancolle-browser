import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

enum NewShipAcquisitionSource { battle, eventReward, questReward, construction }

class PendingNewShipAcquisition {
  PendingNewShipAcquisition({
    required this.key,
    required Iterable<int> masterIds,
    required this.source,
    required this.occurredAt,
  }) : masterIds = List<int>.unmodifiable(
         (masterIds.where((id) => id > 0).toSet().toList()..sort()),
       );

  final String key;
  final List<int> masterIds;
  final NewShipAcquisitionSource source;
  final DateTime occurredAt;

  Map<String, Object?> toJson() => <String, Object?>{
    'key': key,
    'masterIds': masterIds,
    'source': source.name,
    'occurredAt': occurredAt.toUtc().toIso8601String(),
  };

  static PendingNewShipAcquisition? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final key = raw['key']?.toString() ?? '';
    final sourceName = raw['source']?.toString();
    final occurredAt = DateTime.tryParse(raw['occurredAt']?.toString() ?? '');
    final rawIds = raw['masterIds'];
    final source = NewShipAcquisitionSource.values.where(
      (candidate) => candidate.name == sourceName,
    );
    if (key.isEmpty ||
        occurredAt == null ||
        rawIds is! List ||
        source.isEmpty) {
      return null;
    }
    final ids = rawIds
        .map((value) => value is num ? value.toInt() : int.tryParse('$value'))
        .whereType<int>()
        .where((id) => id > 0);
    return PendingNewShipAcquisition(
      key: key,
      masterIds: ids,
      source: source.first,
      occurredAt: occurredAt,
    );
  }
}

class NewShipReminderStore {
  const NewShipReminderStore(this.preferences);

  final SharedPreferences preferences;

  String _excludedKey(int memberId) => 'new_ship.excluded.$memberId';
  String _pendingKey(int memberId) => 'new_ship.pending.$memberId';

  Future<Set<int>> loadExcludedFamilyIds(int memberId) async {
    if (memberId <= 0) return <int>{};
    try {
      final raw = jsonDecode(
        preferences.getString(_excludedKey(memberId)) ?? '[]',
      );
      if (raw is! List) return <int>{};
      return raw
          .map((value) => value is num ? value.toInt() : int.tryParse('$value'))
          .whereType<int>()
          .where((id) => id > 0)
          .toSet();
    } on FormatException {
      return <int>{};
    }
  }

  Future<void> saveExcludedFamilyIds(int memberId, Set<int> ids) async {
    if (memberId <= 0) return;
    final sorted = ids.where((id) => id > 0).toList()..sort();
    await preferences.setString(_excludedKey(memberId), jsonEncode(sorted));
  }

  Future<List<PendingNewShipAcquisition>> loadPending(int memberId) async {
    if (memberId <= 0) return <PendingNewShipAcquisition>[];
    try {
      final raw = jsonDecode(
        preferences.getString(_pendingKey(memberId)) ?? '[]',
      );
      if (raw is! List) return <PendingNewShipAcquisition>[];
      return <PendingNewShipAcquisition>[
        for (final value in raw)
          if (PendingNewShipAcquisition.fromJson(value) case final pending?)
            pending,
      ];
    } on FormatException {
      return <PendingNewShipAcquisition>[];
    }
  }

  Future<void> savePending(
    int memberId,
    Iterable<PendingNewShipAcquisition> acquisitions,
  ) async {
    if (memberId <= 0) return;
    final byKey = <String, PendingNewShipAcquisition>{};
    for (final acquisition in acquisitions) {
      if (acquisition.key.isNotEmpty && acquisition.masterIds.isNotEmpty) {
        byKey[acquisition.key] = acquisition;
      }
    }
    final values = byKey.values.toList()
      ..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
    final retained = values.length > 128
        ? values.sublist(values.length - 128)
        : values;
    await preferences.setString(
      _pendingKey(memberId),
      jsonEncode(retained.map((item) => item.toJson()).toList()),
    );
  }
}
