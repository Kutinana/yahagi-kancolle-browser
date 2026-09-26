import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/composition_image_page.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/composition_record_store.dart';
import 'package:yahagi_kancolle_browser/src/widgets/top_notice.dart';

void main() {
  testWidgets('index read failure is visible and can be retried', (
    tester,
  ) async {
    final store = _AuditStore()..failLoad = true;
    await tester.pumpWidget(_app(store, 7));
    await tester.pumpAndSettle();
    expect(find.text('读取编队记录失败。'), findsOneWidget);
    expect(find.text('还没有编队记录'), findsNothing);
    store.failLoad = false;
    await tester.tap(find.byKey(const Key('composition-record-retry')));
    await tester.pumpAndSettle();
    expect(find.text('读取编队记录失败。'), findsNothing);
    expect(find.text('还没有编队记录'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('missing legacy PNG shows an error instead of endless loading', (
    tester,
  ) async {
    final store = _AuditStore()
      ..records[7] = [_record('broken')]
      ..failRead = true;
    await tester.pumpWidget(_app(store, 7));
    await tester.pumpAndSettle();
    expect(find.text('记录图片无法读取。'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('composition-record-detail')),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsNothing,
    );
    store.failRead = false;
    await tester.tap(find.byKey(const Key('composition-record-retry')));
    await tester.pumpAndSettle();
    expect(find.text('记录图片无法读取。'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('malformed persisted map tag cannot crash the saved library', (
    tester,
  ) async {
    final store = _AuditStore()
      ..records[7] = [
        _record('bad', mapTag: 'normal:abc'),
        _record('good', mapTag: 'normal:1-1'),
        _record(
          'huge',
          mapTag: 'normal:1-999999999999999999999999999999999999999',
        ),
      ];
    await tester.pumpWidget(_app(store, 7));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('composition-record-bad')), findsOneWidget);
    expect(find.byKey(const Key('composition-record-good')), findsOneWidget);
    expect(find.byKey(const Key('composition-record-huge')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('deleting the last record for a legacy map clears its filter', (
    tester,
  ) async {
    final store = _AuditStore()
      ..records[7] = [
        _record('old-map', mapTag: 'normal:1-99'),
        _record('other'),
      ];
    await tester.pumpWidget(_app(store, 7));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('composition-filter')));
    await tester.pumpAndSettle();
    final oldMap = find.byKey(const Key('composition-filter-map-1-99')).last;
    await tester.ensureVisible(oldMap);
    await tester.tap(oldMap);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('composition-record-old-map')), findsOneWidget);
    expect(find.byKey(const Key('composition-record-other')), findsNothing);
    await tester.tap(find.byKey(const Key('composition-delete-record')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除记录').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('composition-record-other')), findsOneWidget);
    expect(find.text('筛选'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'confirming delete after account switch cannot delete new account',
    (tester) async {
      final store = _AuditStore()
        ..records[7] = [_record('shared')]
        ..records[8] = [_record('shared')];
      final memberId = ValueNotifier<int>(7);
      addTearDown(memberId.dispose);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: TopNoticeHost(
            child: Scaffold(
              body: ValueListenableBuilder<int>(
                valueListenable: memberId,
                builder: (context, id, _) => CompositionImagePage(
                  state: GameState(memberId: id),
                  recordStore: store,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('composition-delete-record')));
      await tester.pumpAndSettle();
      memberId.value = 8;
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除记录').last);
      await tester.pumpAndSettle();
      expect(store.deleted, isEmpty);
      expect(store.records[7], hasLength(1));
      expect(store.records[8], hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );
}

Widget _app(_AuditStore store, int memberId) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: TopNoticeHost(
    child: Scaffold(
      body: CompositionImagePage(
        state: GameState(memberId: memberId),
        recordStore: store,
      ),
    ),
  ),
);

CompositionRecord _record(String id, {String mapTag = 'none'}) =>
    CompositionRecord(
      id: id,
      createdAt: DateTime(2026, 9, 23),
      note: '',
      name: id,
      fleetForm: '普通舰队',
      targetMap: '',
      fleetIds: const [1],
      landBaseCount: 0,
      mapTag: mapTag,
    );

class _AuditStore extends Fake implements CompositionRecordStore {
  final records = <int, List<CompositionRecord>>{};
  final deleted = <(int, String)>[];
  bool failLoad = false;
  bool failRead = false;
  final png = Uint8List.fromList(img.encodePng(img.Image(width: 1, height: 1)));

  @override
  Future<List<CompositionRecord>> load(int memberId) async {
    if (failLoad) throw const FormatException('bad record index');
    return List.of(records[memberId] ?? const []);
  }

  @override
  Future<Uint8List> readPng(int memberId, String id) async {
    if (failRead) throw const FormatException('missing image');
    return png;
  }

  @override
  Future<void> delete(int memberId, String id) async {
    deleted.add((memberId, id));
    records[memberId]?.removeWhere((record) => record.id == id);
  }
}
