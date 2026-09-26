import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/composition_record_store.dart';

void main() {
  test('full legacy index rejects saves without creating a PNG', () async {
    final root = await Directory.systemTemp.createTemp('composition-limit-');
    addTearDown(() => root.delete(recursive: true));
    await _seedIndex(root, 12, 101);
    final store = FileCompositionRecordStore(rootDirectory: () async => root);

    await expectLater(
      _createRecord(store, 12),
      throwsA(isA<CompositionRecordLimitReachedException>()),
    );
    expect(await store.load(12), hasLength(101));
    final directory = Directory('${root.path}/composition_records/12');
    expect(
      await directory.list().where((file) => file.path.endsWith('.png')).length,
      0,
    );

    await store.delete(12, 'legacy-0');
    await store.delete(12, 'legacy-1');
    final saved = await _createRecord(store, 12);
    expect(await store.load(12), hasLength(100));
    expect(await store.readPng(12, saved.id), [1, 2, 3]);
  });

  test('concurrent saves from separate stores cannot exceed 100', () async {
    final root = await Directory.systemTemp.createTemp('composition-limit-');
    addTearDown(() => root.delete(recursive: true));
    await _seedIndex(root, 12, 99);
    final first = FileCompositionRecordStore(rootDirectory: () async => root);
    final second = FileCompositionRecordStore(rootDirectory: () async => root);

    final results = await Future.wait([
      _createRecord(
        first,
        12,
      ).then<Object>((value) => value, onError: (Object error) => error),
      _createRecord(
        second,
        12,
      ).then<Object>((value) => value, onError: (Object error) => error),
    ]);
    expect(results.whereType<CompositionRecord>(), hasLength(1));
    expect(
      results.whereType<CompositionRecordLimitReachedException>(),
      hasLength(1),
    );
    expect(await first.load(12), hasLength(100));
    expect(await _createRecord(first, 13), isA<CompositionRecord>());
  });

  test('concurrent account writes keep every record and its PNG', () async {
    final root = await Directory.systemTemp.createTemp('composition-race-');
    addTearDown(() => root.delete(recursive: true));
    final first = FileCompositionRecordStore(rootDirectory: () async => root);
    final second = FileCompositionRecordStore(rootDirectory: () async => root);

    final saved = await Future.wait([
      _createRecord(first, 12),
      _createRecord(second, 12),
    ]);
    expect(saved.map((record) => record.id).toSet(), hasLength(2));
    expect(await first.load(12), hasLength(2));
    for (final record in saved) {
      expect(await first.readPng(12, record.id), [1, 2, 3]);
    }
  });

  test('older records without a name still load', () {
    final record = CompositionRecord.fromJson({
      'id': 'old',
      'createdAt': '2026-09-23T00:00:00.000',
      'note': '旧攻略',
    });
    expect(record.name, isEmpty);
    expect(record.note, '旧攻略');
    expect(record.effectiveMapTag, 'none');
    expect(
      CompositionRecord.fromJson({
        'id': 'normal',
        'createdAt': '2026-09-23T00:00:00.000',
        'targetMap': '3-2 キス島沖',
      }).effectiveMapTag,
      'normal:3-2',
    );
    expect(
      CompositionRecord.fromJson({
        'id': 'event',
        'createdAt': '2026-09-23T00:00:00.000',
        'targetMap': 'E3 · 甲',
      }).effectiveMapTag,
      'event',
    );
  });

  test(
    'records keep their PNG and metadata per account; notes alone can change',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'composition-record-test-',
      );
      addTearDown(() => root.delete(recursive: true));
      final store = FileCompositionRecordStore(rootDirectory: () async => root);
      final original = Uint8List.fromList([1, 2, 3, 4]);
      final saved = await store.create(
        name: 'E3 攻略',
        memberId: 12,
        png: original,
        note: '斩杀',
        fleetForm: '水上打击部队',
        targetMap: 'E3-3 · 甲',
        fleetIds: [1, 2],
        landBaseCount: 1,
        createdAt: DateTime(2026, 9, 23),
        snapshotJson: '{"fleets":[]}',
        landBaseAreaId: 6,
        landBaseIds: [1, 2],
        planeCountMode: 'current',
        mapTag: 'event',
      );
      original[0] = 9;
      expect(await store.load(13), isEmpty);
      expect((await store.load(12)).single.note, '斩杀');
      expect((await store.load(12)).single.name, 'E3 攻略');
      expect(await store.readPng(12, saved.id), [1, 2, 3, 4]);
      await store.updateNote(12, saved.id, '周回');
      final reloaded = (await store.load(12)).single;
      expect(reloaded.note, '周回');
      expect(reloaded.name, 'E3 攻略');
      expect(reloaded.targetMap, 'E3-3 · 甲');
      expect(reloaded.fleetForm, '水上打击部队');
      expect(reloaded.snapshotJson, '{"fleets":[]}');
      expect(reloaded.landBaseAreaId, 6);
      expect(reloaded.landBaseIds, [1, 2]);
      expect(reloaded.planeCountMode, 'current');
      expect(reloaded.effectiveMapTag, 'event');
      expect(await store.readPng(12, saved.id), [1, 2, 3, 4]);
      await store.delete(12, saved.id);
      expect(await store.load(12), isEmpty);
      expect(
        () => store.readPng(12, saved.id),
        throwsA(isA<FileSystemException>()),
      );
    },
  );
}

Future<void> _seedIndex(Directory root, int memberId, int count) async {
  final directory = Directory('${root.path}/composition_records/$memberId');
  await directory.create(recursive: true);
  final records = List.generate(
    count,
    (index) => CompositionRecord(
      id: 'legacy-$index',
      createdAt: DateTime(2026, 9, 23),
      note: '',
      fleetForm: '',
      targetMap: '',
      fleetIds: const [],
      landBaseCount: 0,
    ).toJson(),
  );
  await File(
    '${directory.path}/records.json',
  ).writeAsString(jsonEncode(records));
}

Future<CompositionRecord> _createRecord(
  CompositionRecordStore store,
  int memberId,
) => store.create(
  memberId: memberId,
  png: Uint8List.fromList([1, 2, 3]),
  note: '',
  name: '测试编队',
  fleetForm: '普通舰队',
  targetMap: '',
  fleetIds: const [1],
  landBaseCount: 0,
  createdAt: DateTime(2026, 9, 23),
);
