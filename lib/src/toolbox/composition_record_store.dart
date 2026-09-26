import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

const maxCompositionRecordsPerAccount = 100;

final class CompositionRecordLimitReachedException implements Exception {
  const CompositionRecordLimitReachedException();
}

final class CompositionRecordChange {
  const CompositionRecordChange(
    this.memberId,
    this.id, {
    this.deleted = false,
    this.refreshOnly = false,
  });
  final int memberId;
  final String id;
  final bool deleted;
  final bool refreshOnly;
}

final class CompositionRecord {
  const CompositionRecord({
    required this.id,
    required this.createdAt,
    required this.note,
    this.name = '',
    required this.fleetForm,
    required this.targetMap,
    required this.fleetIds,
    required this.landBaseCount,
    this.snapshotJson,
    this.landBaseAreaId,
    this.landBaseIds = const [],
    this.planeCountMode = 'maximum',
    this.mapTag = '',
  });

  final String id;
  final DateTime createdAt;
  final String note;
  final String name;
  final String fleetForm;
  final String targetMap;
  final List<int> fleetIds;
  final int landBaseCount;
  final String? snapshotJson;
  final int? landBaseAreaId;
  final List<int> landBaseIds;
  final String planeCountMode;

  /// `none`, `normal:1-1`, or `event`; older records derive this from targetMap.
  final String mapTag;

  String get effectiveMapTag {
    if (mapTag.isNotEmpty) return mapTag;
    if (targetMap.trim().isEmpty) return 'none';
    final normal = RegExp(r'^([1-7]-\d+)(?=\s|$)').firstMatch(targetMap.trim());
    return normal == null ? 'event' : 'normal:${normal.group(1)}';
  }

  CompositionRecord withNote(String value) => CompositionRecord(
    id: id,
    createdAt: createdAt,
    note: value,
    name: name,
    fleetForm: fleetForm,
    targetMap: targetMap,
    fleetIds: fleetIds,
    landBaseCount: landBaseCount,
    snapshotJson: snapshotJson,
    landBaseAreaId: landBaseAreaId,
    landBaseIds: landBaseIds,
    planeCountMode: planeCountMode,
    mapTag: mapTag,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'createdAt': createdAt.toIso8601String(),
    'note': note,
    'name': name,
    'fleetForm': fleetForm,
    'targetMap': targetMap,
    'fleetIds': fleetIds,
    'landBaseCount': landBaseCount,
    if (snapshotJson != null) 'snapshotJson': snapshotJson,
    if (landBaseAreaId != null) 'landBaseAreaId': landBaseAreaId,
    if (landBaseIds.isNotEmpty) 'landBaseIds': landBaseIds,
    if (snapshotJson != null) 'planeCountMode': planeCountMode,
    if (mapTag.isNotEmpty) 'mapTag': mapTag,
  };

  factory CompositionRecord.fromJson(Map<String, dynamic> json) =>
      CompositionRecord(
        id: json['id'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        note: json['note'] as String? ?? '',
        name: json['name'] as String? ?? '',
        fleetForm: json['fleetForm'] as String? ?? '',
        targetMap: json['targetMap'] as String? ?? '',
        fleetIds: (json['fleetIds'] as List<dynamic>? ?? const [])
            .whereType<num>()
            .map((id) => id.toInt())
            .toList(),
        landBaseCount: json['landBaseCount'] as int? ?? 0,
        snapshotJson: json['snapshotJson'] as String?,
        landBaseAreaId: (json['landBaseAreaId'] as num?)?.toInt(),
        landBaseIds: (json['landBaseIds'] as List<dynamic>? ?? const [])
            .whereType<num>()
            .map((id) => id.toInt())
            .toList(),
        planeCountMode: json['planeCountMode'] as String? ?? 'maximum',
        mapTag: json['mapTag'] as String? ?? '',
      );
}

abstract interface class CompositionRecordStore {
  Future<List<CompositionRecord>> load(int memberId);
  Future<CompositionRecord> create({
    required int memberId,
    required Uint8List png,
    required String note,
    required String name,
    required String fleetForm,
    required String targetMap,
    required List<int> fleetIds,
    required int landBaseCount,
    required DateTime createdAt,
    String? snapshotJson,
    int? landBaseAreaId,
    List<int> landBaseIds = const [],
    String planeCountMode = 'maximum',
    String mapTag = '',
  });
  Future<Uint8List> readPng(int memberId, String id);
  Future<void> updateNote(int memberId, String id, String note);
  Future<void> delete(int memberId, String id);
}

final class FileCompositionRecordStore implements CompositionRecordStore {
  FileCompositionRecordStore({Future<Directory> Function()? rootDirectory})
    : _rootDirectory = rootDirectory ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _rootDirectory;
  Future<Directory> supportDirectory() => _rootDirectory();
  static final Map<String, Future<void>> _pendingWrites = {};
  static final Set<String> _maintenanceDirectories = {};
  static int _nextSequence = 0;
  static final StreamController<CompositionRecordChange> _changes =
      StreamController<CompositionRecordChange>.broadcast(sync: true);
  static Stream<CompositionRecordChange> get changes => _changes.stream;

