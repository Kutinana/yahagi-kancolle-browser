import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/layout/workspace_context_header.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/toolbox_page.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/composition_image_page.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/composition_image_port.dart';
import 'package:yahagi_kancolle_browser/src/widgets/top_notice.dart';

void main() {
  testWidgets('no target and no air base are the default choices', (
    tester,
  ) async {
    final state = _readyState().copyWith(
      landBases: const [LandBaseState(areaId: 6, baseId: 1, name: '第一基地航空队')],
    );
    await tester.pumpWidget(
      _app(CompositionImagePage(initiallyShowSaved: false, state: state)),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('composition-target-none')), findsOneWidget);
    expect(find.byKey(const Key('composition-target-map')), findsNothing);
    expect(find.byKey(const Key('composition-event-map')), findsNothing);
    expect(find.text('不使用航空队'), findsOneWidget);
    expect(find.byKey(const Key('composition-base-6-1')), findsNothing);
    for (var id = 1; id <= 3; id++) {
      final cell = tester.widget<InkWell>(
        find.byKey(Key('composition-select-base-0-$id')),
      );
      expect(cell.onTap, isNull);
    }
    await tester.tap(find.byKey(const ValueKey('composition-area-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('海域 6').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('composition-select-base-6-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('composition-base-6-1')), findsOneWidget);
    for (var id = 2; id <= 3; id++) {
      expect(
        tester
            .widget<InkWell>(find.byKey(Key('composition-select-base-6-$id')))
            .onTap,
        isNull,
      );
    }
    await tester.tap(find.byKey(const ValueKey('composition-area-6')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('不使用航空队').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('composition-base-6-1')), findsNothing);
    expect(
      tester
          .widget<InkWell>(find.byKey(const Key('composition-select-base-0-1')))
          .onTap,
      isNull,
    );
  });

  testWidgets('unfinished choices survive leaving and reopening the toolbox', (
    tester,
  ) async {
    final draft = CompositionImageDraftController();
    final state = _readyState().copyWith(
      landBases: const [LandBaseState(areaId: 6, baseId: 1, name: '第一基地航空队')],
    );
    Widget page(GameState current) => _app(
      CompositionImagePage(
        initiallyShowSaved: false,
        state: current,
        draftController: draft,
      ),
    );
    await tester.pumpWidget(page(state));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('composition-fleet-2')));
    await tester.tap(find.byKey(const ValueKey('composition-area-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('海域 6').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('composition-select-base-6-1')));
    await tester.tap(find.byKey(const Key('composition-target-event')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('composition-event-map')),
      'E3-3',
    );
    await tester.enterText(find.byKey(const Key('composition-name')), '攻略');
    await tester.pumpWidget(_app(const SizedBox.shrink()));
    await tester.pumpWidget(page(state));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('composition-ship-2-2')), findsNothing);
    expect(find.byKey(const Key('composition-base-6-1')), findsOneWidget);
    expect(find.byKey(const Key('composition-event-map')), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('composition-event-map')))
          .controller
          ?.text,
      'E3-3',
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('composition-name')))
          .controller
          ?.text,
      '攻略',
    );
    expect(find.byKey(const Key('composition-note')), findsNothing);
    expect(find.text('保存后名称：E3-3 攻略'), findsOneWidget);
    await tester.pumpWidget(_app(const SizedBox.shrink()));
    await tester.pumpWidget(page(state.copyWith(memberId: 2)));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('composition-event-map')), findsNothing);
    expect(find.byKey(const Key('composition-base-6-1')), findsNothing);
    await tester.pumpWidget(_app(const SizedBox.shrink()));
    await tester.pumpWidget(page(state));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('composition-event-map')), findsOneWidget);
    expect(find.byKey(const Key('composition-base-6-1')), findsOneWidget);
  });

  testWidgets(
    'preview time follows composition changes and survives rebuilds',
    (tester) async {
      var currentTime = DateTime(2026, 9, 12, 10, 20, 30);
      var clockReads = 0;
      var state = _readyState().copyWith(updatedAt: DateTime(2001, 1, 1));
      Widget page() => _app(
        CompositionImagePage(
          initiallyShowSaved: false,
          state: state,
          now: () {
            clockReads++;
            return currentTime;
          },
        ),
      );
      await tester.pumpWidget(page());
      expect(_generatedAt(tester), contains('2026-09-12 10:20:30'));
      expect(clockReads, 1);

      currentTime = DateTime(2026, 9, 12, 10, 21, 0);
      await tester.pumpWidget(page());
      final reassemble = tester.binding.reassembleApplication();
      await tester.pump();
      await reassemble;
      state = state.copyWith(
        updatedAt: currentTime,
        resources: {GameResourceType.fuel: 1000},
      );
      await tester.pumpWidget(page());
      expect(_generatedAt(tester), contains('2026-09-12 10:20:30'));
      expect(clockReads, 1);

      await tester.tap(find.byKey(const Key('composition-fleet-2')));
      await tester.pump();
      expect(_generatedAt(tester), contains('2026-09-12 10:21:00'));
      expect(clockReads, 2);

      currentTime = DateTime(2026, 9, 12, 10, 22, 0);
      state = state.copyWith(
        ships: {
          ...state.ships,
          1: const OwnedShip(id: 1, masterId: 100, level: 100, luck: 42),
        },
      );
      await tester.pumpWidget(page());
      expect(_generatedAt(tester), contains('2026-09-12 10:22:00'));
      expect(clockReads, 3);

      currentTime = DateTime(2026, 9, 12, 10, 23, 0);
      state = state.copyWith(admiralLevel: 120);
      await tester.pumpWidget(page());
      expect(_generatedAt(tester), contains('2026-09-12 10:23:00'));
      expect(clockReads, 4);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('all content controls regenerate the local preview time', (
    tester,
  ) async {
    var currentTime = DateTime(2026, 9, 12, 11, 0, 0);
    final state = _readyState().copyWith(
      masterMapAreas: {2: '第二海域', 3: '第三海域'},
      landBases: const [
        LandBaseState(areaId: 2, baseId: 1, name: '第二海域基地'),
        LandBaseState(areaId: 3, baseId: 1, name: '第三海域基地'),
      ],
    );
    Widget page({bool visible = true}) => _app(
      CompositionImagePage(
        initiallyShowSaved: false,
        state: state,
        now: () => currentTime,
        visible: visible,
      ),
    );
    await tester.pumpWidget(page());
    expect(_generatedAt(tester), contains('2026-09-12 11:00:00'));

    currentTime = DateTime(2026, 9, 12, 11, 1, 0);
    await tester.tap(find.byKey(const Key('composition-planes-maximum')));
    await tester.pump();
    expect(_generatedAt(tester), contains('2026-09-12 11:01:00'));

    currentTime = DateTime(2026, 9, 12, 11, 2, 0);
    await tester.tap(find.byKey(const ValueKey('composition-area-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('第三海域').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('composition-select-base-3-1')));
    await tester.pump();
    expect(_generatedAt(tester), contains('2026-09-12 11:02:00'));

    currentTime = DateTime(2026, 9, 12, 11, 3, 0);
    await tester.tap(find.byKey(const ValueKey('composition-area-3')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('第二海域').last);
    await tester.pumpAndSettle();
    expect(_generatedAt(tester), contains('2026-09-12 11:03:00'));

    await tester.pumpWidget(page(visible: false));
    currentTime = DateTime(2026, 9, 12, 11, 4, 0);
    await tester.pumpWidget(page());
    expect(_generatedAt(tester), contains('2026-09-12 11:04:00'));
  });

  testWidgets(
    'save freezes its new timestamp throughout asynchronous encoding',
    (tester) async {
      var currentTime = DateTime(2026, 9, 12, 12, 0, 0);
      final encoding = Completer<Uint8List>();
      final port = _RecordingPort();
      final capturedTimes = <String>[];
      Widget page(GameState state) => _app(
        CompositionImagePage(
          initiallyShowSaved: false,
          state: state,
          port: port,
          now: () => currentTime,
          capturePng: (_) async {
            capturedTimes.add(_generatedAt(tester));
            final bytes = await encoding.future;
            capturedTimes.add(_generatedAt(tester));
            return bytes;
          },
        ),
      );
      final initialState = _readyState();
      await tester.pumpWidget(page(initialState));
      expect(_generatedAt(tester), contains('2026-09-12 12:00:00'));

      currentTime = DateTime(2026, 9, 12, 12, 1, 0);
      await _startSave(tester);
      expect(capturedTimes.single, contains('2026-09-12 12:01:00'));

      currentTime = DateTime(2026, 9, 12, 12, 2, 0);
      await tester.pumpWidget(
        page(
          initialState.copyWith(
            ships: {
              ...initialState.ships,
              1: const OwnedShip(id: 1, masterId: 100, level: 100, luck: 42),
            },
          ),
        ),
      );
      expect(_generatedAt(tester), contains('2026-09-12 12:01:00'));
      expect(_save(tester).onPressed, isNull);
      encoding.complete(Uint8List.fromList([1, 2, 3]));
      await tester.pump();
      await tester.pump();
      expect(capturedTimes, hasLength(2));
      expect(capturedTimes[1], capturedTimes[0]);
      expect(port.calls, 1);
      expect(_generatedAt(tester), contains('2026-09-12 12:02:00'));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('content selections use the shared yellow theme without ticks', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        CompositionImagePage(initiallyShowSaved: false, state: _readyState()),
      ),
    );
    await tester.pumpAndSettle();

    final fleet = find.byKey(const Key('composition-fleet-1'));
    Color? cellColor(Finder finder) =>
        (tester
                    .widget<AnimatedContainer>(
                      find.descendant(
                        of: finder,
                        matching: find.byType(AnimatedContainer),
                      ),
                    )
                    .decoration
                as BoxDecoration)
            .color;

    for (final chip in tester.widgetList<FilterChip>(find.byType(FilterChip))) {
      expect(chip.showCheckmark, isFalse);
    }
    expect(cellColor(fleet), const Color(0xff8a6628));
    await tester.tap(fleet);
    await tester.pumpAndSettle();
    expect(cellColor(fleet), Colors.transparent);
    expect(find.text('矢矧改二乙'), findsNothing);
  });

  testWidgets('desktop composition controls align with the preview actions', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 700);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      _app(
        CompositionImagePage(initiallyShowSaved: false, state: _readyState()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('把此刻的舰队，保存成一张图。'), findsNothing);
    expect(find.text('编成记录'), findsOneWidget);
    expect(find.text('保存完整高清图片，包含下方全部编成。'), findsNothing);
    final controls = find.byKey(const Key('composition-controls'));
    final previewHeader = find.byKey(const Key('composition-preview-header'));
    final save = find.byKey(const Key('composition-save'));
    final planeTabs = find.byKey(const Key('composition-plane-count-tabs'));
    expect(controls, findsOneWidget);
    expect(previewHeader, findsOneWidget);
    expect(planeTabs, findsOneWidget);
    expect(
      find.descendant(of: planeTabs, matching: find.byType(FilterChip)),
      findsNothing,
    );
    final previewTitle = tester.widget<Text>(find.text('图片预览'));
    expect(previewTitle.style?.fontSize, 21);
    expect(previewTitle.style?.fontWeight, FontWeight.w800);
    expect(previewTitle.style?.color, const Color(0xffecf3f5));
    expect(
      tester.getTopLeft(controls).dy,
      lessThan(tester.getTopLeft(previewHeader).dy),
    );
    expect(
      tester.getCenter(save).dy,
      closeTo(tester.getCenter(previewHeader).dy, 0.01),
    );
    final hidden = tester.getRect(
      find.byKey(const Key('composition-planes-hidden')),
    );
    final maximum = tester.getRect(
      find.byKey(const Key('composition-planes-maximum')),
    );
    expect(hidden.right, closeTo(maximum.left, 0.01));
    expect(find.byKey(const Key('composition-planes-current')), findsNothing);
  });

  testWidgets(
    'fleet and three land bases use full-width aligned selection grids',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(673, 841);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final state = _readyState().copyWith(
        fleets: const [
          Fleet(id: 1, name: '第一', shipIds: [1]),
          Fleet(id: 2, name: '第二', shipIds: [2]),
          Fleet(id: 3, name: '第三', shipIds: []),
          Fleet(id: 4, name: '第四', shipIds: []),
        ],
        landBases: const [
          LandBaseState(areaId: 6, baseId: 1, name: '第一'),
          LandBaseState(areaId: 6, baseId: 2, name: '第二'),
          LandBaseState(areaId: 6, baseId: 3, name: '第三'),
        ],
      );
      await tester.pumpWidget(
        _app(CompositionImagePage(initiallyShowSaved: false, state: state)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('composition-area-0')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('海域 6').last);
      await tester.pumpAndSettle();

      final fleetGrid = tester.getRect(
        find.byKey(const Key('composition-fleet-grid')),
      );
      final formGrid = tester.getRect(
        find.byKey(const Key('composition-form-segmented')),
      );
      expect(fleetGrid.width, closeTo(formGrid.width, 1));
      final fleets = [
        for (var i = 1; i <= 4; i++)
          tester.getRect(find.byKey(Key('composition-fleet-$i'))),
      ];
      expect(fleets[0].width, closeTo(fleets[1].width, 1));
      expect(fleets[0].top, closeTo(fleets[1].top, 1));
      expect(fleets[2].top, greaterThan(fleets[0].bottom));

      final bases = [
        for (var i = 1; i <= 3; i++)
          tester.getRect(find.byKey(Key('composition-select-base-6-$i'))),
      ];
      expect(bases[0].top, closeTo(bases[2].top, 1));
      expect(bases[0].width, closeTo(bases[2].width, 1));
      expect(
        tester.getRect(find.byKey(const Key('composition-base-grid'))).width,
        closeTo(
          tester
              .getRect(find.byKey(const ValueKey('composition-area-6')))
              .width,
          1,
        ),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'fleet form locks unavailable fleets and support locks first fleet',
    (tester) async {
      final state = _readyState().copyWith(
        fleets: const [
          Fleet(id: 1, name: '第一', shipIds: [1]),
          Fleet(id: 2, name: '第二', shipIds: [2]),
          Fleet(id: 3, name: '第三', shipIds: []),
          Fleet(id: 4, name: '第四', shipIds: []),
        ],
      );
      await tester.pumpWidget(
        _app(CompositionImagePage(initiallyShowSaved: false, state: state)),
      );
      await tester.pumpAndSettle();

      InkWell fleet(int id) =>
          tester.widget<InkWell>(find.byKey(Key('composition-fleet-$id')));
      expect(find.text('支援舰队'), findsOneWidget);
      expect(
        tester.getTopLeft(find.byKey(const Key('composition-form-0'))).dy,
        closeTo(
          tester.getTopLeft(find.byKey(const Key('composition-form-1'))).dy,
          1,
        ),
      );
      expect(
        tester.getTopLeft(find.byKey(const Key('composition-form-5'))).dy,
        greaterThan(
          tester.getBottomLeft(find.byKey(const Key('composition-form-0'))).dy,
        ),
      );

      for (final form in const [2, 3, 4]) {
        await tester.tap(find.byKey(Key('composition-form-$form')));
        await tester.pumpAndSettle();
        expect(fleet(1).onTap, isNotNull);
        expect(fleet(2).onTap, isNotNull);
        expect(fleet(3).onTap, isNull);
        expect(fleet(4).onTap, isNull);
      }
      await tester.tap(find.byKey(const Key('composition-form-5')));
      await tester.pumpAndSettle();
      expect(fleet(1).onTap, isNull);
      expect(fleet(2).onTap, isNull);
      expect(fleet(3).onTap, isNotNull);
      expect(fleet(4).onTap, isNull);

      await tester.tap(find.byKey(const Key('composition-form-1')));
      await tester.pumpAndSettle();
      expect(fleet(1).onTap, isNull);
      for (var id = 2; id <= 4; id++) {
        expect(fleet(id).onTap, isNotNull);
      }
    },
  );

  testWidgets(
    'composition alone keeps a wide layout on an unfolded square screen',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      for (final size in const [Size(673, 841), Size(841, 673)]) {
        tester.view.physicalSize = size;
        await tester.pumpWidget(
          _app(
            CompositionImagePage(
              initiallyShowSaved: false,
              state: _readyState().copyWith(
                landBases: const [
                  LandBaseState(areaId: 6, baseId: 1, name: '南西海域'),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final fleet = tester.getRect(
          find.byKey(const Key('composition-fleet-1')),
        );
        final base = tester.getRect(
          find.byKey(const Key('composition-area-0')),
        );
        expect(base.left, greaterThan(fleet.right));
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'temporary ship refresh preserves selected fleets and explains the wait',
    (tester) async {
      await tester.pumpWidget(
        _app(
          ToolboxPage(
            compositionInitiallyShowSaved: false,
            state: _readyState(),
            mode: _mode,
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('composition-fleet-2')));
      await tester.pump();
      await tester.pumpWidget(
        _app(
          ToolboxPage(
            compositionInitiallyShowSaved: false,
            state: _readyState().copyWith(pendingExportShipIds: {1}),
            mode: _mode,
          ),
        ),
      );
      expect(find.text('正在更新舰娘数据…'), findsOneWidget);
      expect(_save(tester).onPressed, isNull);
      await tester.pumpWidget(
        _app(
          ToolboxPage(
            compositionInitiallyShowSaved: false,
            state: _readyState(),
            mode: _mode,
          ),
        ),
      );
      expect(find.text('矢矧改二乙'), findsOneWidget);
      expect(find.text('時雨改三'), findsNothing);
    },
  );

  testWidgets(
    'Japanese and traditional Chinese use localized controls and image labels',
    (tester) async {
      for (final entry in [
        (const Locale('ja'), '画像を書き出す', '表示する内容', '非表示'),
        (
          const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
          '匯出圖片',
          '顯示內容',
          '隱藏',
        ),
      ]) {
        await tester.pumpWidget(
          _app(
            CompositionImagePage(
              initiallyShowSaved: false,
              state: _readyState(),
            ),
            locale: entry.$1,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(entry.$2), findsOneWidget);
        expect(find.text(entry.$3), findsOneWidget);
        expect(find.text(entry.$4), findsOneWidget);
        expect(find.text('矢矧改二乙'), findsOneWidget);
        expect(find.text('保存编成图'), findsNothing);
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'saving locks controls and submits one image despite repeated taps',
    (tester) async {
      final encoding = Completer<Uint8List>();
      final port = _RecordingPort();
      await tester.pumpWidget(
        _app(
          CompositionImagePage(
            initiallyShowSaved: false,
            state: _readyState(),
            port: port,
            capturePng: (_) => encoding.future,
          ),
        ),
      );
      await _startSave(tester);
      expect(_save(tester).onPressed, isNull);
      expect(
        tester
            .widget<InkWell>(find.byKey(const Key('composition-fleet-1')))
            .onTap,
        isNull,
      );
      await tester.tap(find.byKey(const Key('composition-save')));
      encoding.complete(Uint8List.fromList([1, 2, 3]));
      await tester.pump();
      await tester.pump();
      expect(port.calls, 1);
      expect(find.text('编成图已保存到相册。'), findsOneWidget);
      expect(_save(tester).onPressed, isNotNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'permission failure restores controls and permits a successful retry',
    (tester) async {
      final port = _RecordingPort()
        ..error = PlatformException(code: 'storage_permission_denied');
      await tester.pumpWidget(
        _app(
          CompositionImagePage(
            initiallyShowSaved: false,
            state: _readyState(),
            port: port,
            capturePng: (_) async => Uint8List.fromList([1]),
          ),
        ),
      );
      await _startSave(tester);
      expect(find.text('需要相册存储权限才能保存编成图。'), findsOneWidget);
      expect(_save(tester).onPressed, isNotNull);
      port.error = null;
      await _startSave(tester);
      expect(port.calls, 2);
      expect(find.text('编成图已保存到相册。'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'account changes during image encoding cancel the old account save',
    (tester) async {
      final encoding = Completer<Uint8List>();
      final port = _RecordingPort();
      Widget page(GameState state) => _app(
        CompositionImagePage(
          initiallyShowSaved: false,
          state: state,
          port: port,
          capturePng: (_) => encoding.future,
        ),
      );
      await tester.pumpWidget(page(_readyState()));
      await _startSave(tester);
      await tester.pumpWidget(
        page(_readyState().copyWith(memberId: 2, ships: {}, fleets: [])),
      );
      encoding.complete(Uint8List.fromList([1]));
      await tester.pump();
      expect(port.calls, 0);
      expect(find.text('矢矧改二乙'), findsNothing);
      expect(_save(tester).onPressed, isNull);
    },
  );

  testWidgets('toolbox offers a localized composition image tab', (
    tester,
  ) async {
    ToolboxMode? selected;
    await tester.pumpWidget(
      _app(
        ToolboxModeTabs(
          mode: ToolboxMode.export,
          onChanged: (value) => selected = value,
        ),
      ),
    );
    expect(find.text('编成记录'), findsOneWidget);
    await tester.tap(find.byKey(const Key('toolbox-tab-composition')));
    expect(selected?.name, 'composition');
  });

  testWidgets('composition page selects fleets and prevents an empty save', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        ToolboxPage(
          compositionInitiallyShowSaved: false,
          state: _readyState(),
          mode: _mode,
        ),
      ),
    );
    expect(find.text('矢矧改二乙'), findsOneWidget);
    expect(find.text('時雨改三'), findsOneWidget);
    expect(_save(tester).onPressed, isNotNull);
    await tester.tap(find.byKey(const Key('composition-fleet-2')));
    await tester.pump();
    expect(find.text('時雨改三'), findsNothing);
    await tester.tap(find.byKey(const Key('composition-fleet-1')));
    await tester.pump();
    expect(_save(tester).onPressed, isNull);
    expect(find.text('请选择要保存的舰队或陆航。'), findsOneWidget);
  });

  testWidgets(
    'missing live equipment data hides the card and disables saving',
    (tester) async {
      await tester.pumpWidget(
        _app(
          ToolboxPage(
            compositionInitiallyShowSaved: false,
            state: _readyState().copyWith(hasEquipmentInventory: false),
            mode: _mode,
          ),
        ),
      );
      expect(_save(tester).onPressed, isNull);
      expect(find.text('矢矧改二乙'), findsNothing);
      expect(find.byKey(const Key('composition-image-card')), findsNothing);
    },
  );

  testWidgets('account switch replaces displayed ships and resets selections', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        ToolboxPage(
          compositionInitiallyShowSaved: false,
          state: _readyState(),
          mode: _mode,
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('composition-fleet-1')));
    await tester.pump();
    await tester.pumpWidget(
      _app(
        ToolboxPage(
          compositionInitiallyShowSaved: false,
          state: _readyState().copyWith(
            memberId: 2,
            fleets: const [
              Fleet(id: 1, name: 'New', shipIds: [2]),
            ],
          ),
          mode: _mode,
        ),
      ),
    );
    expect(find.text('矢矧改二乙'), findsNothing);
    expect(find.text('時雨改三'), findsOneWidget);
    expect(_save(tester).onPressed, isNotNull);
  });

  testWidgets(
    'portrait and landscape preview stays within the available width',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      for (final size in [const Size(360, 740), const Size(900, 420)]) {
        tester.view.physicalSize = size;
        await tester.pumpWidget(
          _app(
            ToolboxPage(
              compositionInitiallyShowSaved: false,
              state: _readyState(),
              mode: _mode,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          tester.getSize(find.byKey(const Key('composition-preview'))).width,
          lessThanOrEqualTo(size.width),
        );
      }
    },
  );
}

ToolboxMode get _mode =>
    ToolboxMode.values.singleWhere((mode) => mode.name == 'composition');
FilledButton _save(WidgetTester tester) =>
    tester.widget<FilledButton>(find.byKey(const Key('composition-save')));
String _generatedAt(WidgetTester tester) => tester
    .widget<Text>(find.byKey(const Key('composition-generated-at')))
    .data!;

GameState _readyState() => const GameState(
  memberId: 1,
  hasPortData: true,
  hasEquipmentInventory: true,
  masterShips: {
    100: MasterShip(id: 100, name: '矢矧改二乙', shipTypeId: 3),
    101: MasterShip(id: 101, name: '時雨改三', shipTypeId: 2),
  },
  ships: {
    1: OwnedShip(id: 1, masterId: 100, level: 99, luck: 42),
    2: OwnedShip(id: 2, masterId: 101, level: 88, luck: 55),
  },
  fleets: [
    Fleet(id: 1, name: '第一', shipIds: [1]),
    Fleet(id: 2, name: '第二', shipIds: [2]),
  ],
);

Widget _app(Widget child, {Locale locale = const Locale('zh')}) => MaterialApp(
  theme: ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xffd4a85f),
      brightness: Brightness.dark,
    ),
    useMaterial3: true,
  ),
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: TopNoticeHost(child: Scaffold(body: child)),
);

Future<void> _startSave(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const Key('composition-save')));
  await tester.pump();
  await tester.tap(find.byKey(const Key('composition-save')));
  // A frame freezes the card; the next frame follows local icon precaching.
  await tester.pump();
  await tester.pump();
  await tester.pump();
}

class _RecordingPort implements CompositionImagePort {
  int calls = 0;
  Object? error;
  @override
  Future<String> savePng(Uint8List bytes) async {
    calls++;
    if (error case final Object failure) throw failure;
    return 'Pictures/Yahagi/Compositions/test.png';
  }
}