  Future<void> enterMaintenance(int memberId) async {
    final key = path.normalize((await _directory(memberId)).absolute.path);
    _maintenanceDirectories.add(key);
    await _pendingWrites[key];
  }

  Future<void> leaveMaintenance(int memberId) async {
    final key = path.normalize((await _directory(memberId)).absolute.path);
    _maintenanceDirectories.remove(key);
  }

  Future<T> _serialize<T>(
    int memberId,
    Future<T> Function() action, {
    bool allowDuringMaintenance = false,
  }) async {
    final key = path.normalize((await _directory(memberId)).absolute.path);
    final previous = _pendingWrites[key];
    final done = Completer<void>();
    _pendingWrites[key] = done.future;
    if (previous != null) await previous;
    try {
      if (!allowDuringMaintenance && _maintenanceDirectories.contains(key)) {
        throw StateError('Composition records are paused for restore');
      }
      return await action();
    } finally {
      if (identical(_pendingWrites[key], done.future)) {
        _pendingWrites.remove(key);
      }
      done.complete();
    }
  }

  Future<Directory> _directory(int memberId) async {
    if (memberId <= 0) throw StateError('Account identity is unavailable');
    final root = await _rootDirectory();
    return Directory(path.join(root.path, 'composition_records', '$memberId'));
  }

  Future<File> _index(int memberId) async =>
      File(path.join((await _directory(memberId)).path, 'records.json'));

  Future<File> _image(int memberId, String id) async {
    if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(id)) {
      throw ArgumentError.value(id, 'id');
    }
    return File(path.join((await _directory(memberId)).path, '$id.png'));
  }

  @override
  Future<List<CompositionRecord>> load(int memberId) async {
    if (memberId <= 0) return [];
    final index = await _index(memberId);
    if (!await index.exists()) return [];
    final decoded = jsonDecode(await index.readAsString());
    if (decoded is! List) throw const FormatException('Invalid record index');
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(CompositionRecord.fromJson)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<void> _writeIndex(
    int memberId,
    List<CompositionRecord> records,
  ) async {
    final index = await _index(memberId);
    await index.parent.create(recursive: true);
    final pending = File('${index.path}.tmp');
    await pending.writeAsString(
      jsonEncode(records.map((e) => e.toJson()).toList()),
      flush: true,
    );
    await pending.rename(index.path);
  }

  @override
  Future<CompositionRecord> create({
    required int memberId,
    required Uint8List png,
    required String note,
    required String name,
    required String fleetForm,
    required String targetMap,
    required List<int> fleetIds,
    required int landBaseCount,
    required DateTime createdAt,
    String? snapshotJson,
    int? landBaseAreaId,
    List<int> landBaseIds = const [],
    String planeCountMode = 'maximum',
    String mapTag = '',
  }) => _serialize(memberId, () async {
    final records = await load(memberId);
    if (records.length >= maxCompositionRecordsPerAccount) {
      throw const CompositionRecordLimitReachedException();
    }
    final record = CompositionRecord(
      id: '${DateTime.now().microsecondsSinceEpoch}_${_nextSequence++}',
      createdAt: createdAt,
      note: note.trim(),
      name: name.trim(),
      fleetForm: fleetForm,
      targetMap: targetMap,
      fleetIds: List.unmodifiable(fleetIds),
      landBaseCount: landBaseCount,
      snapshotJson: snapshotJson,
      landBaseAreaId: landBaseAreaId,
      landBaseIds: List.unmodifiable(landBaseIds),
      planeCountMode: planeCountMode,
      mapTag: mapTag,
    );
    final image = await _image(memberId, record.id);
    await image.parent.create(recursive: true);
    try {
      await image.writeAsBytes(png, flush: true);
      await _writeIndex(memberId, [record, ...records]);
    } catch (_) {
      if (await image.exists()) await image.delete();
      rethrow;
    }
    _changes.add(CompositionRecordChange(memberId, record.id));
    return record;
  });

  @override
  Future<Uint8List> readPng(int memberId, String id) async =>
      (await _image(memberId, id)).readAsBytes();

  @override
  Future<void> updateNote(int memberId, String id, String note) =>
      _serialize(memberId, () async {
        final records = await load(memberId);
        final index = records.indexWhere((record) => record.id == id);
        if (index < 0) throw StateError('Record no longer exists');
        records[index] = records[index].withNote(note.trim());
        await _writeIndex(memberId, records);
        _changes.add(CompositionRecordChange(memberId, id));
      });

  @override
  Future<void> delete(int memberId, String id) =>
      _serialize(memberId, () async {
        final records = await load(memberId);
        if (!records.any((record) => record.id == id)) return;
        await _writeIndex(
          memberId,
          records.where((record) => record.id != id).toList(),
        );
        final image = await _image(memberId, id);
        if (await image.exists()) await image.delete();
        _changes.add(CompositionRecordChange(memberId, id, deleted: true));
      });

  /// Bulk cleanup deliberately emits no deletion events: the external
  /// archive remains available for a later restore.
  Future<int> clearAll(int memberId) => _serialize(memberId, () async {
    final records = await load(memberId);
    return _clearAllLocked(memberId, records);
  });

  /// The comparison and deletion share the store's per-account file lock.
  /// A record created or edited after backup verification is never discarded.
  Future<int?> clearAllIfSnapshotMatches(
    int memberId,
    List<CompositionRecord> expected,
  ) => _serialize(memberId, () async {
    final records = await load(memberId);
    final actualJson = jsonEncode(
      records.map((record) => record.toJson()).toList(),
    );
    final expectedJson = jsonEncode(
      expected.map((record) => record.toJson()).toList(),
    );
    if (actualJson != expectedJson) return null;
    return _clearAllLocked(memberId, records);
  });

  Future<int> _clearAllLocked(
    int memberId,
    List<CompositionRecord> records,
  ) async {
    if (records.isEmpty) return 0;
    await _writeIndex(memberId, const []);
    for (final record in records) {
      final image = await _image(memberId, record.id);
      if (await image.exists()) await image.delete();
    }
    _changes.add(CompositionRecordChange(memberId, '', refreshOnly: true));
    return records.length;
  }

  /// Restored records are data-only. The toolbox recreates an image on demand.
  Future<void> replaceAll(
    int memberId,
    List<CompositionRecord> records, {
    bool allowLegacy = false,
    bool removeImages = true,
  }) => _serialize(memberId, () async {
    for (final record in records) {
      if ((!allowLegacy &&
              (record.snapshotJson == null || record.snapshotJson!.isEmpty)) ||
          !RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(record.id)) {
        throw const FormatException('Invalid composition record');
      }
    }
    final oldRecords = await load(memberId);
    await _writeIndex(memberId, records);
    if (removeImages) {
      for (final old in oldRecords) {
        final image = await _image(memberId, old.id);
        if (await image.exists()) await image.delete();
      }
    }
    _changes.add(CompositionRecordChange(memberId, '', refreshOnly: true));
  }, allowDuringMaintenance: true);

  Future<void> purgeImages(int memberId) => _serialize(memberId, () async {
    final directory = await _directory(memberId);
    if (!await directory.exists()) return;
    await for (final item in directory.list()) {
      if (item is File && item.path.endsWith('.png')) {
        await item.delete();
      }
    }
  }, allowDuringMaintenance: true);
}
